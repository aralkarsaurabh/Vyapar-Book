import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of transactions that generate journal entries
class TransactionType {
  static const String salesInvoice = 'sales_invoice';
  static const String paymentReceived = 'payment_received';
  static const String purchaseBill = 'purchase_bill';
  static const String paymentMade = 'payment_made';
  static const String creditNote = 'credit_note';
  static const String debitNote = 'debit_note';
  static const String openingBalance = 'opening_balance';
  static const String adjustment = 'adjustment';
}

/// A single line in a journal entry (debit or credit to an account)
class JournalLine {
  String? accountId;
  String? accountCode;
  String? accountName;
  double debit;
  double credit;

  JournalLine({
    this.accountId,
    this.accountCode,
    this.accountName,
    this.debit = 0.0,
    this.credit = 0.0,
  });

  factory JournalLine.fromMap(Map<String, dynamic> map) {
    return JournalLine(
      accountId: map['accountId'] as String?,
      accountCode: map['accountCode'] as String?,
      accountName: map['accountName'] as String?,
      debit: (map['debit'] as num?)?.toDouble() ?? 0.0,
      credit: (map['credit'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accountId': accountId,
      'accountCode': accountCode,
      'accountName': accountName,
      'debit': debit,
      'credit': credit,
    };
  }

  /// Check if this line is a debit entry
  bool get isDebit => debit > 0;

  /// Check if this line is a credit entry
  bool get isCredit => credit > 0;

  /// Get the amount (either debit or credit)
  double get amount => debit > 0 ? debit : credit;
}

/// Represents a complete journal entry with multiple debit/credit lines
class JournalEntry {
  String? id;
  String? userId;
  String? entryNumber; // JE-2025-0001
  DateTime? date;
  String? narration; // Description of the transaction

  // Reference to the source document
  String? referenceType; // TransactionType
  String? referenceId; // Document ID (invoice, payment, etc.)
  String? referenceNumber; // Human-readable number (INV/2025/001)

  // The actual entry lines
  List<JournalLine> entries;

  // Totals for validation
  double totalDebit;
  double totalCredit;

  // Metadata
  bool isPosted; // Once posted, entry cannot be modified
  bool isReversed; // If this entry has been reversed
  String? reversedByEntryId; // ID of the reversing entry
  DateTime? createdAt;

  JournalEntry({
    this.id,
    this.userId,
    this.entryNumber,
    this.date,
    this.narration,
    this.referenceType,
    this.referenceId,
    this.referenceNumber,
    List<JournalLine>? entries,
    this.totalDebit = 0.0,
    this.totalCredit = 0.0,
    this.isPosted = true,
    this.isReversed = false,
    this.reversedByEntryId,
    this.createdAt,
  }) : entries = entries ?? [];

  factory JournalEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JournalEntry.fromMap(data, doc.id);
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map, String docId) {
    final entriesList = (map['entries'] as List<dynamic>?)
            ?.map((e) => JournalLine.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    return JournalEntry(
      id: docId,
      userId: map['userId'] as String?,
      entryNumber: map['entryNumber'] as String?,
      date: map['date'] != null ? (map['date'] as Timestamp).toDate() : null,
      narration: map['narration'] as String?,
      referenceType: map['referenceType'] as String?,
      referenceId: map['referenceId'] as String?,
      referenceNumber: map['referenceNumber'] as String?,
      entries: entriesList,
      totalDebit: (map['totalDebit'] as num?)?.toDouble() ?? 0.0,
      totalCredit: (map['totalCredit'] as num?)?.toDouble() ?? 0.0,
      isPosted: map['isPosted'] as bool? ?? true,
      isReversed: map['isReversed'] as bool? ?? false,
      reversedByEntryId: map['reversedByEntryId'] as String?,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'entryNumber': entryNumber,
      'date': date != null ? Timestamp.fromDate(date!) : null,
      'narration': narration,
      'referenceType': referenceType,
      'referenceId': referenceId,
      'referenceNumber': referenceNumber,
      'entries': entries.map((e) => e.toMap()).toList(),
      'totalDebit': totalDebit,
      'totalCredit': totalCredit,
      'isPosted': isPosted,
      'isReversed': isReversed,
      'reversedByEntryId': reversedByEntryId,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  /// Calculate totals from entries
  void calculateTotals() {
    totalDebit = entries.fold(0.0, (sum, line) => sum + line.debit);
    totalCredit = entries.fold(0.0, (sum, line) => sum + line.credit);
  }

  /// Check if the entry is balanced (debits = credits)
  bool get isBalanced {
    calculateTotals();
    // Allow for small floating point differences
    return (totalDebit - totalCredit).abs() < 0.01;
  }

  /// Add a debit line
  void addDebit(String accountId, String accountName, double amount, {String? accountCode}) {
    if (amount > 0) {
      entries.add(JournalLine(
        accountId: accountId,
        accountCode: accountCode,
        accountName: accountName,
        debit: amount,
        credit: 0,
      ));
    }
  }

  /// Add a credit line
  void addCredit(String accountId, String accountName, double amount, {String? accountCode}) {
    if (amount > 0) {
      entries.add(JournalLine(
        accountId: accountId,
        accountCode: accountCode,
        accountName: accountName,
        debit: 0,
        credit: amount,
      ));
    }
  }
}
