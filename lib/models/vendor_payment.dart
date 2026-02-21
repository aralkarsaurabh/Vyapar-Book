import 'package:cloud_firestore/cloud_firestore.dart';
import 'payment.dart'; // Reuse PaymentMode

/// Represents a payment made to a vendor for a bill (received invoice)
class VendorPayment {
  String? id;
  String? userId;
  String? paymentNumber; // TPL/PAY/2025-26/001

  // Bill reference (the received invoice we're paying)
  String sharedDocumentId; // Reference to shared document
  String? billNumber; // Original invoice number from vendor
  String? vendorId;
  String? vendorName;

  // Payment details
  DateTime paymentDate;
  double totalAmount;
  List<PaymentMode> modes; // Split payment support (reuse from Payment)

  // Optional note
  String? note;

  DateTime? createdAt;

  VendorPayment({
    this.id,
    this.userId,
    this.paymentNumber,
    required this.sharedDocumentId,
    this.billNumber,
    this.vendorId,
    this.vendorName,
    required this.paymentDate,
    this.totalAmount = 0,
    List<PaymentMode>? modes,
    this.note,
    this.createdAt,
  }) : modes = modes ?? [];

  factory VendorPayment.fromMap(Map<String, dynamic> map, String docId) {
    return VendorPayment(
      id: docId,
      userId: map['userId'],
      paymentNumber: map['paymentNumber'],
      sharedDocumentId: map['sharedDocumentId'] ?? '',
      billNumber: map['billNumber'],
      vendorId: map['vendorId'],
      vendorName: map['vendorName'],
      paymentDate:
          (map['paymentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      modes: (map['modes'] as List<dynamic>?)
              ?.map((m) => PaymentMode.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      note: map['note'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'paymentNumber': paymentNumber,
      'sharedDocumentId': sharedDocumentId,
      'billNumber': billNumber,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'totalAmount': totalAmount,
      'modes': modes.map((m) => m.toMap()).toList(),
      'note': note,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  /// Calculate total from all payment modes
  void calculateTotal() {
    totalAmount = modes.fold(0, (total, mode) => total + mode.amount);
  }

  /// Get a map of accountId -> amount for journal entry creation
  Map<String, double> getPaymentModesMap(String cashAccountId) {
    final Map<String, double> result = {};

    for (final mode in modes) {
      if (mode.amount <= 0) continue;

      if (mode.isCash) {
        result[cashAccountId] = (result[cashAccountId] ?? 0) + mode.amount;
      } else if (mode.bankAccountId != null) {
        result[mode.bankAccountId!] =
            (result[mode.bankAccountId] ?? 0) + mode.amount;
      }
    }

    return result;
  }
}
