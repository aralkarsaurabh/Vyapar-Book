import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'quotation_service.dart' show LineItem;
import 'profile_service.dart';
import 'accounting_service.dart';

// Re-export LineItem for convenience
export 'quotation_service.dart' show LineItem;

/// Payment status constants
class PaymentStatus {
  static const String unpaid = 'unpaid';
  static const String partial = 'partial';
  static const String paid = 'paid';
}

/// Credit period options in days
class CreditPeriod {
  static const List<int> options = [0, 7, 15, 30, 45, 60, 90];

  static String getLabel(int days) {
    if (days == 0) return 'Due Immediately';
    return '$days Days';
  }
}

// Invoice model
class Invoice {
  String? id;
  String? userId;
  String? invoiceNumber;
  String? referenceNumber; // Quotation number when converted from quotation

  // Invoice Details
  String? customerId;
  String? customerName;
  String? placeOfSupply;
  DateTime? invoiceDate;
  DateTime? dueDate;
  String? invoiceType; // GST or Non-GST

  // Payment Terms
  int creditPeriodDays; // 0, 7, 15, 30, 45, 60, 90

  // Payment Status
  String paymentStatus; // 'unpaid', 'partial', 'paid'
  double amountPaid;
  double amountDue;

  // Line Items
  List<LineItem> lineItems;

  // Totals
  double subtotal;
  bool hasDiscount;
  String? discountType; // percentage or amount
  double discountValue;
  double discountAmount;
  double grandTotal;

  // Tax totals
  double cgstTotal;
  double sgstTotal;
  double igstTotal;
  double taxTotal;

  // Additional Details
  String? notes;
  String? termsAndConditions;

  // Company Details (saved at creation time)
  Map<String, dynamic>? companyDetails;
  Map<String, dynamic>? bankDetails;
  Map<String, dynamic>? userDetails;
  Map<String, dynamic>? customerDetails;

  DateTime? createdAt;
  DateTime? updatedAt;

  Invoice({
    this.id,
    this.userId,
    this.invoiceNumber,
    this.referenceNumber,
    this.customerId,
    this.customerName,
    this.placeOfSupply,
    this.invoiceDate,
    this.dueDate,
    this.invoiceType,
    this.creditPeriodDays = 30,
    this.paymentStatus = PaymentStatus.unpaid,
    this.amountPaid = 0,
    this.amountDue = 0,
    List<LineItem>? lineItems,
    this.subtotal = 0,
    this.hasDiscount = false,
    this.discountType,
    this.discountValue = 0,
    this.discountAmount = 0,
    this.grandTotal = 0,
    this.cgstTotal = 0,
    this.sgstTotal = 0,
    this.igstTotal = 0,
    this.taxTotal = 0,
    this.notes,
    this.termsAndConditions,
    this.companyDetails,
    this.bankDetails,
    this.userDetails,
    this.customerDetails,
    this.createdAt,
    this.updatedAt,
  }) : lineItems = lineItems ?? [];

  factory Invoice.fromMap(Map<String, dynamic> map, String docId) {
    return Invoice(
      id: docId,
      userId: map['userId'],
      invoiceNumber: map['invoiceNumber'],
      referenceNumber: map['referenceNumber'],
      customerId: map['customerId'],
      customerName: map['customerName'],
      placeOfSupply: map['placeOfSupply'],
      invoiceDate: map['invoiceDate']?.toDate(),
      dueDate: map['dueDate']?.toDate(),
      invoiceType: map['invoiceType'],
      creditPeriodDays: map['creditPeriodDays'] ?? 30,
      paymentStatus: map['paymentStatus'] ?? PaymentStatus.unpaid,
      amountPaid: (map['amountPaid'] ?? 0).toDouble(),
      amountDue: (map['amountDue'] ?? map['grandTotal'] ?? 0).toDouble(),
      lineItems: (map['lineItems'] as List<dynamic>?)
              ?.map((item) => LineItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      hasDiscount: map['hasDiscount'] ?? false,
      discountType: map['discountType'],
      discountValue: (map['discountValue'] ?? 0).toDouble(),
      discountAmount: (map['discountAmount'] ?? 0).toDouble(),
      grandTotal: (map['grandTotal'] ?? 0).toDouble(),
      cgstTotal: (map['cgstTotal'] ?? 0).toDouble(),
      sgstTotal: (map['sgstTotal'] ?? 0).toDouble(),
      igstTotal: (map['igstTotal'] ?? 0).toDouble(),
      taxTotal: (map['taxTotal'] ?? 0).toDouble(),
      notes: map['notes'],
      termsAndConditions: map['termsAndConditions'],
      companyDetails: map['companyDetails'] as Map<String, dynamic>?,
      bankDetails: map['bankDetails'] as Map<String, dynamic>?,
      userDetails: map['userDetails'] as Map<String, dynamic>?,
      customerDetails: map['customerDetails'] as Map<String, dynamic>?,
      createdAt: map['createdAt']?.toDate(),
      updatedAt: map['updatedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'invoiceNumber': invoiceNumber,
      'referenceNumber': referenceNumber,
      'customerId': customerId,
      'customerName': customerName,
      'placeOfSupply': placeOfSupply,
      'invoiceDate': invoiceDate != null ? Timestamp.fromDate(invoiceDate!) : null,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'invoiceType': invoiceType,
      'creditPeriodDays': creditPeriodDays,
      'paymentStatus': paymentStatus,
      'amountPaid': amountPaid,
      'amountDue': amountDue,
      'lineItems': lineItems.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'hasDiscount': hasDiscount,
      'discountType': discountType,
      'discountValue': discountValue,
      'discountAmount': discountAmount,
      'grandTotal': grandTotal,
      'cgstTotal': cgstTotal,
      'sgstTotal': sgstTotal,
      'igstTotal': igstTotal,
      'taxTotal': taxTotal,
      'notes': notes,
      'termsAndConditions': termsAndConditions,
      'companyDetails': companyDetails,
      'bankDetails': bankDetails,
      'userDetails': userDetails,
      'customerDetails': customerDetails,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Check if transaction is intra-state (same state = CGST+SGST) or inter-state (IGST)
  bool get isIntraState {
    final companyState = companyDetails?['state'] as String?;
    final customerState = customerDetails?['state'] as String?;
    return companyState != null && customerState != null && companyState == customerState;
  }

  void calculateTotals() {
    final intraState = isIntraState;

    // Calculate line item taxes
    for (final item in lineItems) {
      item.calculateTotal(isIntraState: intraState);
    }

    // Calculate subtotal (taxable amount before GST)
    subtotal = lineItems.fold(0, (sum, item) => sum + item.taxableAmount);

    // Calculate tax totals
    cgstTotal = lineItems.fold(0, (sum, item) => sum + item.cgstAmount);
    sgstTotal = lineItems.fold(0, (sum, item) => sum + item.sgstAmount);
    igstTotal = lineItems.fold(0, (sum, item) => sum + item.igstAmount);
    taxTotal = cgstTotal + sgstTotal + igstTotal;

    // Calculate discount on taxable amount
    if (hasDiscount && discountValue > 0) {
      if (discountType == 'percentage') {
        discountAmount = subtotal * (discountValue / 100);
      } else {
        discountAmount = discountValue;
      }
    } else {
      discountAmount = 0;
    }

    // Calculate grand total
    grandTotal = subtotal + taxTotal - discountAmount;
    if (grandTotal < 0) grandTotal = 0;
  }
}

class InvoiceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProfileService _profileService = ProfileService();

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference get _invoicesCollection =>
      _firestore.collection('invoices');

  // Extract initials from company name (e.g., "Triroop Pvt Ltd" -> "TPL")
  static String getCompanyInitials(String? companyName) {
    if (companyName == null || companyName.isEmpty) return 'INV';

    final words = companyName.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase())
        .join();

    return initials.isNotEmpty ? initials : 'INV';
  }

  // Indian States list
  static const List<String> indianStates = [
    'Andaman and Nicobar Islands',
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chandigarh',
    'Chhattisgarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jammu and Kashmir',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Ladakh',
    'Lakshadweep',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Puducherry',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
  ];

  // GST Percentage options
  static const List<double> gstPercentages = [0, 5, 12, 18, 28];

  // State codes for GST
  static const Map<String, String> stateCodes = {
    'Andaman and Nicobar Islands': '35',
    'Andhra Pradesh': '37',
    'Arunachal Pradesh': '12',
    'Assam': '18',
    'Bihar': '10',
    'Chandigarh': '04',
    'Chhattisgarh': '22',
    'Dadra and Nagar Haveli and Daman and Diu': '26',
    'Delhi': '07',
    'Goa': '30',
    'Gujarat': '24',
    'Haryana': '06',
    'Himachal Pradesh': '02',
    'Jammu and Kashmir': '01',
    'Jharkhand': '20',
    'Karnataka': '29',
    'Kerala': '32',
    'Ladakh': '38',
    'Lakshadweep': '31',
    'Madhya Pradesh': '23',
    'Maharashtra': '27',
    'Manipur': '14',
    'Meghalaya': '17',
    'Mizoram': '15',
    'Nagaland': '13',
    'Odisha': '21',
    'Puducherry': '34',
    'Punjab': '03',
    'Rajasthan': '08',
    'Sikkim': '11',
    'Tamil Nadu': '33',
    'Telangana': '36',
    'Tripura': '16',
    'Uttar Pradesh': '09',
    'Uttarakhand': '05',
    'West Bengal': '19',
  };

  // Get state code from state name
  static String? getStateCode(String? stateName) {
    if (stateName == null) return null;
    return stateCodes[stateName];
  }

  // Get state code from GST number (first 2 digits)
  static String? getStateCodeFromGst(String? gstNumber) {
    if (gstNumber == null || gstNumber.length < 2) return null;
    return gstNumber.substring(0, 2);
  }

  // Generate invoice number: PREFIX/INV/YYYY-YY/NNN (e.g., TPL/INV/2025-26/001)
  Future<String> generateInvoiceNumber() async {
    if (_userId == null) return '';

    // Get company profile to extract initials
    final companyProfile = await _profileService.getCompanyProfile();
    final companyInitials = getCompanyInitials(companyProfile?.companyLegalName);

    final now = DateTime.now();
    // Financial year: April to March
    final year = now.month >= 4 ? now.year : now.year - 1;
    final nextYear = year + 1;
    final financialYear = '$year-${nextYear.toString().substring(2)}';
    final prefix = '$companyInitials/INV/$financialYear/';

    try {
      // Get all invoices for this user in this financial year
      final startDate = DateTime(year, 4, 1);
      final endDate = DateTime(nextYear, 3, 31, 23, 59, 59);

      final snapshot = await _invoicesCollection
          .where('userId', isEqualTo: _userId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('createdAt', descending: true)
          .get();

      int nextNumber = 1;

      if (snapshot.docs.isNotEmpty) {
        // Find the highest sequence number from existing invoices
        // Match any prefix pattern ending with /INV/YYYY-YY/
        final numberRegex = RegExp(r'/INV/\d{4}-\d{2}/(\d+)$');
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final iNumber = data['invoiceNumber'] as String?;
          if (iNumber != null) {
            final match = numberRegex.firstMatch(iNumber);
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
      debugPrint('Error generating invoice number: $e');
      // Fallback: count existing invoices + 1
      try {
        final countSnapshot = await _invoicesCollection
            .where('userId', isEqualTo: _userId)
            .get();
        final nextNumber = countSnapshot.docs.length + 1;
        return '$prefix${nextNumber.toString().padLeft(3, '0')}';
      } catch (_) {
        return '${prefix}001';
      }
    }
  }

  // Get all invoices for the current user
  Stream<List<Invoice>> getInvoices() {
    if (_userId == null) return Stream.value([]);

    return _invoicesCollection
        .where('userId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
      debugPrint('===========================================');
      debugPrint('FIRESTORE ERROR: $error');
      if (error.toString().contains('index')) {
        debugPrint('');
        debugPrint('Please create the required index by visiting the URL above.');
      }
      debugPrint('===========================================');
    }).map((snapshot) {
      return snapshot.docs.map((doc) {
        return Invoice.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // Get a single invoice by ID
  Future<Invoice?> getInvoiceById(String invoiceId) async {
    if (_userId == null) return null;

    try {
      final doc = await _invoicesCollection.doc(invoiceId).get();
      if (doc.exists) {
        final invoice = Invoice.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        if (invoice.userId == _userId) {
          return invoice;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting invoice: $e');
      return null;
    }
  }

  // Add a new invoice
  Future<String?> addInvoice(Invoice invoice) async {
    if (_userId == null) return null;

    try {
      invoice.userId = _userId;
      invoice.invoiceNumber = await generateInvoiceNumber();

      // Calculate due date from invoice date and credit period
      if (invoice.invoiceDate != null) {
        invoice.dueDate = invoice.invoiceDate!.add(
          Duration(days: invoice.creditPeriodDays),
        );
      }

      // Set initial payment status
      invoice.paymentStatus = PaymentStatus.unpaid;
      invoice.amountPaid = 0;
      invoice.amountDue = invoice.grandTotal;

      final map = invoice.toMap();
      map['createdAt'] = FieldValue.serverTimestamp();

      final docRef = await _invoicesCollection.add(map);
      final invoiceId = docRef.id;

      // Create journal entry for the invoice
      try {
        final accountingService = AccountingService();
        await accountingService.recordSalesInvoice(
          invoiceId: invoiceId,
          invoiceNumber: invoice.invoiceNumber ?? '',
          customerName: invoice.customerName ?? '',
          invoiceDate: invoice.invoiceDate ?? DateTime.now(),
          subtotal: invoice.subtotal,
          grandTotal: invoice.grandTotal,
          cgstAmount: invoice.cgstTotal,
          sgstAmount: invoice.sgstTotal,
          igstAmount: invoice.igstTotal,
          discountAmount: invoice.discountAmount,
        );
      } catch (e) {
        debugPrint('Error creating journal entry: $e');
        // Don't fail invoice creation if accounting fails
      }

      return invoiceId;
    } catch (e) {
      debugPrint('Error adding invoice: $e');
      return null;
    }
  }

  // Update an invoice
  Future<bool> updateInvoice(Invoice invoice) async {
    if (_userId == null || invoice.id == null) return false;

    try {
      final existingInvoice = await getInvoiceById(invoice.id!);
      if (existingInvoice == null || existingInvoice.userId != _userId) {
        return false;
      }

      await _invoicesCollection.doc(invoice.id).update(invoice.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating invoice: $e');
      return false;
    }
  }

  // Delete an invoice
  Future<bool> deleteInvoice(String invoiceId) async {
    if (_userId == null) return false;

    try {
      final existingInvoice = await getInvoiceById(invoiceId);
      if (existingInvoice == null || existingInvoice.userId != _userId) {
        return false;
      }

      await _invoicesCollection.doc(invoiceId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting invoice: $e');
      return false;
    }
  }
}
