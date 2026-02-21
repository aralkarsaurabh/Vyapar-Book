import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/credit_note.dart';
import 'profile_service.dart';
import 'accounting_service.dart';
import 'invoice_service.dart';

// Re-export CreditNote and related classes
export '../models/credit_note.dart';

class CreditNoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProfileService _profileService = ProfileService();
  final AccountingService _accountingService = AccountingService();

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference get _creditNotesCollection =>
      _firestore.collection('creditNotes');

  CollectionReference get _invoicesCollection =>
      _firestore.collection('invoices');

  CollectionReference get _customersCollection =>
      _firestore.collection('customers');

  /// Generate credit note number: PREFIX/CN/YYYY-YY/NNN (e.g., TPL/CN/2025-26/001)
  Future<String> generateCreditNoteNumber() async {
    if (_userId == null) return '';

    // Get company profile to extract initials
    final companyProfile = await _profileService.getCompanyProfile();
    final companyInitials =
        InvoiceService.getCompanyInitials(companyProfile?.companyLegalName);

    final now = DateTime.now();
    // Financial year: April to March
    final year = now.month >= 4 ? now.year : now.year - 1;
    final nextYear = year + 1;
    final financialYear = '$year-${nextYear.toString().substring(2)}';
    final prefix = '$companyInitials/CN/$financialYear/';

    try {
      // Get all credit notes for this user in this financial year
      final startDate = DateTime(year, 4, 1);
      final endDate = DateTime(nextYear, 3, 31, 23, 59, 59);

      final snapshot = await _creditNotesCollection
          .where('userId', isEqualTo: _userId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('createdAt', descending: true)
          .get();

      int nextNumber = 1;

      if (snapshot.docs.isNotEmpty) {
        // Find the highest sequence number from existing credit notes
        final numberRegex = RegExp(r'/CN/\d{4}-\d{2}/(\d+)$');
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final cnNumber = data['creditNoteNumber'] as String?;
          if (cnNumber != null) {
            final match = numberRegex.firstMatch(cnNumber);
            if (match != null) {
              final seq = int.tryParse(match.group(1)!);
              if (seq != null && seq >= nextNumber) {
                nextNumber = seq + 1;
              }
            }
          }
        }
      }

      return '$prefix${nextNumber.toString().padLeft(3, '0')}';
    } catch (e) {
      debugPrint('Error generating credit note number: $e');
      // Fallback: count existing credit notes + 1
      try {
        final countSnapshot = await _creditNotesCollection
            .where('userId', isEqualTo: _userId)
            .get();
        final nextNumber = countSnapshot.docs.length + 1;
        return '$prefix${nextNumber.toString().padLeft(3, '0')}';
      } catch (_) {
        return '${prefix}001';
      }
    }
  }

  /// Get all credit notes for the current user
  Stream<List<CreditNote>> getCreditNotes() {
    if (_userId == null) return Stream.value([]);

    return _creditNotesCollection
        .where('userId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
      debugPrint('===========================================');
      debugPrint('FIRESTORE ERROR: $error');
      if (error.toString().contains('index')) {
        debugPrint('');
        debugPrint(
            'Please create the required index by visiting the URL above.');
      }
      debugPrint('===========================================');
    }).map((snapshot) {
      return snapshot.docs.map((doc) {
        return CreditNote.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Get a single credit note by ID
  Future<CreditNote?> getCreditNoteById(String creditNoteId) async {
    if (_userId == null) return null;

    try {
      final doc = await _creditNotesCollection.doc(creditNoteId).get();
      if (doc.exists) {
        final creditNote =
            CreditNote.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        if (creditNote.userId == _userId) {
          return creditNote;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting credit note: $e');
      return null;
    }
  }

  /// Get credit notes for a specific invoice
  Stream<List<CreditNote>> getCreditNotesForInvoice(String invoiceId) {
    if (_userId == null) return Stream.value([]);

    return _creditNotesCollection
        .where('userId', isEqualTo: _userId)
        .where('againstInvoiceId', isEqualTo: invoiceId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return CreditNote.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Add a new credit note
  /// This also:
  /// - Creates a journal entry (DR Sales Return + GST Output, CR Accounts Receivable)
  /// - Updates the invoice's amountDue
  /// - Updates customer's outstanding balance
  Future<String?> addCreditNote(CreditNote creditNote) async {
    if (_userId == null) return null;

    try {
      creditNote.userId = _userId;
      creditNote.creditNoteNumber = await generateCreditNoteNumber();
      creditNote.status = CreditNoteStatus.issued;

      // Calculate totals
      creditNote.calculateTotals();

      final map = creditNote.toMap();
      map['createdAt'] = FieldValue.serverTimestamp();

      // Start batch for atomic operations
      final batch = _firestore.batch();

      // 1. Create credit note
      final creditNoteRef = _creditNotesCollection.doc();
      batch.set(creditNoteRef, map);

      // 2. Update invoice's amountDue
      if (creditNote.againstInvoiceId != null) {
        final invoiceRef =
            _invoicesCollection.doc(creditNote.againstInvoiceId);
        batch.update(invoiceRef, {
          'amountDue': FieldValue.increment(-creditNote.grandTotal),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 3. Update customer's outstanding balance
      if (creditNote.customerId != null) {
        final customerRef = _customersCollection.doc(creditNote.customerId);
        batch.update(customerRef, {
          'outstandingBalance': FieldValue.increment(-creditNote.grandTotal),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Commit batch
      await batch.commit();

      final creditNoteId = creditNoteRef.id;

      // 4. Create journal entry (outside batch - involves multiple queries)
      try {
        await _accountingService.recordCreditNote(
          creditNoteId: creditNoteId,
          creditNoteNumber: creditNote.creditNoteNumber ?? '',
          customerName: creditNote.customerName ?? '',
          invoiceNumber: creditNote.againstInvoiceNumber ?? '',
          date: creditNote.creditNoteDate ?? DateTime.now(),
          subtotal: creditNote.subtotal,
          grandTotal: creditNote.grandTotal,
          cgstAmount: creditNote.cgstTotal,
          sgstAmount: creditNote.sgstTotal,
          igstAmount: creditNote.igstTotal,
        );
      } catch (e) {
        debugPrint('Error creating credit note journal entry: $e');
        // Don't fail credit note creation if accounting fails
      }

      return creditNoteId;
    } catch (e) {
      debugPrint('Error adding credit note: $e');
      return null;
    }
  }

  /// Update a credit note (only if not yet sent to customer)
  Future<bool> updateCreditNote(CreditNote creditNote) async {
    if (_userId == null || creditNote.id == null) return false;

    try {
      final existingCreditNote = await getCreditNoteById(creditNote.id!);
      if (existingCreditNote == null ||
          existingCreditNote.userId != _userId) {
        return false;
      }

      // Don't allow editing if already sent
      if (existingCreditNote.status == CreditNoteStatus.sent) {
        debugPrint('Cannot edit credit note that has been sent');
        return false;
      }

      await _creditNotesCollection.doc(creditNote.id).update(creditNote.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating credit note: $e');
      return false;
    }
  }

  /// Delete a credit note
  /// This also reverses the invoice and customer balance updates
  Future<bool> deleteCreditNote(String creditNoteId) async {
    if (_userId == null) return false;

    try {
      final existingCreditNote = await getCreditNoteById(creditNoteId);
      if (existingCreditNote == null ||
          existingCreditNote.userId != _userId) {
        return false;
      }

      // Don't allow deleting if already sent
      if (existingCreditNote.status == CreditNoteStatus.sent) {
        debugPrint('Cannot delete credit note that has been sent');
        return false;
      }

      final batch = _firestore.batch();

      // 1. Delete credit note
      batch.delete(_creditNotesCollection.doc(creditNoteId));

      // 2. Restore invoice's amountDue
      if (existingCreditNote.againstInvoiceId != null) {
        final invoiceRef =
            _invoicesCollection.doc(existingCreditNote.againstInvoiceId);
        batch.update(invoiceRef, {
          'amountDue': FieldValue.increment(existingCreditNote.grandTotal),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 3. Restore customer's outstanding balance
      if (existingCreditNote.customerId != null) {
        final customerRef =
            _customersCollection.doc(existingCreditNote.customerId);
        batch.update(customerRef, {
          'outstandingBalance':
              FieldValue.increment(existingCreditNote.grandTotal),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Note: Journal entry reversal would need to be handled separately
      // For now, we leave the journal entry as-is (audit trail)

      return true;
    } catch (e) {
      debugPrint('Error deleting credit note: $e');
      return false;
    }
  }

  /// Mark credit note as sent (after sending to customer via Vyapar ID)
  Future<bool> markAsSent(String creditNoteId) async {
    if (_userId == null) return false;

    try {
      final existingCreditNote = await getCreditNoteById(creditNoteId);
      if (existingCreditNote == null ||
          existingCreditNote.userId != _userId) {
        return false;
      }

      await _creditNotesCollection.doc(creditNoteId).update({
        'status': CreditNoteStatus.sent,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error marking credit note as sent: $e');
      return false;
    }
  }

  /// Get invoices available for credit note creation
  /// Returns invoices that are not fully paid (have outstanding balance)
  Future<List<Invoice>> getInvoicesForCreditNote() async {
    if (_userId == null) return [];

    try {
      final invoiceService = InvoiceService();
      final invoices = await invoiceService.getInvoices().first;

      // Filter to invoices with outstanding balance
      return invoices.where((invoice) {
        return invoice.amountDue > 0 || invoice.paymentStatus != PaymentStatus.paid;
      }).toList();
    } catch (e) {
      debugPrint('Error getting invoices for credit note: $e');
      return [];
    }
  }

  /// Get total credit notes issued in a date range
  Future<double> getTotalCreditNotesInRange(
      DateTime startDate, DateTime endDate) async {
    if (_userId == null) return 0;

    try {
      final snapshot = await _creditNotesCollection
          .where('userId', isEqualTo: _userId)
          .where('creditNoteDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('creditNoteDate',
              isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      double total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total += (data['grandTotal'] ?? 0).toDouble();
      }
      return total;
    } catch (e) {
      debugPrint('Error getting total credit notes: $e');
      return 0;
    }
  }

  /// Get credit notes for a specific customer
  Future<List<CreditNote>> getCreditNotesForCustomer(String customerId) async {
    if (_userId == null) return [];

    try {
      final snapshot = await _creditNotesCollection
          .where('userId', isEqualTo: _userId)
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return CreditNote.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Error getting credit notes for customer: $e');
      return [];
    }
  }
}
