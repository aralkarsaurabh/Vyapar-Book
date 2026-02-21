import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single payment mode (cash or bank) in a split payment
class PaymentMode {
  String type; // 'cash' or 'bank'
  String? bankAccountId; // If bank, which account (from chart of accounts)
  String? bankName; // Display name (e.g., "HDFC Bank - 1234")
  double amount;

  PaymentMode({
    required this.type,
    this.bankAccountId,
    this.bankName,
    this.amount = 0,
  });

  factory PaymentMode.fromMap(Map<String, dynamic> map) {
    return PaymentMode(
      type: map['type'] ?? 'cash',
      bankAccountId: map['bankAccountId'],
      bankName: map['bankName'],
      amount: (map['amount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'bankAccountId': bankAccountId,
      'bankName': bankName,
      'amount': amount,
    };
  }

  bool get isCash => type == 'cash';
  bool get isBank => type == 'bank';
}

/// Represents a payment received from a customer for an invoice
class Payment {
  String? id;
  String? userId;
  String? paymentNumber; // TPL/REC/2025-26/001

  // Invoice reference
  String invoiceId;
  String? invoiceNumber;
  String? customerId;
  String? customerName;

  // Payment details
  DateTime paymentDate;
  double totalAmount;
  List<PaymentMode> modes; // Split payment support

  // Optional note
  String? note;

  DateTime? createdAt;

  Payment({
    this.id,
    this.userId,
    this.paymentNumber,
    required this.invoiceId,
    this.invoiceNumber,
    this.customerId,
    this.customerName,
    required this.paymentDate,
    this.totalAmount = 0,
    List<PaymentMode>? modes,
    this.note,
    this.createdAt,
  }) : modes = modes ?? [];

  factory Payment.fromMap(Map<String, dynamic> map, String docId) {
    return Payment(
      id: docId,
      userId: map['userId'],
      paymentNumber: map['paymentNumber'],
      invoiceId: map['invoiceId'] ?? '',
      invoiceNumber: map['invoiceNumber'],
      customerId: map['customerId'],
      customerName: map['customerName'],
      paymentDate: (map['paymentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      'invoiceId': invoiceId,
      'invoiceNumber': invoiceNumber,
      'customerId': customerId,
      'customerName': customerName,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'totalAmount': totalAmount,
      'modes': modes.map((m) => m.toMap()).toList(),
      'note': note,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
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
        result[mode.bankAccountId!] = (result[mode.bankAccountId] ?? 0) + mode.amount;
      }
    }

    return result;
  }
}
