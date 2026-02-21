import 'package:cloud_firestore/cloud_firestore.dart';

/// Account types in the chart of accounts
class AccountType {
  static const String asset = 'asset';
  static const String liability = 'liability';
  static const String income = 'income';
  static const String expense = 'expense';
  static const String equity = 'equity';
}

/// Account sub-types for more granular categorization
class AccountSubType {
  // Assets
  static const String cash = 'cash';
  static const String bank = 'bank';
  static const String receivable = 'receivable';
  static const String gstInput = 'gst_input';

  // Liabilities
  static const String payable = 'payable';
  static const String gstOutput = 'gst_output';

  // Income
  static const String sales = 'sales';
  static const String salesReturn = 'sales_return';
  static const String otherIncome = 'other_income';

  // Expenses
  static const String purchases = 'purchases';
  static const String purchaseReturn = 'purchase_return';
  static const String discount = 'discount';
  static const String bankCharges = 'bank_charges';
  static const String otherExpense = 'other_expense';

  // Equity
  static const String capital = 'capital';
}

/// Represents an account in the chart of accounts
class Account {
  String? id;
  String? userId;
  String? code; // Unique code like ACC001, ACC002
  String? name;
  String? type; // AccountType
  String? subType; // AccountSubType
  String? description;
  double balance;
  bool isSystemAccount; // Pre-created accounts that can't be deleted
  bool isActive;
  String? linkedBankId; // For bank accounts synced from company profile
  DateTime? createdAt;
  DateTime? updatedAt;

  Account({
    this.id,
    this.userId,
    this.code,
    this.name,
    this.type,
    this.subType,
    this.description,
    this.balance = 0.0,
    this.isSystemAccount = true,
    this.isActive = true,
    this.linkedBankId,
    this.createdAt,
    this.updatedAt,
  });

  factory Account.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Account.fromMap(data, doc.id);
  }

  factory Account.fromMap(Map<String, dynamic> map, String docId) {
    return Account(
      id: docId,
      userId: map['userId'] as String?,
      code: map['code'] as String?,
      name: map['name'] as String?,
      type: map['type'] as String?,
      subType: map['subType'] as String?,
      description: map['description'] as String?,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      isSystemAccount: map['isSystemAccount'] as bool? ?? true,
      isActive: map['isActive'] as bool? ?? true,
      linkedBankId: map['linkedBankId'] as String?,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'code': code,
      'name': name,
      'type': type,
      'subType': subType,
      'description': description,
      'balance': balance,
      'isSystemAccount': isSystemAccount,
      'isActive': isActive,
      'linkedBankId': linkedBankId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Check if this is a debit-normal account (Assets, Expenses)
  bool get isDebitNormal => type == AccountType.asset || type == AccountType.expense;

  /// Check if this is a credit-normal account (Liabilities, Income, Equity)
  bool get isCreditNormal =>
      type == AccountType.liability ||
      type == AccountType.income ||
      type == AccountType.equity;
}
