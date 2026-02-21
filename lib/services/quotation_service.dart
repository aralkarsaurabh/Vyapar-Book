import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'profile_service.dart';

// Line item model
class LineItem {
  String? title;
  String? description;
  String? hsnSacCode;
  double quantity;
  double rate;
  double gstPercentage;
  double total;
  String? unitOfMeasure;

  // Tax breakdown
  double taxableAmount;
  double cgstRate;
  double cgstAmount;
  double sgstRate;
  double sgstAmount;
  double igstRate;
  double igstAmount;

  LineItem({
    this.title,
    this.description,
    this.hsnSacCode,
    this.quantity = 1,
    this.rate = 0,
    this.gstPercentage = 0,
    this.total = 0,
    this.unitOfMeasure = 'Nos',
    this.taxableAmount = 0,
    this.cgstRate = 0,
    this.cgstAmount = 0,
    this.sgstRate = 0,
    this.sgstAmount = 0,
    this.igstRate = 0,
    this.igstAmount = 0,
  });

  factory LineItem.fromMap(Map<String, dynamic> map) {
    return LineItem(
      title: map['title'],
      description: map['description'],
      hsnSacCode: map['hsnSacCode'],
      quantity: (map['quantity'] ?? 1).toDouble(),
      rate: (map['rate'] ?? 0).toDouble(),
      gstPercentage: (map['gstPercentage'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
      unitOfMeasure: map['unitOfMeasure'] ?? 'Nos',
      taxableAmount: (map['taxableAmount'] ?? 0).toDouble(),
      cgstRate: (map['cgstRate'] ?? 0).toDouble(),
      cgstAmount: (map['cgstAmount'] ?? 0).toDouble(),
      sgstRate: (map['sgstRate'] ?? 0).toDouble(),
      sgstAmount: (map['sgstAmount'] ?? 0).toDouble(),
      igstRate: (map['igstRate'] ?? 0).toDouble(),
      igstAmount: (map['igstAmount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'hsnSacCode': hsnSacCode,
      'quantity': quantity,
      'rate': rate,
      'gstPercentage': gstPercentage,
      'total': total,
      'unitOfMeasure': unitOfMeasure,
      'taxableAmount': taxableAmount,
      'cgstRate': cgstRate,
      'cgstAmount': cgstAmount,
      'sgstRate': sgstRate,
      'sgstAmount': sgstAmount,
      'igstRate': igstRate,
      'igstAmount': igstAmount,
    };
  }

  void calculateTotal({bool isIntraState = true}) {
    taxableAmount = quantity * rate;

    if (isIntraState) {
      // Intra-state: CGST + SGST (half each)
      cgstRate = gstPercentage / 2;
      sgstRate = gstPercentage / 2;
      igstRate = 0;
      cgstAmount = taxableAmount * (cgstRate / 100);
      sgstAmount = taxableAmount * (sgstRate / 100);
      igstAmount = 0;
    } else {
      // Inter-state: IGST
      cgstRate = 0;
      sgstRate = 0;
      igstRate = gstPercentage;
      cgstAmount = 0;
      sgstAmount = 0;
      igstAmount = taxableAmount * (igstRate / 100);
    }

    total = taxableAmount + cgstAmount + sgstAmount + igstAmount;
  }
}

// Quotation model
class Quotation {
  String? id;
  String? userId;
  String? quotationNumber;

  // Quotation Details
  String? customerId;
  String? customerName;
  String? placeOfSupply;
  DateTime? quotationDate;
  DateTime? validUntilDate;
  String? quotationType; // GST or Non-GST

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

  // Conversion tracking
  bool convertedToInvoice;
  String? convertedInvoiceId;
  DateTime? convertedAt;

  Quotation({
    this.id,
    this.userId,
    this.quotationNumber,
    this.customerId,
    this.customerName,
    this.placeOfSupply,
    this.quotationDate,
    this.validUntilDate,
    this.quotationType,
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
    this.convertedToInvoice = false,
    this.convertedInvoiceId,
    this.convertedAt,
  }) : lineItems = lineItems ?? [];

  factory Quotation.fromMap(Map<String, dynamic> map, String docId) {
    return Quotation(
      id: docId,
      userId: map['userId'],
      quotationNumber: map['quotationNumber'],
      customerId: map['customerId'],
      customerName: map['customerName'],
      placeOfSupply: map['placeOfSupply'],
      quotationDate: map['quotationDate']?.toDate(),
      validUntilDate: map['validUntilDate']?.toDate(),
      quotationType: map['quotationType'],
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
      convertedToInvoice: map['convertedToInvoice'] ?? false,
      convertedInvoiceId: map['convertedInvoiceId'],
      convertedAt: map['convertedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'quotationNumber': quotationNumber,
      'customerId': customerId,
      'customerName': customerName,
      'placeOfSupply': placeOfSupply,
      'quotationDate': quotationDate != null ? Timestamp.fromDate(quotationDate!) : null,
      'validUntilDate': validUntilDate != null ? Timestamp.fromDate(validUntilDate!) : null,
      'quotationType': quotationType,
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
      'convertedToInvoice': convertedToInvoice,
      'convertedInvoiceId': convertedInvoiceId,
      'convertedAt': convertedAt != null ? Timestamp.fromDate(convertedAt!) : null,
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

class QuotationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProfileService _profileService = ProfileService();

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference get _quotationsCollection =>
      _firestore.collection('quotations');

  // Extract initials from company name (e.g., "Triroop Pvt Ltd" -> "TPL")
  static String getCompanyInitials(String? companyName) {
    if (companyName == null || companyName.isEmpty) return 'QTN';

    final words = companyName.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase())
        .join();

    return initials.isNotEmpty ? initials : 'QTN';
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

  // Generate quotation number: PREFIX/QTN/YYYY-YY/NNN (e.g., TPL/QTN/2025-26/001)
  Future<String> generateQuotationNumber() async {
    if (_userId == null) return '';

    // Get company profile to extract initials
    final companyProfile = await _profileService.getCompanyProfile();
    final companyInitials = getCompanyInitials(companyProfile?.companyLegalName);

    final now = DateTime.now();
    // Financial year: April to March
    final year = now.month >= 4 ? now.year : now.year - 1;
    final nextYear = year + 1;
    final financialYear = '$year-${nextYear.toString().substring(2)}';
    final prefix = '$companyInitials/QTN/$financialYear/';

    try {
      // Get all quotations for this user in this financial year
      final startDate = DateTime(year, 4, 1);
      final endDate = DateTime(nextYear, 3, 31, 23, 59, 59);

      final snapshot = await _quotationsCollection
          .where('userId', isEqualTo: _userId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('createdAt', descending: true)
          .get();

      int nextNumber = 1;

      if (snapshot.docs.isNotEmpty) {
        // Find the highest sequence number from existing quotations
        // Match any prefix pattern ending with /QTN/YYYY-YY/
        final numberRegex = RegExp(r'/QTN/\d{4}-\d{2}/(\d+)$');
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final qNumber = data['quotationNumber'] as String?;
          if (qNumber != null) {
            final match = numberRegex.firstMatch(qNumber);
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
      debugPrint('Error generating quotation number: $e');
      // Fallback: count existing quotations + 1
      try {
        final countSnapshot = await _quotationsCollection
            .where('userId', isEqualTo: _userId)
            .get();
        final nextNumber = countSnapshot.docs.length + 1;
        return '$prefix${nextNumber.toString().padLeft(3, '0')}';
      } catch (_) {
        return '${prefix}001';
      }
    }
  }

  // Get all quotations for the current user
  Stream<List<Quotation>> getQuotations() {
    if (_userId == null) return Stream.value([]);

    return _quotationsCollection
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
        return Quotation.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // Get a single quotation by ID
  Future<Quotation?> getQuotationById(String quotationId) async {
    if (_userId == null) return null;

    try {
      final doc = await _quotationsCollection.doc(quotationId).get();
      if (doc.exists) {
        final quotation = Quotation.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        if (quotation.userId == _userId) {
          return quotation;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting quotation: $e');
      return null;
    }
  }

  // Add a new quotation
  Future<String?> addQuotation(Quotation quotation) async {
    if (_userId == null) return null;

    try {
      quotation.userId = _userId;
      quotation.quotationNumber = await generateQuotationNumber();

      final map = quotation.toMap();
      map['createdAt'] = FieldValue.serverTimestamp();

      final docRef = await _quotationsCollection.add(map);
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding quotation: $e');
      return null;
    }
  }

  // Update a quotation
  Future<bool> updateQuotation(Quotation quotation) async {
    if (_userId == null || quotation.id == null) return false;

    try {
      final existingQuotation = await getQuotationById(quotation.id!);
      if (existingQuotation == null || existingQuotation.userId != _userId) {
        return false;
      }

      await _quotationsCollection.doc(quotation.id).update(quotation.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating quotation: $e');
      return false;
    }
  }

  // Delete a quotation
  Future<bool> deleteQuotation(String quotationId) async {
    if (_userId == null) return false;

    try {
      final existingQuotation = await getQuotationById(quotationId);
      if (existingQuotation == null || existingQuotation.userId != _userId) {
        return false;
      }

      await _quotationsCollection.doc(quotationId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting quotation: $e');
      return false;
    }
  }

  // Mark quotation as converted to invoice
  Future<bool> markAsConvertedToInvoice(String quotationId, String invoiceId) async {
    if (_userId == null) return false;

    try {
      final existingQuotation = await getQuotationById(quotationId);
      if (existingQuotation == null || existingQuotation.userId != _userId) {
        return false;
      }

      await _quotationsCollection.doc(quotationId).update({
        'convertedToInvoice': true,
        'convertedInvoiceId': invoiceId,
        'convertedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error marking quotation as converted: $e');
      return false;
    }
  }
}
