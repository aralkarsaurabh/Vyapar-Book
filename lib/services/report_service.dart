import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Data class for Sales Register report items
class SalesRegisterItem {
  final String invoiceNumber;
  final String customerName;
  final DateTime invoiceDate;
  final double taxableAmount;
  final double cgst;
  final double sgst;
  final double igst;
  final double total;

  SalesRegisterItem({
    required this.invoiceNumber,
    required this.customerName,
    required this.invoiceDate,
    required this.taxableAmount,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.total,
  });
}

/// Data class for Purchase Register report items
class PurchaseRegisterItem {
  final String billNumber;
  final String vendorName;
  final DateTime billDate;
  final double taxableAmount;
  final double cgst;
  final double sgst;
  final double igst;
  final double total;

  PurchaseRegisterItem({
    required this.billNumber,
    required this.vendorName,
    required this.billDate,
    required this.taxableAmount,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.total,
  });
}

/// Data class for Outstanding Receivables report items (grouped by customer)
class OutstandingReceivableItem {
  final String customerId;
  final String customerName;
  final double totalInvoiced;
  final double amountReceived;
  final double outstanding;
  final int invoiceCount;

  OutstandingReceivableItem({
    required this.customerId,
    required this.customerName,
    required this.totalInvoiced,
    required this.amountReceived,
    required this.outstanding,
    required this.invoiceCount,
  });
}

/// Data class for Outstanding Payables report items (grouped by vendor)
class OutstandingPayableItem {
  final String vendorName;
  final String vendorVyaparId;
  final double totalBilled;
  final double amountPaid;
  final double outstanding;
  final int billCount;

  OutstandingPayableItem({
    required this.vendorName,
    required this.vendorVyaparId,
    required this.totalBilled,
    required this.amountPaid,
    required this.outstanding,
    required this.billCount,
  });
}

/// Data class for Customer-wise Sales report items
class CustomerWiseSalesItem {
  final String customerId;
  final String customerName;
  final int invoiceCount;
  final double salesAmount;
  final double gstAmount;
  final double totalAmount;

  CustomerWiseSalesItem({
    required this.customerId,
    required this.customerName,
    required this.invoiceCount,
    required this.salesAmount,
    required this.gstAmount,
    required this.totalAmount,
  });
}

/// Data class for Vendor-wise Purchases report items
class VendorWisePurchaseItem {
  final String vendorName;
  final String vendorVyaparId;
  final int billCount;
  final double purchaseAmount;
  final double gstAmount;
  final double totalAmount;

  VendorWisePurchaseItem({
    required this.vendorName,
    required this.vendorVyaparId,
    required this.billCount,
    required this.purchaseAmount,
    required this.gstAmount,
    required this.totalAmount,
  });
}

/// Data class for Receivables Aging report items (grouped by customer)
class ReceivablesAgingItem {
  final String customerName;
  final double totalOutstanding;
  final double current;      // Not yet due
  final double overdue1to30; // 1-30 days overdue
  final double overdue31to60; // 31-60 days overdue
  final double overdue60plus; // 60+ days overdue
  final int invoiceCount;

  ReceivablesAgingItem({
    required this.customerName,
    required this.totalOutstanding,
    required this.current,
    required this.overdue1to30,
    required this.overdue31to60,
    required this.overdue60plus,
    required this.invoiceCount,
  });
}

/// Data class for Payables Aging report items (grouped by vendor)
class PayablesAgingItem {
  final String vendorName;
  final double totalOutstanding;
  final double current;
  final double overdue1to30;
  final double overdue31to60;
  final double overdue60plus;
  final int billCount;

  PayablesAgingItem({
    required this.vendorName,
    required this.totalOutstanding,
    required this.current,
    required this.overdue1to30,
    required this.overdue31to60,
    required this.overdue60plus,
    required this.billCount,
  });
}

/// Data class for GST Summary report
class GstSummaryData {
  final double outputCgst;
  final double outputSgst;
  final double outputIgst;
  final double inputCgst;
  final double inputSgst;
  final double inputIgst;
  final double totalOutput;
  final double totalInput;
  final double netPayable;
  final int salesInvoiceCount;
  final int purchaseBillCount;

  GstSummaryData({
    required this.outputCgst,
    required this.outputSgst,
    required this.outputIgst,
    required this.inputCgst,
    required this.inputSgst,
    required this.inputIgst,
    required this.totalOutput,
    required this.totalInput,
    required this.netPayable,
    required this.salesInvoiceCount,
    required this.purchaseBillCount,
  });
}

/// Data class for GSTR-1 invoice items
class Gstr1InvoiceItem {
  final String customerGstin;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final String customerName;
  final double taxableAmount;
  final double cgst;
  final double sgst;
  final double igst;
  final double total;

  Gstr1InvoiceItem({
    required this.customerGstin,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.customerName,
    required this.taxableAmount,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.total,
  });
}

/// Data class for GSTR-1 report
class Gstr1Data {
  final List<Gstr1InvoiceItem> b2bInvoices;
  final List<Gstr1InvoiceItem> b2cInvoices;
  final double b2bTotalAmount;
  final double b2cTotalAmount;

  Gstr1Data({
    required this.b2bInvoices,
    required this.b2cInvoices,
    required this.b2bTotalAmount,
    required this.b2cTotalAmount,
  });
}

/// Data class for GSTR-3B report
class Gstr3bData {
  final double outwardTaxable;
  final double outwardIgst;
  final double outwardCgst;
  final double outwardSgst;
  final double inputTaxable;
  final double inputIgst;
  final double inputCgst;
  final double inputSgst;

  Gstr3bData({
    required this.outwardTaxable,
    required this.outwardIgst,
    required this.outwardCgst,
    required this.outwardSgst,
    required this.inputTaxable,
    required this.inputIgst,
    required this.inputCgst,
    required this.inputSgst,
  });
}

/// Data class for Ledger report items
class LedgerItem {
  final DateTime date;
  final String particular;
  final String reference;
  final double debit;
  final double credit;
  final double balance;

  LedgerItem({
    required this.date,
    required this.particular,
    required this.reference,
    required this.debit,
    required this.credit,
    required this.balance,
  });
}

/// Data class for Ledger report result
class LedgerData {
  final String accountName;
  final String accountType;
  final double openingBalance;
  final double closingBalance;
  final List<LedgerItem> items;

  LedgerData({
    required this.accountName,
    required this.accountType,
    required this.openingBalance,
    required this.closingBalance,
    required this.items,
  });
}

/// Data class for Day Book entries
class DayBookEntry {
  final String entryNumber;
  final String narration;
  final String referenceNumber;
  final String referenceType;
  final DateTime date;
  final List<DayBookLine> lines;
  final double totalDebit;
  final double totalCredit;

  DayBookEntry({
    required this.entryNumber,
    required this.narration,
    required this.referenceNumber,
    required this.referenceType,
    required this.date,
    required this.lines,
    required this.totalDebit,
    required this.totalCredit,
  });
}

class DayBookLine {
  final String accountName;
  final double debit;
  final double credit;

  DayBookLine({
    required this.accountName,
    required this.debit,
    required this.credit,
  });
}

/// Data class for Trial Balance items
class TrialBalanceItem {
  final String accountCode;
  final String accountName;
  final String accountType;
  final double debitBalance;
  final double creditBalance;

  TrialBalanceItem({
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    required this.debitBalance,
    required this.creditBalance,
  });
}

/// Data class for P&L line items
class ProfitLossLineItem {
  final String accountName;
  final String subType;
  final double amount;

  ProfitLossLineItem({
    required this.accountName,
    required this.subType,
    required this.amount,
  });
}

/// Data class for Profit & Loss report
class ProfitLossData {
  final List<ProfitLossLineItem> incomeItems;
  final List<ProfitLossLineItem> expenseItems;
  final double totalIncome;
  final double totalExpenses;
  final double netProfit;

  ProfitLossData({
    required this.incomeItems,
    required this.expenseItems,
    required this.totalIncome,
    required this.totalExpenses,
    required this.netProfit,
  });
}

/// Data class for Balance Sheet line items
class BalanceSheetLineItem {
  final String accountName;
  final String subType;
  final double amount;

  BalanceSheetLineItem({
    required this.accountName,
    required this.subType,
    required this.amount,
  });
}

/// Data class for Balance Sheet report
class BalanceSheetData {
  final List<BalanceSheetLineItem> assetItems;
  final List<BalanceSheetLineItem> liabilityItems;
  final List<BalanceSheetLineItem> equityItems;
  final double totalAssets;
  final double totalLiabilities;
  final double totalEquity;
  final double retainedEarnings;

  BalanceSheetData({
    required this.assetItems,
    required this.liabilityItems,
    required this.equityItems,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.totalEquity,
    required this.retainedEarnings,
  });
}

/// Data class for Party (Customer/Vendor) Ledger items
class PartyLedgerItem {
  final DateTime date;
  final String particular;
  final String reference;
  final double debit;
  final double credit;
  final String type;
  final double balance;

  PartyLedgerItem({
    required this.date,
    required this.particular,
    required this.reference,
    required this.debit,
    required this.credit,
    required this.type,
    this.balance = 0,
  });
}

/// Data class for Party Ledger report
class PartyLedgerData {
  final String partyName;
  final String partyType;
  final double openingBalance;
  final double closingBalance;
  final double totalDebit;
  final double totalCredit;
  final List<PartyLedgerItem> items;

  PartyLedgerData({
    required this.partyName,
    required this.partyType,
    required this.openingBalance,
    required this.closingBalance,
    required this.totalDebit,
    required this.totalCredit,
    required this.items,
  });
}

/// Service for generating business reports
class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // ==================== SALES REGISTER ====================

  /// Get sales register data filtered by date range
  Future<List<SalesRegisterItem>> getSalesRegister({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('invoices')
          .where('userId', isEqualTo: _userId)
          .orderBy('invoiceDate', descending: true)
          .get();

      final items = <SalesRegisterItem>[];
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final invoiceDate = (data['invoiceDate'] as Timestamp?)?.toDate();
        if (invoiceDate == null) continue;

        // Filter by date range client-side
        if (invoiceDate.isBefore(startDate) || invoiceDate.isAfter(endOfDay)) continue;

        items.add(SalesRegisterItem(
          invoiceNumber: data['invoiceNumber'] ?? '-',
          customerName: data['customerName'] ?? '-',
          invoiceDate: invoiceDate,
          taxableAmount: (data['subtotal'] ?? 0).toDouble() - (data['discountAmount'] ?? 0).toDouble(),
          cgst: (data['cgstTotal'] ?? 0).toDouble(),
          sgst: (data['sgstTotal'] ?? 0).toDouble(),
          igst: (data['igstTotal'] ?? 0).toDouble(),
          total: (data['grandTotal'] ?? 0).toDouble(),
        ));
      }

      // Sort by date ascending for register display
      items.sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));
      return items;
    } catch (e) {
      debugPrint('Error getting sales register: $e');
      return [];
    }
  }

  // ==================== PURCHASE REGISTER ====================

  /// Get purchase register data (recorded received invoices) filtered by date range
  Future<List<PurchaseRegisterItem>> getPurchaseRegister({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('sharedDocuments')
          .where('receiverUserId', isEqualTo: _userId)
          .where('documentType', isEqualTo: 'invoice')
          .orderBy('documentDate', descending: true)
          .get();

      final items = <PurchaseRegisterItem>[];
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Only include recorded bills
        if (data['recordingStatus'] != 'recorded') continue;

        final docDate = (data['documentDate'] as Timestamp?)?.toDate();
        if (docDate == null) continue;

        // Filter by date range
        if (docDate.isBefore(startDate) || docDate.isAfter(endOfDay)) continue;

        // Extract tax details from document snapshot
        final docSnapshot = data['documentSnapshot'] as Map<String, dynamic>? ?? {};
        final subtotal = (docSnapshot['subtotal'] ?? 0).toDouble();
        final discountAmount = (docSnapshot['discountAmount'] ?? 0).toDouble();

        items.add(PurchaseRegisterItem(
          billNumber: data['documentNumber'] ?? '-',
          vendorName: data['senderCompanyName'] ?? '-',
          billDate: docDate,
          taxableAmount: subtotal - discountAmount,
          cgst: (docSnapshot['cgstTotal'] ?? 0).toDouble(),
          sgst: (docSnapshot['sgstTotal'] ?? 0).toDouble(),
          igst: (docSnapshot['igstTotal'] ?? 0).toDouble(),
          total: (data['grandTotal'] ?? 0).toDouble(),
        ));
      }

      items.sort((a, b) => a.billDate.compareTo(b.billDate));
      return items;
    } catch (e) {
      debugPrint('Error getting purchase register: $e');
      return [];
    }
  }

  // ==================== OUTSTANDING RECEIVABLES ====================

  /// Get outstanding receivables grouped by customer
  Future<List<OutstandingReceivableItem>> getOutstandingReceivables() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('invoices')
          .where('userId', isEqualTo: _userId)
          .get();

      // Group by customer
      final customerMap = <String, Map<String, dynamic>>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final paymentStatus = data['paymentStatus'] ?? 'unpaid';

        // Only include unpaid/partial
        if (paymentStatus == 'paid') continue;

        final customerId = data['customerId'] ?? 'unknown';
        final customerName = data['customerName'] ?? '-';
        final grandTotal = (data['grandTotal'] ?? 0).toDouble();
        final amountPaid = (data['amountPaid'] ?? 0).toDouble();

        if (!customerMap.containsKey(customerId)) {
          customerMap[customerId] = {
            'customerName': customerName,
            'totalInvoiced': 0.0,
            'amountReceived': 0.0,
            'outstanding': 0.0,
            'invoiceCount': 0,
          };
        }

        customerMap[customerId]!['totalInvoiced'] += grandTotal;
        customerMap[customerId]!['amountReceived'] += amountPaid;
        customerMap[customerId]!['outstanding'] += (grandTotal - amountPaid);
        customerMap[customerId]!['invoiceCount'] += 1;
      }

      final items = customerMap.entries.map((entry) {
        return OutstandingReceivableItem(
          customerId: entry.key,
          customerName: entry.value['customerName'],
          totalInvoiced: entry.value['totalInvoiced'],
          amountReceived: entry.value['amountReceived'],
          outstanding: entry.value['outstanding'],
          invoiceCount: entry.value['invoiceCount'],
        );
      }).toList();

      // Sort by outstanding descending
      items.sort((a, b) => b.outstanding.compareTo(a.outstanding));
      return items;
    } catch (e) {
      debugPrint('Error getting outstanding receivables: $e');
      return [];
    }
  }

  // ==================== OUTSTANDING PAYABLES ====================

  /// Get outstanding payables grouped by vendor
  Future<List<OutstandingPayableItem>> getOutstandingPayables() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('sharedDocuments')
          .where('receiverUserId', isEqualTo: _userId)
          .where('documentType', isEqualTo: 'invoice')
          .get();

      // Group by vendor
      final vendorMap = <String, Map<String, dynamic>>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Only include recorded bills that are not fully paid
        if (data['recordingStatus'] != 'recorded') continue;
        if (data['paymentStatus'] == 'paid') continue;

        final vendorName = data['senderCompanyName'] ?? '-';
        final vendorVyaparId = data['senderVyaparId'] ?? '';
        final key = vendorVyaparId.isNotEmpty ? vendorVyaparId : vendorName;
        final grandTotal = (data['grandTotal'] ?? 0).toDouble();
        final amountPaid = (data['amountPaid'] ?? 0).toDouble();

        if (!vendorMap.containsKey(key)) {
          vendorMap[key] = {
            'vendorName': vendorName,
            'vendorVyaparId': vendorVyaparId,
            'totalBilled': 0.0,
            'amountPaid': 0.0,
            'outstanding': 0.0,
            'billCount': 0,
          };
        }

        vendorMap[key]!['totalBilled'] += grandTotal;
        vendorMap[key]!['amountPaid'] += amountPaid;
        vendorMap[key]!['outstanding'] += (grandTotal - amountPaid);
        vendorMap[key]!['billCount'] += 1;
      }

      final items = vendorMap.entries.map((entry) {
        return OutstandingPayableItem(
          vendorName: entry.value['vendorName'],
          vendorVyaparId: entry.value['vendorVyaparId'],
          totalBilled: entry.value['totalBilled'],
          amountPaid: entry.value['amountPaid'],
          outstanding: entry.value['outstanding'],
          billCount: entry.value['billCount'],
        );
      }).toList();

      items.sort((a, b) => b.outstanding.compareTo(a.outstanding));
      return items;
    } catch (e) {
      debugPrint('Error getting outstanding payables: $e');
      return [];
    }
  }

  // ==================== CUSTOMER-WISE SALES ====================

  /// Get customer-wise sales summary filtered by date range
  Future<List<CustomerWiseSalesItem>> getCustomerWiseSales({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('invoices')
          .where('userId', isEqualTo: _userId)
          .orderBy('invoiceDate', descending: true)
          .get();

      final customerMap = <String, Map<String, dynamic>>{};
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final invoiceDate = (data['invoiceDate'] as Timestamp?)?.toDate();
        if (invoiceDate == null) continue;

        if (invoiceDate.isBefore(startDate) || invoiceDate.isAfter(endOfDay)) continue;

        final customerId = data['customerId'] ?? 'unknown';
        final customerName = data['customerName'] ?? '-';
        final subtotal = (data['subtotal'] ?? 0).toDouble();
        final discountAmount = (data['discountAmount'] ?? 0).toDouble();
        final taxTotal = (data['taxTotal'] ?? 0).toDouble();
        final grandTotal = (data['grandTotal'] ?? 0).toDouble();

        if (!customerMap.containsKey(customerId)) {
          customerMap[customerId] = {
            'customerName': customerName,
            'invoiceCount': 0,
            'salesAmount': 0.0,
            'gstAmount': 0.0,
            'totalAmount': 0.0,
          };
        }

        customerMap[customerId]!['invoiceCount'] += 1;
        customerMap[customerId]!['salesAmount'] += (subtotal - discountAmount);
        customerMap[customerId]!['gstAmount'] += taxTotal;
        customerMap[customerId]!['totalAmount'] += grandTotal;
      }

      final items = customerMap.entries.map((entry) {
        return CustomerWiseSalesItem(
          customerId: entry.key,
          customerName: entry.value['customerName'],
          invoiceCount: entry.value['invoiceCount'],
          salesAmount: entry.value['salesAmount'],
          gstAmount: entry.value['gstAmount'],
          totalAmount: entry.value['totalAmount'],
        );
      }).toList();

      // Sort by total amount descending
      items.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
      return items;
    } catch (e) {
      debugPrint('Error getting customer-wise sales: $e');
      return [];
    }
  }

  // ==================== VENDOR-WISE PURCHASES ====================

  /// Get vendor-wise purchases summary filtered by date range
  Future<List<VendorWisePurchaseItem>> getVendorWisePurchases({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('sharedDocuments')
          .where('receiverUserId', isEqualTo: _userId)
          .where('documentType', isEqualTo: 'invoice')
          .orderBy('documentDate', descending: true)
          .get();

      final vendorMap = <String, Map<String, dynamic>>{};
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Only include recorded bills
        if (data['recordingStatus'] != 'recorded') continue;

        final docDate = (data['documentDate'] as Timestamp?)?.toDate();
        if (docDate == null) continue;

        if (docDate.isBefore(startDate) || docDate.isAfter(endOfDay)) continue;

        final vendorName = data['senderCompanyName'] ?? '-';
        final vendorVyaparId = data['senderVyaparId'] ?? '';
        final key = vendorVyaparId.isNotEmpty ? vendorVyaparId : vendorName;
        final docSnapshot = data['documentSnapshot'] as Map<String, dynamic>? ?? {};
        final subtotal = (docSnapshot['subtotal'] ?? 0).toDouble();
        final discountAmount = (docSnapshot['discountAmount'] ?? 0).toDouble();
        final taxTotal = (docSnapshot['taxTotal'] ?? 0).toDouble();
        final grandTotal = (data['grandTotal'] ?? 0).toDouble();

        if (!vendorMap.containsKey(key)) {
          vendorMap[key] = {
            'vendorName': vendorName,
            'vendorVyaparId': vendorVyaparId,
            'billCount': 0,
            'purchaseAmount': 0.0,
            'gstAmount': 0.0,
            'totalAmount': 0.0,
          };
        }

        vendorMap[key]!['billCount'] += 1;
        vendorMap[key]!['purchaseAmount'] += (subtotal - discountAmount);
        vendorMap[key]!['gstAmount'] += taxTotal;
        vendorMap[key]!['totalAmount'] += grandTotal;
      }

      final items = vendorMap.entries.map((entry) {
        return VendorWisePurchaseItem(
          vendorName: entry.value['vendorName'],
          vendorVyaparId: entry.value['vendorVyaparId'],
          billCount: entry.value['billCount'],
          purchaseAmount: entry.value['purchaseAmount'],
          gstAmount: entry.value['gstAmount'],
          totalAmount: entry.value['totalAmount'],
        );
      }).toList();

      items.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
      return items;
    } catch (e) {
      debugPrint('Error getting vendor-wise purchases: $e');
      return [];
    }
  }

  // ==================== RECEIVABLES AGING ====================

  /// Get receivables aging grouped by customer with aging buckets
  Future<List<ReceivablesAgingItem>> getReceivablesAging() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('invoices')
          .where('userId', isEqualTo: _userId)
          .get();

      final customerMap = <String, Map<String, dynamic>>{};
      final now = DateTime.now();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final paymentStatus = data['paymentStatus'] ?? 'unpaid';

        // Only include unpaid/partial
        if (paymentStatus == 'paid') continue;

        final customerName = data['customerName'] ?? '-';
        final customerId = data['customerId'] ?? 'unknown';
        final grandTotal = (data['grandTotal'] ?? 0).toDouble();
        final amountPaid = (data['amountPaid'] ?? 0).toDouble();
        final outstanding = grandTotal - amountPaid;

        if (outstanding <= 0) continue;

        // Calculate due date
        final invoiceDate = (data['invoiceDate'] as Timestamp?)?.toDate();
        if (invoiceDate == null) continue;

        DateTime dueDate;
        if (data['dueDate'] != null) {
          dueDate = (data['dueDate'] as Timestamp).toDate();
        } else {
          final creditDays = (data['creditPeriodDays'] ?? 0) as int;
          dueDate = invoiceDate.add(Duration(days: creditDays));
        }

        final daysOverdue = now.difference(dueDate).inDays;

        if (!customerMap.containsKey(customerId)) {
          customerMap[customerId] = {
            'customerName': customerName,
            'totalOutstanding': 0.0,
            'current': 0.0,
            'overdue1to30': 0.0,
            'overdue31to60': 0.0,
            'overdue60plus': 0.0,
            'invoiceCount': 0,
          };
        }

        customerMap[customerId]!['totalOutstanding'] += outstanding;
        customerMap[customerId]!['invoiceCount'] += 1;

        if (daysOverdue <= 0) {
          customerMap[customerId]!['current'] += outstanding;
        } else if (daysOverdue <= 30) {
          customerMap[customerId]!['overdue1to30'] += outstanding;
        } else if (daysOverdue <= 60) {
          customerMap[customerId]!['overdue31to60'] += outstanding;
        } else {
          customerMap[customerId]!['overdue60plus'] += outstanding;
        }
      }

      final items = customerMap.entries.map((entry) {
        return ReceivablesAgingItem(
          customerName: entry.value['customerName'],
          totalOutstanding: entry.value['totalOutstanding'],
          current: entry.value['current'],
          overdue1to30: entry.value['overdue1to30'],
          overdue31to60: entry.value['overdue31to60'],
          overdue60plus: entry.value['overdue60plus'],
          invoiceCount: entry.value['invoiceCount'],
        );
      }).toList();

      // Sort by total outstanding descending
      items.sort((a, b) => b.totalOutstanding.compareTo(a.totalOutstanding));
      return items;
    } catch (e) {
      debugPrint('Error getting receivables aging: $e');
      return [];
    }
  }

  // ==================== PAYABLES AGING ====================

  /// Get payables aging grouped by vendor with aging buckets
  Future<List<PayablesAgingItem>> getPayablesAging() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('sharedDocuments')
          .where('receiverUserId', isEqualTo: _userId)
          .where('documentType', isEqualTo: 'invoice')
          .get();

      final vendorMap = <String, Map<String, dynamic>>{};
      final now = DateTime.now();

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Only include recorded bills that are not fully paid
        if (data['recordingStatus'] != 'recorded') continue;
        if (data['paymentStatus'] == 'paid') continue;

        final vendorName = data['senderCompanyName'] ?? '-';
        final vendorVyaparId = data['senderVyaparId'] ?? '';
        final key = vendorVyaparId.isNotEmpty ? vendorVyaparId : vendorName;
        final grandTotal = (data['grandTotal'] ?? 0).toDouble();
        final amountPaid = (data['amountPaid'] ?? 0).toDouble();
        final outstanding = grandTotal - amountPaid;

        if (outstanding <= 0) continue;

        // Calculate due date
        final docDate = (data['documentDate'] as Timestamp?)?.toDate();
        if (docDate == null) continue;

        DateTime dueDate;
        if (data['dueDate'] != null) {
          dueDate = (data['dueDate'] as Timestamp).toDate();
        } else {
          final docSnapshot = data['documentSnapshot'] as Map<String, dynamic>? ?? {};
          final creditDays = (docSnapshot['creditPeriodDays'] ?? data['creditPeriodDays'] ?? 0) as int;
          dueDate = docDate.add(Duration(days: creditDays));
        }

        final daysOverdue = now.difference(dueDate).inDays;

        if (!vendorMap.containsKey(key)) {
          vendorMap[key] = {
            'vendorName': vendorName,
            'totalOutstanding': 0.0,
            'current': 0.0,
            'overdue1to30': 0.0,
            'overdue31to60': 0.0,
            'overdue60plus': 0.0,
            'billCount': 0,
          };
        }

        vendorMap[key]!['totalOutstanding'] += outstanding;
        vendorMap[key]!['billCount'] += 1;

        if (daysOverdue <= 0) {
          vendorMap[key]!['current'] += outstanding;
        } else if (daysOverdue <= 30) {
          vendorMap[key]!['overdue1to30'] += outstanding;
        } else if (daysOverdue <= 60) {
          vendorMap[key]!['overdue31to60'] += outstanding;
        } else {
          vendorMap[key]!['overdue60plus'] += outstanding;
        }
      }

      final items = vendorMap.entries.map((entry) {
        return PayablesAgingItem(
          vendorName: entry.value['vendorName'],
          totalOutstanding: entry.value['totalOutstanding'],
          current: entry.value['current'],
          overdue1to30: entry.value['overdue1to30'],
          overdue31to60: entry.value['overdue31to60'],
          overdue60plus: entry.value['overdue60plus'],
          billCount: entry.value['billCount'],
        );
      }).toList();

      items.sort((a, b) => b.totalOutstanding.compareTo(a.totalOutstanding));
      return items;
    } catch (e) {
      debugPrint('Error getting payables aging: $e');
      return [];
    }
  }

  // ==================== GST SUMMARY ====================

  /// Get GST summary - output vs input GST for a date range
  Future<GstSummaryData?> getGstSummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_userId == null) return null;

    try {
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      // Output GST from sales invoices
      double outputCgst = 0, outputSgst = 0, outputIgst = 0;
      int salesCount = 0;

      final salesSnapshot = await _firestore
          .collection('invoices')
          .where('userId', isEqualTo: _userId)
          .get();

      for (final doc in salesSnapshot.docs) {
        final data = doc.data();
        final invoiceDate = (data['invoiceDate'] as Timestamp?)?.toDate();
        if (invoiceDate == null) continue;
        if (invoiceDate.isBefore(startDate) || invoiceDate.isAfter(endOfDay)) continue;

        outputCgst += (data['cgstTotal'] ?? 0).toDouble();
        outputSgst += (data['sgstTotal'] ?? 0).toDouble();
        outputIgst += (data['igstTotal'] ?? 0).toDouble();
        salesCount++;
      }

      // Input GST from recorded purchase bills
      double inputCgst = 0, inputSgst = 0, inputIgst = 0;
      int purchaseCount = 0;

      final purchaseSnapshot = await _firestore
          .collection('sharedDocuments')
          .where('receiverUserId', isEqualTo: _userId)
          .where('documentType', isEqualTo: 'invoice')
          .get();

      for (final doc in purchaseSnapshot.docs) {
        final data = doc.data();
        if (data['recordingStatus'] != 'recorded') continue;

        final docDate = (data['documentDate'] as Timestamp?)?.toDate();
        if (docDate == null) continue;
        if (docDate.isBefore(startDate) || docDate.isAfter(endOfDay)) continue;

        final docSnapshot = data['documentSnapshot'] as Map<String, dynamic>? ?? {};
        inputCgst += (docSnapshot['cgstTotal'] ?? 0).toDouble();
        inputSgst += (docSnapshot['sgstTotal'] ?? 0).toDouble();
        inputIgst += (docSnapshot['igstTotal'] ?? 0).toDouble();
        purchaseCount++;
      }

      final totalOutput = outputCgst + outputSgst + outputIgst;
      final totalInput = inputCgst + inputSgst + inputIgst;

      return GstSummaryData(
        outputCgst: outputCgst,
        outputSgst: outputSgst,
        outputIgst: outputIgst,
        inputCgst: inputCgst,
        inputSgst: inputSgst,
        inputIgst: inputIgst,
        totalOutput: totalOutput,
        totalInput: totalInput,
        netPayable: totalOutput - totalInput,
        salesInvoiceCount: salesCount,
        purchaseBillCount: purchaseCount,
      );
    } catch (e) {
      debugPrint('Error getting GST summary: $e');
      return null;
    }
  }

  // ==================== GSTR-1 ====================

  /// Get GSTR-1 data - B2B and B2C sales breakdown
  Future<Gstr1Data?> getGstr1Data({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_userId == null) return null;

    try {
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection('invoices')
          .where('userId', isEqualTo: _userId)
          .orderBy('invoiceDate', descending: true)
          .get();

      final b2bInvoices = <Gstr1InvoiceItem>[];
      final b2cInvoices = <Gstr1InvoiceItem>[];
      double b2bTotal = 0, b2cTotal = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final invoiceDate = (data['invoiceDate'] as Timestamp?)?.toDate();
        if (invoiceDate == null) continue;
        if (invoiceDate.isBefore(startDate) || invoiceDate.isAfter(endOfDay)) continue;

        final customerGstin = (data['customerGst'] ?? data['customerGstin'] ?? '').toString().trim();
        final subtotal = (data['subtotal'] ?? 0).toDouble();
        final discountAmount = (data['discountAmount'] ?? 0).toDouble();
        final taxableAmount = subtotal - discountAmount;
        final cgst = (data['cgstTotal'] ?? 0).toDouble();
        final sgst = (data['sgstTotal'] ?? 0).toDouble();
        final igst = (data['igstTotal'] ?? 0).toDouble();
        final total = (data['grandTotal'] ?? 0).toDouble();

        final item = Gstr1InvoiceItem(
          customerGstin: customerGstin,
          invoiceNumber: data['invoiceNumber'] ?? '-',
          invoiceDate: invoiceDate,
          customerName: data['customerName'] ?? '-',
          taxableAmount: taxableAmount,
          cgst: cgst,
          sgst: sgst,
          igst: igst,
          total: total,
        );

        if (customerGstin.isNotEmpty && customerGstin.length >= 15) {
          b2bInvoices.add(item);
          b2bTotal += total;
        } else {
          b2cInvoices.add(item);
          b2cTotal += total;
        }
      }

      // Sort by date ascending
      b2bInvoices.sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));
      b2cInvoices.sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));

      return Gstr1Data(
        b2bInvoices: b2bInvoices,
        b2cInvoices: b2cInvoices,
        b2bTotalAmount: b2bTotal,
        b2cTotalAmount: b2cTotal,
      );
    } catch (e) {
      debugPrint('Error getting GSTR-1 data: $e');
      return null;
    }
  }

  // ==================== GSTR-3B ====================

  /// Get GSTR-3B data - summary return format
  Future<Gstr3bData?> getGstr3bData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_userId == null) return null;

    try {
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      // Outward supplies (sales)
      double outwardTaxable = 0, outwardIgst = 0, outwardCgst = 0, outwardSgst = 0;

      final salesSnapshot = await _firestore
          .collection('invoices')
          .where('userId', isEqualTo: _userId)
          .get();

      for (final doc in salesSnapshot.docs) {
        final data = doc.data();
        final invoiceDate = (data['invoiceDate'] as Timestamp?)?.toDate();
        if (invoiceDate == null) continue;
        if (invoiceDate.isBefore(startDate) || invoiceDate.isAfter(endOfDay)) continue;

        final subtotal = (data['subtotal'] ?? 0).toDouble();
        final discountAmount = (data['discountAmount'] ?? 0).toDouble();
        outwardTaxable += (subtotal - discountAmount);
        outwardCgst += (data['cgstTotal'] ?? 0).toDouble();
        outwardSgst += (data['sgstTotal'] ?? 0).toDouble();
        outwardIgst += (data['igstTotal'] ?? 0).toDouble();
      }

      // Input tax credit (purchases)
      double inputTaxable = 0, inputIgst = 0, inputCgst = 0, inputSgst = 0;

      final purchaseSnapshot = await _firestore
          .collection('sharedDocuments')
          .where('receiverUserId', isEqualTo: _userId)
          .where('documentType', isEqualTo: 'invoice')
          .get();

      for (final doc in purchaseSnapshot.docs) {
        final data = doc.data();
        if (data['recordingStatus'] != 'recorded') continue;

        final docDate = (data['documentDate'] as Timestamp?)?.toDate();
        if (docDate == null) continue;
        if (docDate.isBefore(startDate) || docDate.isAfter(endOfDay)) continue;

        final docSnapshot = data['documentSnapshot'] as Map<String, dynamic>? ?? {};
        final subtotal = (docSnapshot['subtotal'] ?? 0).toDouble();
        final discountAmount = (docSnapshot['discountAmount'] ?? 0).toDouble();
        inputTaxable += (subtotal - discountAmount);
        inputCgst += (docSnapshot['cgstTotal'] ?? 0).toDouble();
        inputSgst += (docSnapshot['sgstTotal'] ?? 0).toDouble();
        inputIgst += (docSnapshot['igstTotal'] ?? 0).toDouble();
      }

      return Gstr3bData(
        outwardTaxable: outwardTaxable,
        outwardIgst: outwardIgst,
        outwardCgst: outwardCgst,
        outwardSgst: outwardSgst,
        inputTaxable: inputTaxable,
        inputIgst: inputIgst,
        inputCgst: inputCgst,
        inputSgst: inputSgst,
      );
    } catch (e) {
      debugPrint('Error getting GSTR-3B data: $e');
      return null;
    }
  }

  // ==================== LEDGER REPORT ====================

  /// Get ledger data for a specific account within a date range
  Future<LedgerData?> getLedger({
    required String accountId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_userId == null) return null;

    try {
      // Get account info
      final accountDoc = await _firestore.collection('accounts').doc(accountId).get();
      if (!accountDoc.exists) return null;
      final accountData = accountDoc.data() as Map<String, dynamic>;
      final accountName = accountData['name'] as String? ?? '';
      final accountType = accountData['type'] as String? ?? '';
      final isDebitNormal = accountType == 'asset' || accountType == 'expense';

      // Get all journal entries for this user, ordered by date
      final snapshot = await _firestore
          .collection('journalEntries')
          .where('userId', isEqualTo: _userId)
          .orderBy('date')
          .get();

      final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      double openingBalance = 0;
      final items = <LedgerItem>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp?)?.toDate();
        if (date == null) continue;

        // Find lines for this account
        final entries = (data['entries'] as List<dynamic>?) ?? [];
        double lineDebit = 0, lineCredit = 0;
        bool found = false;
        for (final e in entries) {
          final line = e as Map<String, dynamic>;
          if (line['accountId'] == accountId) {
            lineDebit += (line['debit'] as num?)?.toDouble() ?? 0;
            lineCredit += (line['credit'] as num?)?.toDouble() ?? 0;
            found = true;
          }
        }
        if (!found) continue;

        if (date.isBefore(startOfDay)) {
          // Before range - contribute to opening balance
          if (isDebitNormal) {
            openingBalance += lineDebit - lineCredit;
          } else {
            openingBalance += lineCredit - lineDebit;
          }
        } else if (!date.isAfter(endOfDay)) {
          items.add(LedgerItem(
            date: date,
            particular: data['narration'] ?? '',
            reference: data['referenceNumber'] ?? '',
            debit: lineDebit,
            credit: lineCredit,
            balance: 0, // placeholder
          ));
        }
      }

      // Calculate running balance
      double runningBalance = openingBalance;
      final balancedItems = <LedgerItem>[];
      for (final item in items) {
        if (isDebitNormal) {
          runningBalance += item.debit - item.credit;
        } else {
          runningBalance += item.credit - item.debit;
        }
        balancedItems.add(LedgerItem(
          date: item.date,
          particular: item.particular,
          reference: item.reference,
          debit: item.debit,
          credit: item.credit,
          balance: runningBalance,
        ));
      }

      return LedgerData(
        accountName: accountName,
        accountType: accountType,
        openingBalance: openingBalance,
        closingBalance: runningBalance,
        items: balancedItems,
      );
    } catch (e) {
      debugPrint('Error getting ledger: $e');
      return null;
    }
  }

  // ==================== DAY BOOK ====================

  /// Get all journal entries for a specific date
  Future<List<DayBookEntry>> getDayBook({required DateTime date}) async {
    if (_userId == null) return [];

    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection('journalEntries')
          .where('userId', isEqualTo: _userId)
          .orderBy('date')
          .get();

      final items = <DayBookEntry>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final entryDate = (data['date'] as Timestamp?)?.toDate();
        if (entryDate == null) continue;

        if (entryDate.isBefore(startOfDay) || entryDate.isAfter(endOfDay)) continue;

        final entries = (data['entries'] as List<dynamic>?) ?? [];
        final lines = entries.map((e) {
          final line = e as Map<String, dynamic>;
          return DayBookLine(
            accountName: line['accountName'] ?? '',
            debit: (line['debit'] as num?)?.toDouble() ?? 0,
            credit: (line['credit'] as num?)?.toDouble() ?? 0,
          );
        }).toList();

        items.add(DayBookEntry(
          entryNumber: data['entryNumber'] ?? '',
          narration: data['narration'] ?? '',
          referenceNumber: data['referenceNumber'] ?? '',
          referenceType: data['referenceType'] ?? '',
          date: entryDate,
          lines: lines,
          totalDebit: (data['totalDebit'] as num?)?.toDouble() ?? 0,
          totalCredit: (data['totalCredit'] as num?)?.toDouble() ?? 0,
        ));
      }

      return items;
    } catch (e) {
      debugPrint('Error getting day book: $e');
      return [];
    }
  }

  // ==================== TRIAL BALANCE ====================

  /// Get trial balance - all accounts with debit/credit balances
  Future<List<TrialBalanceItem>> getTrialBalance() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('accounts')
          .where('userId', isEqualTo: _userId)
          .where('isActive', isEqualTo: true)
          .orderBy('code')
          .get();

      final items = <TrialBalanceItem>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
        if (balance == 0) continue; // Skip zero-balance accounts

        final type = data['type'] as String? ?? '';
        final isDebitNormal = type == 'asset' || type == 'expense';

        double debitBalance = 0, creditBalance = 0;
        if (isDebitNormal) {
          if (balance >= 0) {
            debitBalance = balance;
          } else {
            creditBalance = balance.abs();
          }
        } else {
          if (balance >= 0) {
            creditBalance = balance;
          } else {
            debitBalance = balance.abs();
          }
        }

        items.add(TrialBalanceItem(
          accountCode: data['code'] ?? '',
          accountName: data['name'] ?? '',
          accountType: type,
          debitBalance: debitBalance,
          creditBalance: creditBalance,
        ));
      }

      return items;
    } catch (e) {
      debugPrint('Error getting trial balance: $e');
      return [];
    }
  }

  // ==================== PROFIT & LOSS ====================

  /// Get profit and loss statement for a date range
  Future<ProfitLossData?> getProfitAndLoss({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_userId == null) return null;

    try {
      final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      // Get all accounts to map IDs to names and types
      final accountsSnapshot = await _firestore
          .collection('accounts')
          .where('userId', isEqualTo: _userId)
          .where('isActive', isEqualTo: true)
          .get();

      final accountMap = <String, Map<String, String>>{};
      for (final doc in accountsSnapshot.docs) {
        final data = doc.data();
        accountMap[doc.id] = {
          'name': data['name'] ?? '',
          'type': data['type'] ?? '',
          'subType': data['subType'] ?? '',
        };
      }

      // Get journal entries in the date range
      final entriesSnapshot = await _firestore
          .collection('journalEntries')
          .where('userId', isEqualTo: _userId)
          .orderBy('date')
          .get();

      // Accumulate amounts per account for income and expense
      final accountTotals = <String, double>{};

      for (final doc in entriesSnapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp?)?.toDate();
        if (date == null) continue;
        if (date.isBefore(startOfDay) || date.isAfter(endOfDay)) continue;

        final entries = (data['entries'] as List<dynamic>?) ?? [];
        for (final e in entries) {
          final line = e as Map<String, dynamic>;
          final accountId = line['accountId'] as String?;
          if (accountId == null) continue;

          final accountInfo = accountMap[accountId];
          if (accountInfo == null) continue;

          final type = accountInfo['type']!;
          if (type != 'income' && type != 'expense') continue;

          final debit = (line['debit'] as num?)?.toDouble() ?? 0;
          final credit = (line['credit'] as num?)?.toDouble() ?? 0;

          // For income (credit-normal): amount = credit - debit
          // For expense (debit-normal): amount = debit - credit
          double amount;
          if (type == 'income') {
            amount = credit - debit;
          } else {
            amount = debit - credit;
          }

          accountTotals[accountId] = (accountTotals[accountId] ?? 0) + amount;
        }
      }

      // Build income and expense line items
      final incomeItems = <ProfitLossLineItem>[];
      final expenseItems = <ProfitLossLineItem>[];
      double totalIncome = 0, totalExpenses = 0;

      for (final entry in accountTotals.entries) {
        final accountInfo = accountMap[entry.key];
        if (accountInfo == null) continue;
        final amount = entry.value;
        if (amount == 0) continue;

        final item = ProfitLossLineItem(
          accountName: accountInfo['name']!,
          subType: accountInfo['subType']!,
          amount: amount,
        );

        if (accountInfo['type'] == 'income') {
          incomeItems.add(item);
          totalIncome += amount;
        } else {
          expenseItems.add(item);
          totalExpenses += amount;
        }
      }

      // Sort by amount descending
      incomeItems.sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
      expenseItems.sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));

      return ProfitLossData(
        incomeItems: incomeItems,
        expenseItems: expenseItems,
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        netProfit: totalIncome - totalExpenses,
      );
    } catch (e) {
      debugPrint('Error getting P&L: $e');
      return null;
    }
  }

  // ==================== BALANCE SHEET ====================

  /// Get balance sheet data (as of current date using account balances)
  Future<BalanceSheetData?> getBalanceSheet() async {
    if (_userId == null) return null;

    try {
      final snapshot = await _firestore
          .collection('accounts')
          .where('userId', isEqualTo: _userId)
          .where('isActive', isEqualTo: true)
          .orderBy('code')
          .get();

      final assetItems = <BalanceSheetLineItem>[];
      final liabilityItems = <BalanceSheetLineItem>[];
      final equityItems = <BalanceSheetLineItem>[];
      double totalAssets = 0, totalLiabilities = 0, totalEquity = 0;
      double totalIncome = 0, totalExpenses = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
        if (balance == 0) continue;

        final type = data['type'] as String? ?? '';
        final subType = data['subType'] as String? ?? '';
        final name = data['name'] as String? ?? '';

        final item = BalanceSheetLineItem(
          accountName: name,
          subType: subType,
          amount: balance,
        );

        switch (type) {
          case 'asset':
            assetItems.add(item);
            totalAssets += balance;
            break;
          case 'liability':
            liabilityItems.add(item);
            totalLiabilities += balance;
            break;
          case 'equity':
            equityItems.add(item);
            totalEquity += balance;
            break;
          case 'income':
            totalIncome += balance;
            break;
          case 'expense':
            totalExpenses += balance;
            break;
        }
      }

      // Retained Earnings = Income - Expenses (cumulative)
      final retainedEarnings = totalIncome - totalExpenses;

      return BalanceSheetData(
        assetItems: assetItems,
        liabilityItems: liabilityItems,
        equityItems: equityItems,
        totalAssets: totalAssets,
        totalLiabilities: totalLiabilities,
        totalEquity: totalEquity + retainedEarnings,
        retainedEarnings: retainedEarnings,
      );
    } catch (e) {
      debugPrint('Error getting balance sheet: $e');
      return null;
    }
  }

  // ==================== ACCOUNT LIST HELPERS ====================

  /// Get all active accounts for the user (for account selector dropdowns)
  Future<List<Map<String, dynamic>>> getAccountList() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('accounts')
          .where('userId', isEqualTo: _userId)
          .where('isActive', isEqualTo: true)
          .orderBy('code')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'code': data['code'] ?? '',
          'name': data['name'] ?? '',
          'type': data['type'] ?? '',
          'subType': data['subType'] ?? '',
          'balance': (data['balance'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting account list: $e');
      return [];
    }
  }

  /// Get bank accounts for the user
  Future<List<Map<String, dynamic>>> getBankAccountList() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('accounts')
          .where('userId', isEqualTo: _userId)
          .where('subType', isEqualTo: 'bank')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'code': data['code'] ?? '',
          'name': data['name'] ?? '',
          'balance': (data['balance'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting bank accounts: $e');
      return [];
    }
  }

  /// Get list of customers for dropdown
  Future<List<Map<String, String>>> getCustomerList() async {
    if (_userId == null) return [];
    try {
      final snapshot = await _firestore
          .collection('customers')
          .where('userId', isEqualTo: _userId)
          .orderBy('customerName')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': (data['customerName'] as String?) ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting customer list: $e');
      return [];
    }
  }

  /// Get list of vendors for dropdown
  Future<List<Map<String, String>>> getVendorList() async {
    if (_userId == null) return [];
    try {
      final snapshot = await _firestore
          .collection('vendors')
          .where('userId', isEqualTo: _userId)
          .orderBy('vendorName')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': (data['vendorName'] as String?) ?? '',
          'linkedVyaparId': (data['linkedVyaparId'] as String?) ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting vendor list: $e');
      return [];
    }
  }

  /// Get customer ledger - all transactions for a specific customer
  Future<PartyLedgerData?> getCustomerLedger({
    required String customerId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_userId == null) return null;

    try {
      // Fetch invoices for this customer
      final invoiceSnapshot = await _firestore
          .collection('invoices')
          .where('userId', isEqualTo: _userId)
          .where('customerId', isEqualTo: customerId)
          .orderBy('invoiceDate')
          .get();

      // Fetch payments for this customer
      final paymentSnapshot = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: _userId)
          .where('customerId', isEqualTo: customerId)
          .orderBy('paymentDate')
          .get();

      // Fetch credit notes for this customer
      final creditNoteSnapshot = await _firestore
          .collection('creditNotes')
          .where('userId', isEqualTo: _userId)
          .where('customerId', isEqualTo: customerId)
          .orderBy('creditNoteDate')
          .get();

      // Build combined transaction list
      final allItems = <PartyLedgerItem>[];
      String customerName = '';

      for (final doc in invoiceSnapshot.docs) {
        final data = doc.data();
        if (customerName.isEmpty) {
          customerName = (data['customerName'] as String?) ?? '';
        }
        final date = (data['invoiceDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final amount = (data['grandTotal'] as num?)?.toDouble() ?? 0.0;
        allItems.add(PartyLedgerItem(
          date: date,
          particular: 'Sales Invoice',
          reference: (data['invoiceNumber'] as String?) ?? '',
          debit: amount,
          credit: 0,
          type: 'invoice',
        ));
      }

      for (final doc in paymentSnapshot.docs) {
        final data = doc.data();
        final date = (data['paymentDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        allItems.add(PartyLedgerItem(
          date: date,
          particular: 'Payment Received',
          reference: (data['paymentNumber'] as String?) ?? '',
          debit: 0,
          credit: amount,
          type: 'payment',
        ));
      }

      for (final doc in creditNoteSnapshot.docs) {
        final data = doc.data();
        if (customerName.isEmpty) {
          customerName = (data['customerName'] as String?) ?? '';
        }
        final date = (data['creditNoteDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final amount = (data['grandTotal'] as num?)?.toDouble() ?? 0.0;
        allItems.add(PartyLedgerItem(
          date: date,
          particular: 'Credit Note',
          reference: (data['creditNoteNumber'] as String?) ?? '',
          debit: 0,
          credit: amount,
          type: 'credit_note',
        ));
      }

      // Sort by date
      allItems.sort((a, b) => a.date.compareTo(b.date));

      // Split into before-range (opening) and in-range
      final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      double openingBalance = 0;
      final inRangeItems = <PartyLedgerItem>[];

      for (final item in allItems) {
        if (item.date.isBefore(startOfDay)) {
          openingBalance += item.debit - item.credit;
        } else if (!item.date.isAfter(endOfDay)) {
          inRangeItems.add(item);
        }
      }

      // Calculate running balance
      double runningBalance = openingBalance;
      double totalDebit = 0;
      double totalCredit = 0;
      final balancedItems = <PartyLedgerItem>[];

      for (final item in inRangeItems) {
        runningBalance += item.debit - item.credit;
        totalDebit += item.debit;
        totalCredit += item.credit;
        balancedItems.add(PartyLedgerItem(
          date: item.date,
          particular: item.particular,
          reference: item.reference,
          debit: item.debit,
          credit: item.credit,
          type: item.type,
          balance: runningBalance,
        ));
      }

      return PartyLedgerData(
        partyName: customerName,
        partyType: 'Customer',
        openingBalance: openingBalance,
        closingBalance: runningBalance,
        totalDebit: totalDebit,
        totalCredit: totalCredit,
        items: balancedItems,
      );
    } catch (e) {
      debugPrint('Error getting customer ledger: $e');
      return null;
    }
  }

  /// Get vendor ledger - all transactions for a specific vendor
  Future<PartyLedgerData?> getVendorLedger({
    required String vendorId,
    required String vendorLinkedVyaparId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_userId == null) return null;

    try {
      final allItems = <PartyLedgerItem>[];
      String vendorName = '';

      // Fetch bills (sharedDocuments where sender is this vendor)
      if (vendorLinkedVyaparId.isNotEmpty) {
        final billSnapshot = await _firestore
            .collection('sharedDocuments')
            .where('receiverUserId', isEqualTo: _userId)
            .where('senderVyaparId', isEqualTo: vendorLinkedVyaparId)
            .where('documentType', isEqualTo: 'invoice')
            .get();

        for (final doc in billSnapshot.docs) {
          final data = doc.data();
          final recordingStatus = (data['recordingStatus'] as String?) ?? 'pending';
          if (recordingStatus != 'recorded') continue;

          if (vendorName.isEmpty) {
            vendorName = (data['senderCompanyName'] as String?) ?? '';
          }
          final date = (data['recordedAt'] as Timestamp?)?.toDate() ??
              (data['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now();
          final documentData = data['documentData'] as Map<String, dynamic>?;
          final amount = (documentData?['grandTotal'] as num?)?.toDouble() ?? 0.0;
          final billNumber = (documentData?['invoiceNumber'] as String?) ?? '';

          allItems.add(PartyLedgerItem(
            date: date,
            particular: 'Purchase Bill',
            reference: billNumber,
            debit: 0,
            credit: amount,
            type: 'bill',
          ));
        }
      }

      // Fetch vendor payments
      final paymentSnapshot = await _firestore
          .collection('vendorPayments')
          .where('userId', isEqualTo: _userId)
          .where('vendorId', isEqualTo: vendorId)
          .orderBy('paymentDate')
          .get();

      for (final doc in paymentSnapshot.docs) {
        final data = doc.data();
        if (vendorName.isEmpty) {
          vendorName = (data['vendorName'] as String?) ?? '';
        }
        final date = (data['paymentDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        allItems.add(PartyLedgerItem(
          date: date,
          particular: 'Payment Made',
          reference: (data['paymentNumber'] as String?) ?? '',
          debit: amount,
          credit: 0,
          type: 'payment',
        ));
      }

      // Fetch debit notes
      final debitNoteSnapshot = await _firestore
          .collection('debitNotes')
          .where('userId', isEqualTo: _userId)
          .where('vendorId', isEqualTo: vendorId)
          .orderBy('debitNoteDate')
          .get();

      for (final doc in debitNoteSnapshot.docs) {
        final data = doc.data();
        if (vendorName.isEmpty) {
          vendorName = (data['vendorName'] as String?) ?? '';
        }
        final date = (data['debitNoteDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final amount = (data['grandTotal'] as num?)?.toDouble() ?? 0.0;
        allItems.add(PartyLedgerItem(
          date: date,
          particular: 'Debit Note',
          reference: (data['debitNoteNumber'] as String?) ?? '',
          debit: amount,
          credit: 0,
          type: 'debit_note',
        ));
      }

      // Sort by date
      allItems.sort((a, b) => a.date.compareTo(b.date));

      // Split into before-range (opening) and in-range
      // For vendor: credit = increases payable, debit = decreases payable
      // Balance = what we owe (positive = we owe, negative = they owe us)
      final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      double openingBalance = 0;
      final inRangeItems = <PartyLedgerItem>[];

      for (final item in allItems) {
        if (item.date.isBefore(startOfDay)) {
          openingBalance += item.credit - item.debit;
        } else if (!item.date.isAfter(endOfDay)) {
          inRangeItems.add(item);
        }
      }

      // Calculate running balance
      double runningBalance = openingBalance;
      double totalDebit = 0;
      double totalCredit = 0;
      final balancedItems = <PartyLedgerItem>[];

      for (final item in inRangeItems) {
        runningBalance += item.credit - item.debit;
        totalDebit += item.debit;
        totalCredit += item.credit;
        balancedItems.add(PartyLedgerItem(
          date: item.date,
          particular: item.particular,
          reference: item.reference,
          debit: item.debit,
          credit: item.credit,
          type: item.type,
          balance: runningBalance,
        ));
      }

      return PartyLedgerData(
        partyName: vendorName,
        partyType: 'Vendor',
        openingBalance: openingBalance,
        closingBalance: runningBalance,
        totalDebit: totalDebit,
        totalCredit: totalCredit,
        items: balancedItems,
      );
    } catch (e) {
      debugPrint('Error getting vendor ledger: $e');
      return null;
    }
  }

  /// Get cash account ID
  Future<String?> getCashAccountId() async {
    if (_userId == null) return null;

    try {
      final snapshot = await _firestore
          .collection('accounts')
          .where('userId', isEqualTo: _userId)
          .where('subType', isEqualTo: 'cash')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.id;
    } catch (e) {
      debugPrint('Error getting cash account: $e');
      return null;
    }
  }
}
