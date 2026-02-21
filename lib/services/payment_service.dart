import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/payment.dart';
import 'profile_service.dart';
import 'accounting_service.dart';
import 'invoice_service.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProfileService _profileService = ProfileService();
  final AccountingService _accountingService = AccountingService();

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference get _paymentsCollection =>
      _firestore.collection('payments');

  CollectionReference get _invoicesCollection =>
      _firestore.collection('invoices');

  // Generate payment number: PREFIX/REC/YYYY-YY/NNN (e.g., TPL/REC/2025-26/001)
  Future<String> generatePaymentNumber() async {
    if (_userId == null) return '';

    // Get company profile to extract initials
    final companyProfile = await _profileService.getCompanyProfile();
    final companyInitials = InvoiceService.getCompanyInitials(companyProfile?.companyLegalName);

    final now = DateTime.now();
    // Financial year: April to March
    final year = now.month >= 4 ? now.year : now.year - 1;
    final nextYear = year + 1;
    final financialYear = '$year-${nextYear.toString().substring(2)}';
    final prefix = '$companyInitials/REC/$financialYear/';

    try {
      // Get all payments for this user in this financial year
      final startDate = DateTime(year, 4, 1);
      final endDate = DateTime(nextYear, 3, 31, 23, 59, 59);

      final snapshot = await _paymentsCollection
          .where('userId', isEqualTo: _userId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('createdAt', descending: true)
          .get();

      int nextNumber = 1;

      if (snapshot.docs.isNotEmpty) {
        // Find the highest sequence number from existing payments
        final numberRegex = RegExp(r'/REC/\d{4}-\d{2}/(\d+)$');
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
      debugPrint('Error generating payment number: $e');
      // Fallback: count existing payments + 1
      try {
        final countSnapshot = await _paymentsCollection
            .where('userId', isEqualTo: _userId)
            .get();
        final nextNumber = countSnapshot.docs.length + 1;
        return '$prefix${nextNumber.toString().padLeft(3, '0')}';
      } catch (_) {
        return '${prefix}001';
      }
    }
  }

  /// Record a payment for an invoice
  /// This updates the invoice payment status and creates a journal entry
  Future<String?> recordPayment(Payment payment) async {
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
      final paymentRef = _paymentsCollection.doc();
      batch.set(paymentRef, payment.toMap());

      // 2. Update invoice payment status
      final invoiceRef = _invoicesCollection.doc(payment.invoiceId);
      final invoiceDoc = await invoiceRef.get();

      if (!invoiceDoc.exists) {
        throw Exception('Invoice not found');
      }

      final invoiceData = invoiceDoc.data() as Map<String, dynamic>;
      final currentPaid = (invoiceData['amountPaid'] ?? 0).toDouble();
      final grandTotal = (invoiceData['grandTotal'] ?? 0).toDouble();
      final newPaid = currentPaid + payment.totalAmount;
      final newDue = grandTotal - newPaid;

      // Determine new payment status
      String newStatus;
      if (newPaid >= grandTotal) {
        newStatus = PaymentStatus.paid;
      } else if (newPaid > 0) {
        newStatus = PaymentStatus.partial;
      } else {
        newStatus = PaymentStatus.unpaid;
      }

      batch.update(invoiceRef, {
        'amountPaid': newPaid,
        'amountDue': newDue < 0 ? 0 : newDue,
        'paymentStatus': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Commit the batch
      await batch.commit();

      // 3. Create journal entry (outside batch because it involves multiple queries)
      try {
        final cashAccount = await _accountingService.getCashAccount();
        if (cashAccount == null) {
          debugPrint('Cash account not found, skipping journal entry');
        } else {
          final paymentModes = payment.getPaymentModesMap(cashAccount.id!);

          await _accountingService.recordPaymentReceived(
            paymentId: paymentRef.id,
            paymentNumber: payment.paymentNumber!,
            customerName: payment.customerName ?? '',
            invoiceNumber: payment.invoiceNumber ?? '',
            paymentDate: payment.paymentDate,
            totalAmount: payment.totalAmount,
            paymentModes: paymentModes,
          );
        }
      } catch (e) {
        debugPrint('Error creating payment journal entry: $e');
        // Don't fail payment recording if accounting fails
      }

      return paymentRef.id;
    } catch (e) {
      debugPrint('Error recording payment: $e');
      return null;
    }
  }

  /// Get all payments for the current user
  Stream<List<Payment>> getPayments() {
    if (_userId == null) return Stream.value([]);

    return _paymentsCollection
        .where('userId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Payment.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Get payments for a specific invoice
  Stream<List<Payment>> getPaymentsForInvoice(String invoiceId) {
    if (_userId == null) return Stream.value([]);

    return _paymentsCollection
        .where('userId', isEqualTo: _userId)
        .where('invoiceId', isEqualTo: invoiceId)
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Payment.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Get payments for a specific invoice (non-stream version)
  Future<List<Payment>> getPaymentsForInvoiceOnce(String invoiceId) async {
    if (_userId == null) return [];

    try {
      final snapshot = await _paymentsCollection
          .where('userId', isEqualTo: _userId)
          .where('invoiceId', isEqualTo: invoiceId)
          .orderBy('paymentDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return Payment.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Error getting payments for invoice: $e');
      return [];
    }
  }

  /// Get a single payment by ID
  Future<Payment?> getPaymentById(String paymentId) async {
    if (_userId == null) return null;

    try {
      final doc = await _paymentsCollection.doc(paymentId).get();
      if (doc.exists) {
        final payment = Payment.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        if (payment.userId == _userId) {
          return payment;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting payment: $e');
      return null;
    }
  }

  /// Get total payments received in a date range
  Future<double> getTotalPaymentsInRange(DateTime startDate, DateTime endDate) async {
    if (_userId == null) return 0;

    try {
      final snapshot = await _paymentsCollection
          .where('userId', isEqualTo: _userId)
          .where('paymentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('paymentDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      double total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total += (data['totalAmount'] ?? 0).toDouble();
      }
      return total;
    } catch (e) {
      debugPrint('Error getting total payments: $e');
      return 0;
    }
  }
}
