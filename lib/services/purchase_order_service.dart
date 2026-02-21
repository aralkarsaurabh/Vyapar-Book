import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'profile_service.dart';
import 'quotation_service.dart';

// Purchase Order Status
class POStatus {
  static const String draft = 'draft';
  static const String sent = 'sent';
  static const String acknowledged = 'acknowledged';
  static const String fulfilled = 'fulfilled';
  static const String cancelled = 'cancelled';
}

// Purchase Order model
class PurchaseOrder {
  String? id;
  String? userId;
  String? poNumber;

  // PO Details
  String? vendorId;
  String? vendorName;
  String? vendorGst;
  String? placeOfSupply;
  DateTime? poDate;
  DateTime? expectedDeliveryDate;
  String? poType; // GST or Non-GST

  // Reference (if created from received quotation)
  String? againstQuotationId; // Shared document ID
  String? againstQuotationNumber;

  // Line Items (reuse from quotation)
  List<LineItem> lineItems;

  // Totals
  double subtotal;
  bool hasDiscount;
  String? discountType;
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
  String? deliveryAddress;
  String? shippingMethod;

  // Company Details (saved at creation time)
  Map<String, dynamic>? companyDetails;
  Map<String, dynamic>? bankDetails;
  Map<String, dynamic>? userDetails;
  Map<String, dynamic>? vendorDetails;

  // Status
  String status;

  // B2B Sharing
  bool sentToVendor;
  DateTime? sentAt;

  DateTime? createdAt;
  DateTime? updatedAt;

  PurchaseOrder({
    this.id,
    this.userId,
    this.poNumber,
    this.vendorId,
    this.vendorName,
    this.vendorGst,
    this.placeOfSupply,
    this.poDate,
    this.expectedDeliveryDate,
    this.poType,
    this.againstQuotationId,
    this.againstQuotationNumber,
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
    this.deliveryAddress,
    this.shippingMethod,
    this.companyDetails,
    this.bankDetails,
    this.userDetails,
    this.vendorDetails,
    this.status = POStatus.draft,
    this.sentToVendor = false,
    this.sentAt,
    this.createdAt,
    this.updatedAt,
  }) : lineItems = lineItems ?? [];

  factory PurchaseOrder.fromMap(Map<String, dynamic> map, String docId) {
    return PurchaseOrder(
      id: docId,
      userId: map['userId'],
      poNumber: map['poNumber'],
      vendorId: map['vendorId'],
      vendorName: map['vendorName'],
      vendorGst: map['vendorGst'],
      placeOfSupply: map['placeOfSupply'],
      poDate: map['poDate']?.toDate(),
      expectedDeliveryDate: map['expectedDeliveryDate']?.toDate(),
      poType: map['poType'],
      againstQuotationId: map['againstQuotationId'],
      againstQuotationNumber: map['againstQuotationNumber'],
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
      deliveryAddress: map['deliveryAddress'],
      shippingMethod: map['shippingMethod'],
      companyDetails: map['companyDetails'] as Map<String, dynamic>?,
      bankDetails: map['bankDetails'] as Map<String, dynamic>?,
      userDetails: map['userDetails'] as Map<String, dynamic>?,
      vendorDetails: map['vendorDetails'] as Map<String, dynamic>?,
      status: map['status'] ?? POStatus.draft,
      sentToVendor: map['sentToVendor'] ?? false,
      sentAt: map['sentAt']?.toDate(),
      createdAt: map['createdAt']?.toDate(),
      updatedAt: map['updatedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'poNumber': poNumber,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'vendorGst': vendorGst,
      'placeOfSupply': placeOfSupply,
      'poDate': poDate != null ? Timestamp.fromDate(poDate!) : null,
      'expectedDeliveryDate': expectedDeliveryDate != null
          ? Timestamp.fromDate(expectedDeliveryDate!)
          : null,
      'poType': poType,
      'againstQuotationId': againstQuotationId,
      'againstQuotationNumber': againstQuotationNumber,
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
      'deliveryAddress': deliveryAddress,
      'shippingMethod': shippingMethod,
      'companyDetails': companyDetails,
      'bankDetails': bankDetails,
      'userDetails': userDetails,
      'vendorDetails': vendorDetails,
      'status': status,
      'sentToVendor': sentToVendor,
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Check if transaction is intra-state (same state = CGST+SGST) or inter-state (IGST)
  bool get isIntraState {
    final companyState = companyDetails?['state'] as String?;
    final vendorState = vendorDetails?['state'] as String?;
    return companyState != null &&
        vendorState != null &&
        companyState == vendorState;
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

  // Get status display text
  String get statusDisplay {
    switch (status) {
      case POStatus.draft:
        return 'Draft';
      case POStatus.sent:
        return 'Sent';
      case POStatus.acknowledged:
        return 'Acknowledged';
      case POStatus.fulfilled:
        return 'Fulfilled';
      case POStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }
}

class PurchaseOrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProfileService _profileService = ProfileService();

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference get _purchaseOrdersCollection =>
      _firestore.collection('purchaseOrders');

  CollectionReference get _sharedDocumentsCollection =>
      _firestore.collection('sharedDocuments');

  // Generate PO number: PREFIX/PO/YYYY-YY/NNN
  Future<String> generatePONumber() async {
    if (_userId == null) return '';

    final companyProfile = await _profileService.getCompanyProfile();
    final companyInitials =
        QuotationService.getCompanyInitials(companyProfile?.companyLegalName);

    final now = DateTime.now();
    final year = now.month >= 4 ? now.year : now.year - 1;
    final nextYear = year + 1;
    final financialYear = '$year-${nextYear.toString().substring(2)}';
    final prefix = '$companyInitials/PO/$financialYear/';

    try {
      final startDate = DateTime(year, 4, 1);
      final endDate = DateTime(nextYear, 3, 31, 23, 59, 59);

      final snapshot = await _purchaseOrdersCollection
          .where('userId', isEqualTo: _userId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('createdAt', descending: true)
          .get();

      int nextNumber = 1;

      if (snapshot.docs.isNotEmpty) {
        final numberRegex = RegExp(r'/PO/\d{4}-\d{2}/(\d+)$');
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final poNum = data['poNumber'] as String?;
          if (poNum != null) {
            final match = numberRegex.firstMatch(poNum);
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
      debugPrint('Error generating PO number: $e');
      try {
        final countSnapshot = await _purchaseOrdersCollection
            .where('userId', isEqualTo: _userId)
            .get();
        final nextNumber = countSnapshot.docs.length + 1;
        return '$prefix${nextNumber.toString().padLeft(3, '0')}';
      } catch (_) {
        return '${prefix}001';
      }
    }
  }

  // Get all purchase orders for the current user
  Stream<List<PurchaseOrder>> getPurchaseOrders() {
    if (_userId == null) return Stream.value([]);

    return _purchaseOrdersCollection
        .where('userId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
      debugPrint('===========================================');
      debugPrint('FIRESTORE ERROR: $error');
      if (error.toString().contains('index')) {
        debugPrint('');
        debugPrint('Please create the required index.');
      }
      debugPrint('===========================================');
    }).map((snapshot) {
      return snapshot.docs.map((doc) {
        return PurchaseOrder.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // Get a single purchase order by ID
  Future<PurchaseOrder?> getPurchaseOrderById(String poId) async {
    if (_userId == null) return null;

    try {
      final doc = await _purchaseOrdersCollection.doc(poId).get();
      if (doc.exists) {
        final po =
            PurchaseOrder.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        if (po.userId == _userId) {
          return po;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting purchase order: $e');
      return null;
    }
  }

  // Add a new purchase order
  Future<String?> addPurchaseOrder(PurchaseOrder po) async {
    if (_userId == null) return null;

    try {
      po.userId = _userId;
      po.poNumber = await generatePONumber();

      final map = po.toMap();
      map['createdAt'] = FieldValue.serverTimestamp();

      final docRef = await _purchaseOrdersCollection.add(map);
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding purchase order: $e');
      return null;
    }
  }

  // Update a purchase order
  Future<bool> updatePurchaseOrder(PurchaseOrder po) async {
    if (_userId == null || po.id == null) return false;

    try {
      final existingPO = await getPurchaseOrderById(po.id!);
      if (existingPO == null || existingPO.userId != _userId) {
        return false;
      }

      await _purchaseOrdersCollection.doc(po.id).update(po.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating purchase order: $e');
      return false;
    }
  }

  // Delete a purchase order
  Future<bool> deletePurchaseOrder(String poId) async {
    if (_userId == null) return false;

    try {
      final existingPO = await getPurchaseOrderById(poId);
      if (existingPO == null || existingPO.userId != _userId) {
        return false;
      }

      await _purchaseOrdersCollection.doc(poId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting purchase order: $e');
      return false;
    }
  }

  // Send PO to vendor via Vyapar ID
  Future<bool> sendToVendor(String poId) async {
    if (_userId == null) return false;

    try {
      final po = await getPurchaseOrderById(poId);
      if (po == null) return false;

      // Get vendor's linked Vyapar ID and user ID
      final vendorLinkedUserId = po.vendorDetails?['linkedUserId'];
      final vendorLinkedVyaparId = po.vendorDetails?['linkedVyaparId'];

      if (vendorLinkedUserId == null || vendorLinkedVyaparId == null) {
        debugPrint('Vendor is not linked via Vyapar ID');
        return false;
      }

      // Get sender info
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      final senderVyaparId = userDoc.data()?['msmeId'] ?? '';
      final senderName = userDoc.data()?['name'] ?? '';

      String senderCompanyName = userDoc.data()?['companyLegalName'] ?? userDoc.data()?['traderName'] ?? senderName;

      // Check if already shared
      final existingShare = await _sharedDocumentsCollection
          .where('documentId', isEqualTo: poId)
          .where('receiverUserId', isEqualTo: vendorLinkedUserId)
          .limit(1)
          .get();

      if (existingShare.docs.isNotEmpty) {
        debugPrint('PO already sent to this vendor');
        return false;
      }

      // Create shared document
      await _sharedDocumentsCollection.add({
        'documentType': 'purchase_order',
        'documentId': poId,
        'documentNumber': po.poNumber,
        'senderUserId': _userId,
        'senderVyaparId': senderVyaparId,
        'senderCompanyName': senderCompanyName,
        'receiverVyaparId': vendorLinkedVyaparId,
        'receiverUserId': vendorLinkedUserId,
        'grandTotal': po.grandTotal,
        'documentDate': po.poDate,
        'sharedAt': FieldValue.serverTimestamp(),
        'documentSnapshot': _sanitizeForFirestore(po.toMap()),
        'status': 'pending',
      });

      // Update PO status
      await _purchaseOrdersCollection.doc(poId).update({
        'sentToVendor': true,
        'sentAt': FieldValue.serverTimestamp(),
        'status': POStatus.sent,
      });

      return true;
    } catch (e) {
      debugPrint('Error sending PO to vendor: $e');
      return false;
    }
  }

  // Get received purchase orders (POs sent to current user by their customers)
  Stream<List<Map<String, dynamic>>> getReceivedPurchaseOrders() {
    if (_userId == null) return Stream.value([]);

    return _sharedDocumentsCollection
        .where('receiverUserId', isEqualTo: _userId)
        .where('documentType', isEqualTo: 'purchase_order')
        .orderBy('sharedAt', descending: true)
        .snapshots()
        .handleError((error) {
      debugPrint('Error fetching received POs: $error');
    }).map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    });
  }

  // Get a received PO by shared document ID
  Future<Map<String, dynamic>?> getReceivedPOById(String sharedDocId) async {
    try {
      final doc = await _sharedDocumentsCollection.doc(sharedDocId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['documentType'] == 'purchase_order') {
          return {
            'id': doc.id,
            ...data,
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching received PO: $e');
      return null;
    }
  }

  Map<String, dynamic> _sanitizeForFirestore(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};

    for (final entry in data.entries) {
      final value = entry.value;
      if (value == null) {
        sanitized[entry.key] = null;
      } else if (value is DateTime) {
        sanitized[entry.key] = Timestamp.fromDate(value);
      } else if (value is Map) {
        sanitized[entry.key] =
            _sanitizeForFirestore(Map<String, dynamic>.from(value));
      } else if (value is List) {
        sanitized[entry.key] = value.map((item) {
          if (item is Map) {
            return _sanitizeForFirestore(Map<String, dynamic>.from(item));
          } else if (item is DateTime) {
            return Timestamp.fromDate(item);
          }
          return item;
        }).toList();
      } else {
        sanitized[entry.key] = value;
      }
    }

    return sanitized;
  }

  // Mark received quotation as converted to PO
  Future<bool> markQuotationConvertedToPO(
      String sharedDocId, String poId) async {
    try {
      await _sharedDocumentsCollection.doc(sharedDocId).update({
        'convertedToPO': true,
        'convertedPOId': poId,
        'convertedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error marking quotation as converted: $e');
      return false;
    }
  }
}
