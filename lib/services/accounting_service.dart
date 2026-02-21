import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/journal_entry.dart';
import 'profile_service.dart';
import 'invoice_service.dart';

/// Service for managing the chart of accounts and journal entries
class AccountingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // Collection references
  CollectionReference get _accountsRef => _firestore.collection('accounts');
  CollectionReference get _journalEntriesRef => _firestore.collection('journalEntries');

  // ==================== ACCOUNT MANAGEMENT ====================

  /// Get all accounts for the current user
  Stream<List<Account>> getAccounts() {
    if (_userId == null) return Stream.value([]);

    return _accountsRef
        .where('userId', isEqualTo: _userId)
        .where('isActive', isEqualTo: true)
        .orderBy('code')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Account.fromFirestore(doc)).toList());
  }

  /// Get accounts by type
  Stream<List<Account>> getAccountsByType(String type) {
    if (_userId == null) return Stream.value([]);

    return _accountsRef
        .where('userId', isEqualTo: _userId)
        .where('type', isEqualTo: type)
        .where('isActive', isEqualTo: true)
        .orderBy('code')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Account.fromFirestore(doc)).toList());
  }

  /// Get a single account by subType (e.g., get the Accounts Receivable account)
  Future<Account?> getAccountBySubType(String subType) async {
    if (_userId == null) return null;

    final query = await _accountsRef
        .where('userId', isEqualTo: _userId)
        .where('subType', isEqualTo: subType)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return Account.fromFirestore(query.docs.first);
  }

  /// Get account by ID
  Future<Account?> getAccountById(String accountId) async {
    final doc = await _accountsRef.doc(accountId).get();
    if (!doc.exists) return null;
    return Account.fromFirestore(doc);
  }

  /// Get bank accounts (for payment recording)
  Future<List<Account>> getBankAccounts() async {
    if (_userId == null) return [];

    final query = await _accountsRef
        .where('userId', isEqualTo: _userId)
        .where('subType', isEqualTo: AccountSubType.bank)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .get();

    return query.docs.map((doc) => Account.fromFirestore(doc)).toList();
  }

  /// Get cash account
  Future<Account?> getCashAccount() async {
    return getAccountBySubType(AccountSubType.cash);
  }

  /// Check if accounts are already initialized for user
  Future<bool> areAccountsInitialized() async {
    if (_userId == null) return false;

    final query = await _accountsRef
        .where('userId', isEqualTo: _userId)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  /// Initialize the chart of accounts for a new user
  /// Creates 18-20 default accounts
  Future<void> initializeAccounts() async {
    if (_userId == null) return;

    // Check if already initialized
    if (await areAccountsInitialized()) return;

    final batch = _firestore.batch();
    int accountIndex = 1;

    String getCode() {
      final code = 'ACC${accountIndex.toString().padLeft(3, '0')}';
      accountIndex++;
      return code;
    }

    // ===== ASSETS =====
    final assetAccounts = [
      Account(
        userId: _userId,
        code: getCode(),
        name: 'Cash',
        type: AccountType.asset,
        subType: AccountSubType.cash,
        description: 'Physical cash in hand',
        isSystemAccount: true,
      ),
      Account(
        userId: _userId,
        code: getCode(),
        name: 'Accounts Receivable',
        type: AccountType.asset,
        subType: AccountSubType.receivable,
        description: 'Money customers owe you',
        isSystemAccount: true,
      ),
      Account(
        userId: _userId,
        code: getCode(),
        name: 'GST Input (CGST)',
        type: AccountType.asset,
        subType: AccountSubType.gstInput,
        description: 'CGST credit from purchases',
        isSystemAccount: true,
      ),
      Account(
        userId: _userId,
        code: getCode(),
        name: 'GST Input (SGST)',
        type: AccountType.asset,
        subType: AccountSubType.gstInput,
        description: 'SGST credit from purchases',
        isSystemAccount: true,
      ),
      Account(
        userId: _userId,
        code: getCode(),
        name: 'GST Input (IGST)',
        type: AccountType.asset,
        subType: AccountSubType.gstInput,
        description: 'IGST credit from inter-state purchases',
        isSystemAccount: true,
      ),
    ];

    // ===== LIABILITIES =====
    final liabilityAccounts = [
      Account(
        userId: _userId,
        code: getCode(),
        name: 'Accounts Payable',
        type: AccountType.liability,
        subType: AccountSubType.payable,
        description: 'Money you owe to vendors',
        isSystemAccount: true,
      ),
      Account(
        userId: _userId,
        code: getCode(),
        name: 'GST Output (CGST)',
        type: AccountType.liability,
        subType: AccountSubType.gstOutput,
        description: 'CGST collected on sales',
        isSystemAccount: true,
      ),
      Account(
        userId: _userId,
        code: getCode(),
        name: 'GST Output (SGST)',
        type: AccountType.liability,
        subType: AccountSubType.gstOutput,
        description: 'SGST collected on sales',
        isSystemAccount: true,
      ),
      Account(
        userId: _userId,
        code: getCode(),
        name: 'GST Output (IGST)',
        type: AccountType.liability,
        subType: AccountSubType.gstOutput,
        description: 'IGST collected on inter-state sales',
        isSystemAccount: true,
      ),
    ];

    // ===== INCOME =====
    final incomeAccounts = [
      Account(
        userId: _userId,
        code: getCode(),
        name: 'Sales',
        type: AccountType.income,
        subType: AccountSubType.sales,
        description: 'Revenue from invoices',
        isSystemAccount: true,
      ),
      Account(
        userId: _userId,
        code: getCode(),
        name: 'Sales Return',
        type: AccountType.income,
        subType: AccountSubType.salesReturn,
        description: 'Goods returned by customers (contra account)',
        isSystemAccount: true,
      ),
      Account(
        userId: _userId,
        code: getCode(),
        name: 'Other Income',
        type: AccountType.income,
        subType: AccountSubType.otherIncome,
        description: 'Interest, discounts received, etc.',
        isSystemAccount: true,
      ),
    ];

    // ===== EXPENSES =====
    final expenseAccounts = [
      Account(
        userId: _userId,
        code: getCode(),
        name: 'Purchases',
        type: AccountType.expense,
        subType: AccountSubType.purchases,
        description: 'Cost of goods/services bought',
        isSystemAccount: true,
      ),
      Account(
        userId: _userId,
        code: getCode(),
        name: 'Purchase Return',
        type: AccountType.expense,
        subType: AccountSubType.purchaseReturn,
        description: 'Goods returned to vendors (contra account)',
        isSystemAccount: true,
      ),
      Account(
        userId: _userId,
        code: getCode(),
        name: 'Discount Given',
        type: AccountType.expense,
        subType: AccountSubType.discount,
        description: 'Discounts offered to customers',
        isSystemAccount: true,
      ),
      Account(
        userId: _userId,
        code: getCode(),
        name: 'Bank Charges',
        type: AccountType.expense,
        subType: AccountSubType.bankCharges,
        description: 'Bank fees, transaction charges',
        isSystemAccount: true,
      ),
      Account(
        userId: _userId,
        code: getCode(),
        name: 'Other Expenses',
        type: AccountType.expense,
        subType: AccountSubType.otherExpense,
        description: 'Miscellaneous expenses',
        isSystemAccount: true,
      ),
    ];

    // ===== EQUITY =====
    final equityAccounts = [
      Account(
        userId: _userId,
        code: getCode(),
        name: "Owner's Capital",
        type: AccountType.equity,
        subType: AccountSubType.capital,
        description: 'Initial investment / retained earnings',
        isSystemAccount: true,
      ),
    ];

    // Add all accounts to batch
    final allAccounts = [
      ...assetAccounts,
      ...liabilityAccounts,
      ...incomeAccounts,
      ...expenseAccounts,
      ...equityAccounts,
    ];

    for (final account in allAccounts) {
      final docRef = _accountsRef.doc();
      batch.set(docRef, account.toMap());
    }

    await batch.commit();
  }

  /// Sync bank accounts from company profile
  /// Creates bank accounts in chart of accounts if they don't exist
  Future<void> syncBankAccountsFromProfile(CompanyProfile profile) async {
    if (_userId == null) return;

    // Only sync if bank details are available
    if (profile.bankName == null || profile.bankName!.isEmpty) return;
    if (profile.accountNumber == null || profile.accountNumber!.isEmpty) return;

    // Create a unique identifier for this bank account
    final bankId = '${profile.bankName}_${profile.accountNumber}';

    // Check if this bank account already exists
    final existingQuery = await _accountsRef
        .where('userId', isEqualTo: _userId)
        .where('linkedBankId', isEqualTo: bankId)
        .limit(1)
        .get();

    if (existingQuery.docs.isNotEmpty) {
      // Update existing bank account if name changed
      final existingDoc = existingQuery.docs.first;
      final displayName = _formatBankAccountName(profile);
      if (existingDoc.data() is Map) {
        final data = existingDoc.data() as Map<String, dynamic>;
        if (data['name'] != displayName) {
          await existingDoc.reference.update({
            'name': displayName,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      return;
    }

    // Get the next account code
    final accountsQuery = await _accountsRef
        .where('userId', isEqualTo: _userId)
        .orderBy('code', descending: true)
        .limit(1)
        .get();

    String nextCode = 'ACC021';
    if (accountsQuery.docs.isNotEmpty) {
      final lastCode = (accountsQuery.docs.first.data() as Map<String, dynamic>)['code'] as String?;
      if (lastCode != null && lastCode.startsWith('ACC')) {
        final lastNum = int.tryParse(lastCode.substring(3)) ?? 20;
        nextCode = 'ACC${(lastNum + 1).toString().padLeft(3, '0')}';
      }
    }

    // Create new bank account
    final bankAccount = Account(
      userId: _userId,
      code: nextCode,
      name: _formatBankAccountName(profile),
      type: AccountType.asset,
      subType: AccountSubType.bank,
      description: 'Bank account synced from company profile',
      isSystemAccount: false,
      linkedBankId: bankId,
    );

    await _accountsRef.add(bankAccount.toMap());
  }

  String _formatBankAccountName(CompanyProfile profile) {
    final bankName = profile.bankName ?? 'Bank';
    final accountNumber = profile.accountNumber ?? '';
    final lastFour = accountNumber.length > 4
        ? accountNumber.substring(accountNumber.length - 4)
        : accountNumber;
    return '$bankName - $lastFour';
  }

  // ==================== JOURNAL ENTRIES ====================

  /// Generate the next journal entry number
  Future<String> _getNextEntryNumber() async {
    if (_userId == null) return 'JE-0001';

    final now = DateTime.now();
    final year = now.year;

    final query = await _journalEntriesRef
        .where('userId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    int nextNum = 1;
    if (query.docs.isNotEmpty) {
      final lastEntry = query.docs.first.data() as Map<String, dynamic>;
      final lastNumber = lastEntry['entryNumber'] as String?;
      if (lastNumber != null && lastNumber.contains('-')) {
        final parts = lastNumber.split('-');
        if (parts.length >= 2) {
          final lastNum = int.tryParse(parts.last) ?? 0;
          nextNum = lastNum + 1;
        }
      }
    }

    return 'JE-$year-${nextNum.toString().padLeft(4, '0')}';
  }

  /// Create a journal entry
  Future<String?> createJournalEntry(JournalEntry entry) async {
    if (_userId == null) return null;

    // Validate entry is balanced
    entry.calculateTotals();
    if (!entry.isBalanced) {
      throw Exception('Journal entry is not balanced: Debit=${entry.totalDebit}, Credit=${entry.totalCredit}');
    }

    entry.userId = _userId;
    entry.entryNumber = await _getNextEntryNumber();
    entry.createdAt = DateTime.now();

    final docRef = await _journalEntriesRef.add(entry.toMap());

    // Update account balances
    await _updateAccountBalances(entry);

    return docRef.id;
  }

  /// Update account balances based on journal entry
  Future<void> _updateAccountBalances(JournalEntry entry) async {
    final batch = _firestore.batch();

    for (final line in entry.entries) {
      if (line.accountId == null) continue;

      final accountRef = _accountsRef.doc(line.accountId);
      final accountDoc = await accountRef.get();

      if (!accountDoc.exists) continue;

      final account = Account.fromFirestore(accountDoc);
      double balanceChange = 0;

      // For debit-normal accounts (Assets, Expenses):
      // - Debit increases balance
      // - Credit decreases balance
      // For credit-normal accounts (Liabilities, Income, Equity):
      // - Credit increases balance
      // - Debit decreases balance
      if (account.isDebitNormal) {
        balanceChange = line.debit - line.credit;
      } else {
        balanceChange = line.credit - line.debit;
      }

      batch.update(accountRef, {
        'balance': FieldValue.increment(balanceChange),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Get journal entries for a specific reference
  Future<List<JournalEntry>> getEntriesByReference(String referenceType, String referenceId) async {
    if (_userId == null) return [];

    final query = await _journalEntriesRef
        .where('userId', isEqualTo: _userId)
        .where('referenceType', isEqualTo: referenceType)
        .where('referenceId', isEqualTo: referenceId)
        .get();

    return query.docs.map((doc) => JournalEntry.fromFirestore(doc)).toList();
  }

  /// Get all journal entries
  Stream<List<JournalEntry>> getJournalEntries() {
    if (_userId == null) return Stream.value([]);

    return _journalEntriesRef
        .where('userId', isEqualTo: _userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => JournalEntry.fromFirestore(doc)).toList());
  }

  /// Get journal entries for a specific account (for ledger report)
  Future<List<JournalEntry>> getEntriesForAccount(String accountId, {DateTime? startDate, DateTime? endDate}) async {
    if (_userId == null) return [];

    // We need to query all entries and filter client-side since Firestore
    // doesn't support array-contains with nested field queries
    Query query = _journalEntriesRef.where('userId', isEqualTo: _userId);

    if (startDate != null) {
      query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    final snapshot = await query.orderBy('date').get();

    // Filter entries that contain this account
    return snapshot.docs
        .map((doc) => JournalEntry.fromFirestore(doc))
        .where((entry) => entry.entries.any((line) => line.accountId == accountId))
        .toList();
  }

  // ==================== TRANSACTION RECORDING HELPERS ====================

  /// Record a sales invoice
  /// DR: Accounts Receivable (grandTotal)
  /// CR: Sales (subtotal after discount)
  /// CR: GST Output CGST (if applicable)
  /// CR: GST Output SGST (if applicable)
  /// CR: GST Output IGST (if applicable)
  Future<String?> recordSalesInvoice({
    required String invoiceId,
    required String invoiceNumber,
    required String customerName,
    required DateTime invoiceDate,
    required double subtotal,
    required double grandTotal,
    required double cgstAmount,
    required double sgstAmount,
    required double igstAmount,
    double discountAmount = 0,
  }) async {
    // Get required accounts
    final receivableAccount = await getAccountBySubType(AccountSubType.receivable);
    final salesAccount = await getAccountBySubType(AccountSubType.sales);

    if (receivableAccount == null || salesAccount == null) {
      throw Exception('Required accounts not found. Please initialize accounts first.');
    }

    final entry = JournalEntry(
      date: invoiceDate,
      narration: 'Sales to $customerName',
      referenceType: TransactionType.salesInvoice,
      referenceId: invoiceId,
      referenceNumber: invoiceNumber,
    );

    // DR: Accounts Receivable
    entry.addDebit(
      receivableAccount.id!,
      receivableAccount.name!,
      grandTotal,
      accountCode: receivableAccount.code,
    );

    // CR: Sales (subtotal - discount, as discount reduces sales)
    final netSales = subtotal - discountAmount;
    entry.addCredit(
      salesAccount.id!,
      salesAccount.name!,
      netSales,
      accountCode: salesAccount.code,
    );

    // CR: GST Output accounts
    if (cgstAmount > 0) {
      final cgstAccounts = await _accountsRef
          .where('userId', isEqualTo: _userId)
          .where('subType', isEqualTo: AccountSubType.gstOutput)
          .where('name', isEqualTo: 'GST Output (CGST)')
          .limit(1)
          .get();
      if (cgstAccounts.docs.isNotEmpty) {
        final acc = Account.fromFirestore(cgstAccounts.docs.first);
        entry.addCredit(acc.id!, acc.name!, cgstAmount, accountCode: acc.code);
      }
    }

    if (sgstAmount > 0) {
      final sgstAccounts = await _accountsRef
          .where('userId', isEqualTo: _userId)
          .where('subType', isEqualTo: AccountSubType.gstOutput)
          .where('name', isEqualTo: 'GST Output (SGST)')
          .limit(1)
          .get();
      if (sgstAccounts.docs.isNotEmpty) {
        final acc = Account.fromFirestore(sgstAccounts.docs.first);
        entry.addCredit(acc.id!, acc.name!, sgstAmount, accountCode: acc.code);
      }
    }

    if (igstAmount > 0) {
      final igstAccounts = await _accountsRef
          .where('userId', isEqualTo: _userId)
          .where('subType', isEqualTo: AccountSubType.gstOutput)
          .where('name', isEqualTo: 'GST Output (IGST)')
          .limit(1)
          .get();
      if (igstAccounts.docs.isNotEmpty) {
        final acc = Account.fromFirestore(igstAccounts.docs.first);
        entry.addCredit(acc.id!, acc.name!, igstAmount, accountCode: acc.code);
      }
    }

    return createJournalEntry(entry);
  }

  /// Record a payment received from customer
  /// DR: Cash/Bank (amount per mode)
  /// CR: Accounts Receivable (total amount)
  Future<String?> recordPaymentReceived({
    required String paymentId,
    required String paymentNumber,
    required String customerName,
    required String invoiceNumber,
    required DateTime paymentDate,
    required double totalAmount,
    required Map<String, double> paymentModes, // accountId -> amount
  }) async {
    final receivableAccount = await getAccountBySubType(AccountSubType.receivable);
    if (receivableAccount == null) {
      throw Exception('Accounts Receivable not found');
    }

    final entry = JournalEntry(
      date: paymentDate,
      narration: 'Payment from $customerName for $invoiceNumber',
      referenceType: TransactionType.paymentReceived,
      referenceId: paymentId,
      referenceNumber: paymentNumber,
    );

    // DR: Each payment mode (Cash/Bank accounts)
    for (final mode in paymentModes.entries) {
      if (mode.value > 0) {
        final account = await getAccountById(mode.key);
        if (account != null) {
          entry.addDebit(account.id!, account.name!, mode.value, accountCode: account.code);
        }
      }
    }

    // CR: Accounts Receivable
    entry.addCredit(
      receivableAccount.id!,
      receivableAccount.name!,
      totalAmount,
      accountCode: receivableAccount.code,
    );

    return createJournalEntry(entry);
  }

  /// Record a purchase bill (when accepting a received invoice)
  /// DR: Purchases (subtotal)
  /// DR: GST Input CGST/SGST/IGST (tax amounts)
  /// CR: Accounts Payable (grandTotal)
  Future<String?> recordPurchaseBill({
    required String billId,
    required String billNumber,
    required String vendorName,
    required DateTime billDate,
    required double subtotal,
    required double grandTotal,
    required double cgstAmount,
    required double sgstAmount,
    required double igstAmount,
  }) async {
    final purchasesAccount = await getAccountBySubType(AccountSubType.purchases);
    final payableAccount = await getAccountBySubType(AccountSubType.payable);

    if (purchasesAccount == null || payableAccount == null) {
      throw Exception('Required accounts not found');
    }

    final entry = JournalEntry(
      date: billDate,
      narration: 'Purchase from $vendorName',
      referenceType: TransactionType.purchaseBill,
      referenceId: billId,
      referenceNumber: billNumber,
    );

    // DR: Purchases
    entry.addDebit(
      purchasesAccount.id!,
      purchasesAccount.name!,
      subtotal,
      accountCode: purchasesAccount.code,
    );

    // DR: GST Input accounts
    if (cgstAmount > 0) {
      final cgstAccounts = await _accountsRef
          .where('userId', isEqualTo: _userId)
          .where('subType', isEqualTo: AccountSubType.gstInput)
          .where('name', isEqualTo: 'GST Input (CGST)')
          .limit(1)
          .get();
      if (cgstAccounts.docs.isNotEmpty) {
        final acc = Account.fromFirestore(cgstAccounts.docs.first);
        entry.addDebit(acc.id!, acc.name!, cgstAmount, accountCode: acc.code);
      }
    }

    if (sgstAmount > 0) {
      final sgstAccounts = await _accountsRef
          .where('userId', isEqualTo: _userId)
          .where('subType', isEqualTo: AccountSubType.gstInput)
          .where('name', isEqualTo: 'GST Input (SGST)')
          .limit(1)
          .get();
      if (sgstAccounts.docs.isNotEmpty) {
        final acc = Account.fromFirestore(sgstAccounts.docs.first);
        entry.addDebit(acc.id!, acc.name!, sgstAmount, accountCode: acc.code);
      }
    }

    if (igstAmount > 0) {
      final igstAccounts = await _accountsRef
          .where('userId', isEqualTo: _userId)
          .where('subType', isEqualTo: AccountSubType.gstInput)
          .where('name', isEqualTo: 'GST Input (IGST)')
          .limit(1)
          .get();
      if (igstAccounts.docs.isNotEmpty) {
        final acc = Account.fromFirestore(igstAccounts.docs.first);
        entry.addDebit(acc.id!, acc.name!, igstAmount, accountCode: acc.code);
      }
    }

    // CR: Accounts Payable
    entry.addCredit(
      payableAccount.id!,
      payableAccount.name!,
      grandTotal,
      accountCode: payableAccount.code,
    );

    return createJournalEntry(entry);
  }

  /// Record a payment made to vendor
  /// DR: Accounts Payable (amount)
  /// CR: Cash/Bank (amount per mode)
  Future<String?> recordPaymentMade({
    required String paymentId,
    required String paymentNumber,
    required String vendorName,
    required String billNumber,
    required DateTime paymentDate,
    required double totalAmount,
    required Map<String, double> paymentModes, // accountId -> amount
  }) async {
    final payableAccount = await getAccountBySubType(AccountSubType.payable);
    if (payableAccount == null) {
      throw Exception('Accounts Payable not found');
    }

    final entry = JournalEntry(
      date: paymentDate,
      narration: 'Payment to $vendorName for $billNumber',
      referenceType: TransactionType.paymentMade,
      referenceId: paymentId,
      referenceNumber: paymentNumber,
    );

    // DR: Accounts Payable
    entry.addDebit(
      payableAccount.id!,
      payableAccount.name!,
      totalAmount,
      accountCode: payableAccount.code,
    );

    // CR: Each payment mode (Cash/Bank accounts)
    for (final mode in paymentModes.entries) {
      if (mode.value > 0) {
        final account = await getAccountById(mode.key);
        if (account != null) {
          entry.addCredit(account.id!, account.name!, mode.value, accountCode: account.code);
        }
      }
    }

    return createJournalEntry(entry);
  }

  /// Record a credit note (issued to customer)
  /// DR: Sales Return (subtotal)
  /// DR: GST Output (tax amounts)
  /// CR: Accounts Receivable (grandTotal)
  Future<String?> recordCreditNote({
    required String creditNoteId,
    required String creditNoteNumber,
    required String customerName,
    required String invoiceNumber,
    required DateTime date,
    required double subtotal,
    required double grandTotal,
    required double cgstAmount,
    required double sgstAmount,
    required double igstAmount,
  }) async {
    final salesReturnAccount = await getAccountBySubType(AccountSubType.salesReturn);
    final receivableAccount = await getAccountBySubType(AccountSubType.receivable);

    if (salesReturnAccount == null || receivableAccount == null) {
      throw Exception('Required accounts not found');
    }

    final entry = JournalEntry(
      date: date,
      narration: 'Credit Note to $customerName for $invoiceNumber',
      referenceType: TransactionType.creditNote,
      referenceId: creditNoteId,
      referenceNumber: creditNoteNumber,
    );

    // DR: Sales Return
    entry.addDebit(
      salesReturnAccount.id!,
      salesReturnAccount.name!,
      subtotal,
      accountCode: salesReturnAccount.code,
    );

    // DR: GST Output accounts (reducing liability)
    if (cgstAmount > 0) {
      final cgstAccounts = await _accountsRef
          .where('userId', isEqualTo: _userId)
          .where('subType', isEqualTo: AccountSubType.gstOutput)
          .where('name', isEqualTo: 'GST Output (CGST)')
          .limit(1)
          .get();
      if (cgstAccounts.docs.isNotEmpty) {
        final acc = Account.fromFirestore(cgstAccounts.docs.first);
        entry.addDebit(acc.id!, acc.name!, cgstAmount, accountCode: acc.code);
      }
    }

    if (sgstAmount > 0) {
      final sgstAccounts = await _accountsRef
          .where('userId', isEqualTo: _userId)
          .where('subType', isEqualTo: AccountSubType.gstOutput)
          .where('name', isEqualTo: 'GST Output (SGST)')
          .limit(1)
          .get();
      if (sgstAccounts.docs.isNotEmpty) {
        final acc = Account.fromFirestore(sgstAccounts.docs.first);
        entry.addDebit(acc.id!, acc.name!, sgstAmount, accountCode: acc.code);
      }
    }

    if (igstAmount > 0) {
      final igstAccounts = await _accountsRef
          .where('userId', isEqualTo: _userId)
          .where('subType', isEqualTo: AccountSubType.gstOutput)
          .where('name', isEqualTo: 'GST Output (IGST)')
          .limit(1)
          .get();
      if (igstAccounts.docs.isNotEmpty) {
        final acc = Account.fromFirestore(igstAccounts.docs.first);
        entry.addDebit(acc.id!, acc.name!, igstAmount, accountCode: acc.code);
      }
    }

    // CR: Accounts Receivable
    entry.addCredit(
      receivableAccount.id!,
      receivableAccount.name!,
      grandTotal,
      accountCode: receivableAccount.code,
    );

    return createJournalEntry(entry);
  }

  /// Record a debit note (issued to vendor)
  /// DR: Accounts Payable (grandTotal)
  /// CR: Purchase Return (subtotal)
  /// CR: GST Input (tax amounts)
  Future<String?> recordDebitNote({
    required String debitNoteId,
    required String debitNoteNumber,
    required String vendorName,
    required String billNumber,
    required DateTime date,
    required double subtotal,
    required double grandTotal,
    required double cgstAmount,
    required double sgstAmount,
    required double igstAmount,
  }) async {
    final purchaseReturnAccount = await getAccountBySubType(AccountSubType.purchaseReturn);
    final payableAccount = await getAccountBySubType(AccountSubType.payable);

    if (purchaseReturnAccount == null || payableAccount == null) {
      throw Exception('Required accounts not found');
    }

    final entry = JournalEntry(
      date: date,
      narration: 'Debit Note to $vendorName for $billNumber',
      referenceType: TransactionType.debitNote,
      referenceId: debitNoteId,
      referenceNumber: debitNoteNumber,
    );

    // DR: Accounts Payable
    entry.addDebit(
      payableAccount.id!,
      payableAccount.name!,
      grandTotal,
      accountCode: payableAccount.code,
    );

    // CR: Purchase Return
    entry.addCredit(
      purchaseReturnAccount.id!,
      purchaseReturnAccount.name!,
      subtotal,
      accountCode: purchaseReturnAccount.code,
    );

    // CR: GST Input accounts (reducing credit)
    if (cgstAmount > 0) {
      final cgstAccounts = await _accountsRef
          .where('userId', isEqualTo: _userId)
          .where('subType', isEqualTo: AccountSubType.gstInput)
          .where('name', isEqualTo: 'GST Input (CGST)')
          .limit(1)
          .get();
      if (cgstAccounts.docs.isNotEmpty) {
        final acc = Account.fromFirestore(cgstAccounts.docs.first);
        entry.addCredit(acc.id!, acc.name!, cgstAmount, accountCode: acc.code);
      }
    }

    if (sgstAmount > 0) {
      final sgstAccounts = await _accountsRef
          .where('userId', isEqualTo: _userId)
          .where('subType', isEqualTo: AccountSubType.gstInput)
          .where('name', isEqualTo: 'GST Input (SGST)')
          .limit(1)
          .get();
      if (sgstAccounts.docs.isNotEmpty) {
        final acc = Account.fromFirestore(sgstAccounts.docs.first);
        entry.addCredit(acc.id!, acc.name!, sgstAmount, accountCode: acc.code);
      }
    }

    if (igstAmount > 0) {
      final igstAccounts = await _accountsRef
          .where('userId', isEqualTo: _userId)
          .where('subType', isEqualTo: AccountSubType.gstInput)
          .where('name', isEqualTo: 'GST Input (IGST)')
          .limit(1)
          .get();
      if (igstAccounts.docs.isNotEmpty) {
        final acc = Account.fromFirestore(igstAccounts.docs.first);
        entry.addCredit(acc.id!, acc.name!, igstAmount, accountCode: acc.code);
      }
    }

    return createJournalEntry(entry);
  }

  // ==================== REPORT HELPERS ====================

  /// Get total balance for an account type
  Future<double> getTotalBalanceByType(String accountType) async {
    if (_userId == null) return 0;

    final query = await _accountsRef
        .where('userId', isEqualTo: _userId)
        .where('type', isEqualTo: accountType)
        .where('isActive', isEqualTo: true)
        .get();

    double total = 0.0;
    for (final doc in query.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['balance'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  /// Get accounts receivable total
  Future<double> getTotalReceivables() async {
    final account = await getAccountBySubType(AccountSubType.receivable);
    return account?.balance ?? 0.0;
  }

  /// Get accounts payable total
  Future<double> getTotalPayables() async {
    final account = await getAccountBySubType(AccountSubType.payable);
    return account?.balance ?? 0.0;
  }

  /// Get GST liability (Output - Input)
  Future<Map<String, double>> getGSTSummary() async {
    if (_userId == null) return {'output': 0, 'input': 0, 'net': 0};

    // Get GST Output totals
    final outputQuery = await _accountsRef
        .where('userId', isEqualTo: _userId)
        .where('subType', isEqualTo: AccountSubType.gstOutput)
        .where('isActive', isEqualTo: true)
        .get();

    double outputTotal = 0.0;
    for (final doc in outputQuery.docs) {
      final data = doc.data() as Map<String, dynamic>;
      outputTotal += (data['balance'] as num?)?.toDouble() ?? 0.0;
    }

    // Get GST Input totals
    final inputQuery = await _accountsRef
        .where('userId', isEqualTo: _userId)
        .where('subType', isEqualTo: AccountSubType.gstInput)
        .where('isActive', isEqualTo: true)
        .get();

    double inputTotal = 0.0;
    for (final doc in inputQuery.docs) {
      final data = doc.data() as Map<String, dynamic>;
      inputTotal += (data['balance'] as num?)?.toDouble() ?? 0.0;
    }

    return {
      'output': outputTotal,
      'input': inputTotal,
      'net': outputTotal - inputTotal, // Positive = payable to govt
    };
  }

  // ==================== MIGRATION ====================

  /// Migrate existing invoices to accounting system
  /// Creates journal entries for invoices that don't have them
  /// Also updates invoice payment tracking fields if missing
  Future<void> migrateExistingInvoices() async {
    if (_userId == null) return;

    try {
      // Get all invoices for this user
      final invoicesSnapshot = await _firestore
          .collection('invoices')
          .where('userId', isEqualTo: _userId)
          .get();

      if (invoicesSnapshot.docs.isEmpty) {
        debugPrint('No invoices to migrate');
        return;
      }

      // Get all existing journal entries for sales invoices
      final entriesSnapshot = await _journalEntriesRef
          .where('userId', isEqualTo: _userId)
          .where('referenceType', isEqualTo: TransactionType.salesInvoice)
          .get();

      // Create a set of invoice IDs that already have journal entries
      final invoicesWithEntries = <String>{};
      for (final doc in entriesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final refId = data['referenceId'] as String?;
        if (refId != null) {
          invoicesWithEntries.add(refId);
        }
      }

      int migratedCount = 0;
      int updatedFieldsCount = 0;

      for (final doc in invoicesSnapshot.docs) {
        final invoiceId = doc.id;
        final data = doc.data();

        // Check if invoice needs payment field updates
        bool needsFieldUpdate = false;
        final Map<String, dynamic> updates = {};

        if (data['paymentStatus'] == null) {
          updates['paymentStatus'] = PaymentStatus.unpaid;
          needsFieldUpdate = true;
        }
        if (data['amountPaid'] == null) {
          updates['amountPaid'] = 0.0;
          needsFieldUpdate = true;
        }
        if (data['amountDue'] == null) {
          final grandTotal = (data['grandTotal'] ?? 0).toDouble();
          final amountPaid = (data['amountPaid'] ?? 0).toDouble();
          updates['amountDue'] = grandTotal - amountPaid;
          needsFieldUpdate = true;
        }
        if (data['creditPeriodDays'] == null) {
          updates['creditPeriodDays'] = 30; // Default credit period
          needsFieldUpdate = true;
        }

        // Update invoice fields if needed
        if (needsFieldUpdate) {
          updates['updatedAt'] = FieldValue.serverTimestamp();
          await _firestore.collection('invoices').doc(invoiceId).update(updates);
          updatedFieldsCount++;
        }

        // Check if invoice already has a journal entry
        if (invoicesWithEntries.contains(invoiceId)) {
          continue; // Skip - already has entry
        }

        // Create journal entry for this invoice
        try {
          final invoiceNumber = data['invoiceNumber'] as String? ?? '';
          final customerName = data['customerName'] as String? ?? '';
          final invoiceDate = (data['invoiceDate'] as Timestamp?)?.toDate() ?? DateTime.now();
          final subtotal = (data['subtotal'] ?? 0).toDouble();
          final grandTotal = (data['grandTotal'] ?? 0).toDouble();
          final cgstTotal = (data['cgstTotal'] ?? 0).toDouble();
          final sgstTotal = (data['sgstTotal'] ?? 0).toDouble();
          final igstTotal = (data['igstTotal'] ?? 0).toDouble();
          final discountAmount = (data['discountAmount'] ?? 0).toDouble();

          await recordSalesInvoice(
            invoiceId: invoiceId,
            invoiceNumber: invoiceNumber,
            customerName: customerName,
            invoiceDate: invoiceDate,
            subtotal: subtotal,
            grandTotal: grandTotal,
            cgstAmount: cgstTotal,
            sgstAmount: sgstTotal,
            igstAmount: igstTotal,
            discountAmount: discountAmount,
          );

          migratedCount++;
          debugPrint('Migrated invoice to books: $invoiceNumber');
        } catch (e) {
          debugPrint('Error migrating invoice $invoiceId: $e');
          // Continue with other invoices even if one fails
        }
      }

      debugPrint('Invoice migration complete: $migratedCount entries created, $updatedFieldsCount invoices updated');
    } catch (e) {
      debugPrint('Error during invoice migration: $e');
    }
  }
}
