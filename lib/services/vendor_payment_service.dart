import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/vendor_payment.dart';
import 'profile_service.dart';
import 'accounting_service.dart';
import 'invoice_service.dart';

/// Payment status constants for bills (received invoices)
class BillPaymentStatus {
  static const String unpaid = 'unpaid';
  static const String partial = 'partial';
  static const String paid = 'paid';
}

/// Recording status for received invoices
class BillRecordingStatus {
  static const String pending = 'pending'; // Just received, not recorded
  static const String recorded = 'recorded'; // Recorded as bill in books
}

class VendorPaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProfileService _profileService = ProfileService();
  final AccountingService _accountingService = AccountingService();

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference get _vendorPaymentsCollection =>
      _firestore.collection('vendorPayments');

  CollectionReference get _sharedDocumentsCollection =>
      _firestore.collection('sharedDocuments');

  CollectionReference get _vendorsCollection =>
      _firestore.collection('vendors');

  /// Generate payment number: PREFIX/PAY/YYYY-YY/NNN (e.g., TPL/PAY/2025-26/001)
  Future<String> generatePaymentNumber() async {
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
    final prefix = '$companyInitials/PAY/$financialYear/';

    try {
      // Get all vendor payments for this user in this financial year
      final startDate = DateTime(year, 4, 1);
      final endDate = DateTime(nextYear, 3, 31, 23, 59, 59);

      final snapshot = await _vendorPaymentsCollection
          .where('userId', isEqualTo: _userId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('createdAt', descending: true)
          .get();

      int nextNumber = 1;

      if (snapshot.docs.isNotEmpty) {
        // Find the highest sequence number from existing payments
        final numberRegex = RegExp(r'/PAY/\d{4}-\d{2}/(\d+)$');
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final pNumber = data['paymentNumber'] as String?;
          if (pNumber != null) {
            final match = numberRegex.firstMatch(pNumber);
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
      debugPrint('Error generating vendor payment number: $e');
      // Fallback: count existing payments + 1
      try {
        final countSnapshot = await _vendorPaymentsCollection
            .where('userId', isEqualTo: _userId)
            .get();
        final nextNumber = countSnapshot.docs.length + 1;
        return '$prefix${nextNumber.toString().padLeft(3, '0')}';
      } catch (_) {
        return '${prefix}001';
      }
    }
  }

  /// Record a payment made to a vendor
  /// This updates the shared document payment status and creates a journal entry
  Future<String?> recordPaymentMade(VendorPayment payment) async {
    if (_userId == null) return null;

    try {
      // Generate payment number
      payment.userId = _userId;
      payment.paymentNumber = await generatePaymentNumber();
      payment.createdAt = DateTime.now();

      // Calculate total from modes
      payment.calculateTotal();

      // Start a batch write
      final batch = _firestore.batch();

      // 1. Save payment record
      final paymentRef = _vendorPaymentsCollection.doc();
      batch.set(paymentRef, payment.toMap());

      // 2. Update shared document payment status
      final sharedDocRef =
          _sharedDocumentsCollection.doc(payment.sharedDocumentId);
      final sharedDoc = await sharedDocRef.get();

      if (!sharedDoc.exists) {
        throw Exception('Bill not found');
      }

      final sharedDocData = sharedDoc.data() as Map<String, dynamic>;
      final currentPaid = (sharedDocData['amountPaid'] ?? 0).toDouble();
      final grandTotal = (sharedDocData['grandTotal'] ?? 0).toDouble();
      final newPaid = currentPaid + payment.totalAmount;
      final newDue = grandTotal - newPaid;

      // Determine new payment status
      String newStatus;
      if (newPaid >= grandTotal) {
        newStatus = BillPaymentStatus.paid;
      } else if (newPaid > 0) {
        newStatus = BillPaymentStatus.partial;
      } else {
        newStatus = BillPaymentStatus.unpaid;
      }

      batch.update(sharedDocRef, {
        'amountPaid': newPaid,
        'amountDue': newDue < 0 ? 0 : newDue,
        'paymentStatus': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Update vendor outstanding balance (if vendor exists)
      if (payment.vendorId != null && payment.vendorId!.isNotEmpty) {
        final vendorRef = _vendorsCollection.doc(payment.vendorId);
        batch.update(vendorRef, {
          'outstandingBalance': FieldValue.increment(-payment.totalAmount),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Commit the batch
      await batch.commit();

      // 4. Create journal entry (outside batch because it involves multiple queries)
      try {
        final cashAccount = await _accountingService.getCashAccount();
        if (cashAccount == null) {
          debugPrint('Cash account not found, skipping journal entry');
        } else {
          final paymentModes = payment.getPaymentModesMap(cashAccount.id!);

          await _accountingService.recordPaymentMade(
            paymentId: paymentRef.id,
            paymentNumber: payment.paymentNumber!,
            vendorName: payment.vendorName ?? '',
            billNumber: payment.billNumber ?? '',
            paymentDate: payment.paymentDate,
            totalAmount: payment.totalAmount,
            paymentModes: paymentModes,
          );
        }
      } catch (e) {
        debugPrint('Error creating vendor payment journal entry: $e');
        // Don't fail payment recording if accounting fails
      }

      return paymentRef.id;
    } catch (e) {
      debugPrint('Error recording vendor payment: $e');
      return null;
    }
  }

  /// Get all vendor payments for the current user
  Stream<List<VendorPayment>> getVendorPayments() {
    if (_userId == null) return Stream.value([]);

    return _vendorPaymentsCollection
        .where('userId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return VendorPayment.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Get payments for a specific bill (shared document)
  Stream<List<VendorPayment>> getPaymentsForBill(String sharedDocumentId) {
    if (_userId == null) return Stream.value([]);

    return _vendorPaymentsCollection
        .where('userId', isEqualTo: _userId)
        .where('sharedDocumentId', isEqualTo: sharedDocumentId)
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return VendorPayment.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Get payments for a specific bill (non-stream version)
  Future<List<VendorPayment>> getPaymentsForBillOnce(
      String sharedDocumentId) async {
    if (_userId == null) return [];

    try {
      final snapshot = await _vendorPaymentsCollection
          .where('userId', isEqualTo: _userId)
          .where('sharedDocumentId', isEqualTo: sharedDocumentId)
          .orderBy('paymentDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return VendorPayment.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Error getting payments for bill: $e');
      return [];
    }
  }

  /// Get a single vendor payment by ID
  Future<VendorPayment?> getPaymentById(String paymentId) async {
    if (_userId == null) return null;

    try {
      final doc = await _vendorPaymentsCollection.doc(paymentId).get();
      if (doc.exists) {
        final payment = VendorPayment.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
        if (payment.userId == _userId) {
          return payment;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting vendor payment: $e');
      return null;
    }
  }

  /// Get total payments made in a date range
  Future<double> getTotalPaymentsInRange(
      DateTime startDate, DateTime endDate) async {
    if (_userId == null) return 0;

    try {
      final snapshot = await _vendorPaymentsCollection
          .where('userId', isEqualTo: _userId)
          .where('paymentDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('paymentDate',
              isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      double total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total += (data['totalAmount'] ?? 0).toDouble();
      }
      return total;
    } catch (e) {
      debugPrint('Error getting total vendor payments: $e');
      return 0;
    }
  }

  /// Record a bill (received invoice) - creates accounting entry
  /// This is called when user clicks "Record Bill" on a received invoice
  Future<bool> recordBill({
    required String sharedDocumentId,
    required String billNumber,
    required String vendorName,
    required DateTime billDate,
    required double subtotal,
    required double grandTotal,
    required double cgstAmount,
    required double sgstAmount,
    required double igstAmount,
    String? vendorId,
  }) async {
    if (_userId == null) return false;

    try {
      final batch = _firestore.batch();

      // 1. Update shared document to mark as recorded
      final sharedDocRef = _sharedDocumentsCollection.doc(sharedDocumentId);
      batch.update(sharedDocRef, {
        'recordingStatus': BillRecordingStatus.recorded,
        'paymentStatus': BillPaymentStatus.unpaid,
        'amountPaid': 0,
        'amountDue': grandTotal,
        'recordedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update vendor outstanding balance (if vendor exists)
      if (vendorId != null && vendorId.isNotEmpty) {
        final vendorRef = _vendorsCollection.doc(vendorId);
        batch.update(vendorRef, {
          'outstandingBalance': FieldValue.increment(grandTotal),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // 3. Create journal entry for purchase
      try {
        await _accountingService.recordPurchaseBill(
          billId: sharedDocumentId,
          billNumber: billNumber,
          vendorName: vendorName,
          billDate: billDate,
          subtotal: subtotal,
          grandTotal: grandTotal,
          cgstAmount: cgstAmount,
          sgstAmount: sgstAmount,
          igstAmount: igstAmount,
        );
      } catch (e) {
        debugPrint('Error creating purchase journal entry: $e');
        // Don't fail if accounting fails - bill is still recorded
      }

      return true;
    } catch (e) {
      debugPrint('Error recording bill: $e');
      return false;
    }
  }

  /// Check if a bill has already been recorded
  Future<bool> isBillRecorded(String sharedDocumentId) async {
    try {
      final doc =
          await _sharedDocumentsCollection.doc(sharedDocumentId).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      return data['recordingStatus'] == BillRecordingStatus.recorded;
    } catch (e) {
      debugPrint('Error checking bill status: $e');
      return false;
    }
  }

  /// Get bill payment info (amount due, amount paid, status)
  Future<Map<String, dynamic>?> getBillPaymentInfo(
      String sharedDocumentId) async {
    try {
      final doc =
          await _sharedDocumentsCollection.doc(sharedDocumentId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      return {
        'grandTotal': (data['grandTotal'] ?? 0).toDouble(),
        'amountPaid': (data['amountPaid'] ?? 0).toDouble(),
        'amountDue': (data['amountDue'] ?? data['grandTotal'] ?? 0).toDouble(),
        'paymentStatus': data['paymentStatus'] ?? BillPaymentStatus.unpaid,
        'recordingStatus':
            data['recordingStatus'] ?? BillRecordingStatus.pending,
      };
    } catch (e) {
      debugPrint('Error getting bill payment info: $e');
      return null;
    }
  }
}
