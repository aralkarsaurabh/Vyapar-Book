import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/debit_note.dart';
import 'profile_service.dart';
import 'accounting_service.dart';
import 'invoice_service.dart';
import 'shared_document_service.dart';

// Re-export DebitNote and related classes
export '../models/debit_note.dart';

class DebitNoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProfileService _profileService = ProfileService();
  final AccountingService _accountingService = AccountingService();

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference get _debitNotesCollection =>
      _firestore.collection('debitNotes');

  CollectionReference get _sharedDocumentsCollection =>
      _firestore.collection('sharedDocuments');

  CollectionReference get _vendorsCollection =>
      _firestore.collection('vendors');

  /// Generate debit note number: PREFIX/DN/YYYY-YY/NNN (e.g., TPL/DN/2025-26/001)
  Future<String> generateDebitNoteNumber() async {
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
    final prefix = '$companyInitials/DN/$financialYear/';

    try {
      // Get all debit notes for this user in this financial year
      final startDate = DateTime(year, 4, 1);
      final endDate = DateTime(nextYear, 3, 31, 23, 59, 59);

      final snapshot = await _debitNotesCollection
          .where('userId', isEqualTo: _userId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('createdAt', descending: true)
          .get();

      int nextNumber = 1;

      if (snapshot.docs.isNotEmpty) {
        // Find the highest sequence number from existing debit notes
        final numberRegex = RegExp(r'/DN/\d{4}-\d{2}/(\d+)$');
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final dnNumber = data['debitNoteNumber'] as String?;
          if (dnNumber != null) {
            final match = numberRegex.firstMatch(dnNumber);
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
      debugPrint('Error generating debit note number: $e');
      // Fallback: count existing debit notes + 1
      try {
        final countSnapshot = await _debitNotesCollection
            .where('userId', isEqualTo: _userId)
            .get();
        final nextNumber = countSnapshot.docs.length + 1;
        return '$prefix${nextNumber.toString().padLeft(3, '0')}';
      } catch (_) {
        return '${prefix}001';
      }
    }
  }

  /// Get all debit notes for the current user
  Stream<List<DebitNote>> getDebitNotes() {
    if (_userId == null) return Stream.value([]);

    return _debitNotesCollection
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
        return DebitNote.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Get a single debit note by ID
  Future<DebitNote?> getDebitNoteById(String debitNoteId) async {
    if (_userId == null) return null;

    try {
      final doc = await _debitNotesCollection.doc(debitNoteId).get();
      if (doc.exists) {
        final debitNote =
            DebitNote.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        if (debitNote.userId == _userId) {
          return debitNote;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting debit note: $e');
      return null;
    }
  }

  /// Get debit notes for a specific bill (received invoice)
  Stream<List<DebitNote>> getDebitNotesForBill(String billId) {
    if (_userId == null) return Stream.value([]);

    return _debitNotesCollection
        .where('userId', isEqualTo: _userId)
        .where('againstBillId', isEqualTo: billId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return DebitNote.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Add a new debit note
  /// This also:
  /// - Creates a journal entry (DR Accounts Payable, CR Purchase Return + GST Input)
  /// - Updates the shared document's amountDue
  /// - Updates vendor's outstanding balance
  Future<String?> addDebitNote(DebitNote debitNote) async {
    if (_userId == null) return null;

    try {
      debitNote.userId = _userId;
      debitNote.debitNoteNumber = await generateDebitNoteNumber();
      debitNote.status = DebitNoteStatus.issued;

      // Calculate totals
      debitNote.calculateTotals();

      final map = debitNote.toMap();
      map['createdAt'] = FieldValue.serverTimestamp();

      // Start batch for atomic operations
      final batch = _firestore.batch();

      // 1. Create debit note
      final debitNoteRef = _debitNotesCollection.doc();
      batch.set(debitNoteRef, map);

      // 2. Update shared document's amountDue (received invoice)
      if (debitNote.againstBillId != null) {
        final billRef = _sharedDocumentsCollection.doc(debitNote.againstBillId);
        batch.update(billRef, {
          'amountDue': FieldValue.increment(-debitNote.grandTotal),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 3. Update vendor's outstanding balance (what we owe them)
      if (debitNote.vendorId != null) {
        final vendorRef = _vendorsCollection.doc(debitNote.vendorId);
        batch.update(vendorRef, {
          'outstandingBalance': FieldValue.increment(-debitNote.grandTotal),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Commit batch
      await batch.commit();

      final debitNoteId = debitNoteRef.id;

      // 4. Create journal entry (outside batch - involves multiple queries)
      try {
        await _accountingService.recordDebitNote(
          debitNoteId: debitNoteId,
          debitNoteNumber: debitNote.debitNoteNumber ?? '',
          vendorName: debitNote.vendorName ?? '',
          billNumber: debitNote.againstBillNumber ?? '',
          date: debitNote.debitNoteDate ?? DateTime.now(),
          subtotal: debitNote.subtotal,
          grandTotal: debitNote.grandTotal,
          cgstAmount: debitNote.cgstTotal,
          sgstAmount: debitNote.sgstTotal,
          igstAmount: debitNote.igstTotal,
        );
      } catch (e) {
        debugPrint('Error creating debit note journal entry: $e');
        // Don't fail debit note creation if accounting fails
      }

      return debitNoteId;
    } catch (e) {
      debugPrint('Error adding debit note: $e');
      return null;
    }
  }

  /// Update a debit note (only if not yet sent to vendor)
  Future<bool> updateDebitNote(DebitNote debitNote) async {
    if (_userId == null || debitNote.id == null) return false;

    try {
      final existingDebitNote = await getDebitNoteById(debitNote.id!);
      if (existingDebitNote == null ||
          existingDebitNote.userId != _userId) {
        return false;
      }

      // Don't allow editing if already sent
      if (existingDebitNote.status == DebitNoteStatus.sent) {
        debugPrint('Cannot edit debit note that has been sent');
        return false;
      }

      await _debitNotesCollection.doc(debitNote.id).update(debitNote.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating debit note: $e');
      return false;
    }
  }

  /// Delete a debit note
  /// This also reverses the bill and vendor balance updates
  Future<bool> deleteDebitNote(String debitNoteId) async {
    if (_userId == null) return false;

    try {
      final existingDebitNote = await getDebitNoteById(debitNoteId);
      if (existingDebitNote == null ||
          existingDebitNote.userId != _userId) {
        return false;
      }

      // Don't allow deleting if already sent
      if (existingDebitNote.status == DebitNoteStatus.sent) {
        debugPrint('Cannot delete debit note that has been sent');
        return false;
      }

      final batch = _firestore.batch();

      // 1. Delete debit note
      batch.delete(_debitNotesCollection.doc(debitNoteId));

      // 2. Restore bill's amountDue
      if (existingDebitNote.againstBillId != null) {
        final billRef =
            _sharedDocumentsCollection.doc(existingDebitNote.againstBillId);
        batch.update(billRef, {
          'amountDue': FieldValue.increment(existingDebitNote.grandTotal),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 3. Restore vendor's outstanding balance
      if (existingDebitNote.vendorId != null) {
        final vendorRef =
            _vendorsCollection.doc(existingDebitNote.vendorId);
        batch.update(vendorRef, {
          'outstandingBalance':
              FieldValue.increment(existingDebitNote.grandTotal),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Note: Journal entry reversal would need to be handled separately
      // For now, we leave the journal entry as-is (audit trail)

      return true;
    } catch (e) {
      debugPrint('Error deleting debit note: $e');
      return false;
    }
  }

  /// Mark debit note as sent (after sending to vendor via Vyapar ID)
  Future<bool> markAsSent(String debitNoteId) async {
    if (_userId == null) return false;

    try {
      final existingDebitNote = await getDebitNoteById(debitNoteId);
      if (existingDebitNote == null ||
          existingDebitNote.userId != _userId) {
        return false;
      }

      await _debitNotesCollection.doc(debitNoteId).update({
        'status': DebitNoteStatus.sent,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error marking debit note as sent: $e');
      return false;
    }
  }

  /// Get recorded bills (received invoices) available for debit note creation
  /// Returns bills that are recorded and have outstanding balance
  Future<List<SharedDocument>> getRecordedBillsForDebitNote() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _sharedDocumentsCollection
          .where('receiverUserId', isEqualTo: _userId)
          .where('documentType', isEqualTo: 'invoice')
          .where('recordingStatus', isEqualTo: 'recorded')
          .orderBy('sharedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => SharedDocument.fromFirestore(doc))
          .where((doc) => doc.effectiveAmountDue > 0) // Has outstanding balance
          .toList();
    } catch (e) {
      debugPrint('Error getting bills for debit note: $e');
      return [];
    }
  }

  /// Get total debit notes issued in a date range
  Future<double> getTotalDebitNotesInRange(
      DateTime startDate, DateTime endDate) async {
    if (_userId == null) return 0;

    try {
      final snapshot = await _debitNotesCollection
          .where('userId', isEqualTo: _userId)
          .where('debitNoteDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('debitNoteDate',
              isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      double total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total += (data['grandTotal'] ?? 0).toDouble();
      }
      return total;
    } catch (e) {
      debugPrint('Error getting total debit notes: $e');
      return 0;
    }
  }

  /// Get debit notes for a specific vendor
  Future<List<DebitNote>> getDebitNotesForVendor(String vendorId) async {
    if (_userId == null) return [];

    try {
      final snapshot = await _debitNotesCollection
          .where('userId', isEqualTo: _userId)
          .where('vendorId', isEqualTo: vendorId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return DebitNote.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Error getting debit notes for vendor: $e');
      return [];
    }
  }
}
