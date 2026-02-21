import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Model for shared documents between Vyapar users
class SharedDocument {
  final String? id;
  final String documentType; // "quotation" or "invoice"
  final String documentId;
  final String? documentNumber;
  final String senderUserId;
  final String senderVyaparId;
  final String? senderCompanyName;
  final String receiverVyaparId;
  final String receiverUserId;
  final double grandTotal;
  final DateTime? documentDate;
  final DateTime? sharedAt;
  final Map<String, dynamic> documentSnapshot;
  final String status;

  // Bill tracking fields (for received invoices)
  final String? recordingStatus; // 'pending', 'recorded'
  final String? paymentStatus; // 'unpaid', 'partial', 'paid'
  final double amountPaid;
  final double amountDue;
  final DateTime? recordedAt;

  SharedDocument({
    this.id,
    required this.documentType,
    required this.documentId,
    this.documentNumber,
    required this.senderUserId,
    required this.senderVyaparId,
    this.senderCompanyName,
    required this.receiverVyaparId,
    required this.receiverUserId,
    required this.grandTotal,
    this.documentDate,
    this.sharedAt,
    required this.documentSnapshot,
    this.status = 'pending',
    this.recordingStatus,
    this.paymentStatus,
    this.amountPaid = 0,
    this.amountDue = 0,
    this.recordedAt,
  });

  /// Check if this invoice has been recorded as a bill
  bool get isRecorded => recordingStatus == 'recorded';

  /// Check if this bill is fully paid
  bool get isPaid => paymentStatus == 'paid';

  /// Check if this bill is partially paid
  bool get isPartiallyPaid => paymentStatus == 'partial';

  /// Get effective amount due (if not set, use grandTotal)
  double get effectiveAmountDue => amountDue > 0 ? amountDue : grandTotal;

  factory SharedDocument.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final grandTotal = (data['grandTotal'] ?? 0).toDouble();
    return SharedDocument(
      id: doc.id,
      documentType: data['documentType'] ?? '',
      documentId: data['documentId'] ?? '',
      documentNumber: data['documentNumber'],
      senderUserId: data['senderUserId'] ?? '',
      senderVyaparId: data['senderVyaparId'] ?? '',
      senderCompanyName: data['senderCompanyName'],
      receiverVyaparId: data['receiverVyaparId'] ?? '',
      receiverUserId: data['receiverUserId'] ?? '',
      grandTotal: grandTotal,
      documentDate: data['documentDate'] != null
          ? (data['documentDate'] as Timestamp).toDate()
          : null,
      sharedAt: data['sharedAt'] != null
          ? (data['sharedAt'] as Timestamp).toDate()
          : null,
      documentSnapshot: Map<String, dynamic>.from(data['documentSnapshot'] ?? {}),
      status: data['status'] ?? 'pending',
      recordingStatus: data['recordingStatus'],
      paymentStatus: data['paymentStatus'],
      amountPaid: (data['amountPaid'] ?? 0).toDouble(),
      amountDue: (data['amountDue'] ?? grandTotal).toDouble(),
      recordedAt: data['recordedAt'] != null
          ? (data['recordedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'documentType': documentType,
      'documentId': documentId,
      'documentNumber': documentNumber,
      'senderUserId': senderUserId,
      'senderVyaparId': senderVyaparId,
      'senderCompanyName': senderCompanyName,
      'receiverVyaparId': receiverVyaparId,
      'receiverUserId': receiverUserId,
      'grandTotal': grandTotal,
      'documentDate': documentDate,
      'sharedAt': FieldValue.serverTimestamp(),
      'documentSnapshot': documentSnapshot,
      'status': status,
      'recordingStatus': recordingStatus,
      'paymentStatus': paymentStatus,
      'amountPaid': amountPaid,
      'amountDue': amountDue,
      'recordedAt': recordedAt,
    };
  }
}

/// Service for B2B document sharing between Vyapar users
class SharedDocumentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _sharedDocumentsCollection =>
      _firestore.collection('sharedDocuments');

  String? get _userId => _auth.currentUser?.uid;

  /// Search for a user by their Vyapar ID
  /// Returns user info including company name, contact name, and userId
  Future<Map<String, dynamic>?> searchUserByVyaparId(String vyaparId) async {
    try {
      final normalizedId = vyaparId.trim().toUpperCase();

      if (normalizedId.isEmpty) return null;

      // Search in users collection
      final query = await _firestore
          .collection('users')
          .where('msmeId', isEqualTo: normalizedId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final userDoc = query.docs.first;
      final userData = userDoc.data();

      // Get company name from user document (profile data is stored in users collection)
      String companyName = userData['companyLegalName'] ?? userData['traderName'] ?? userData['name'] ?? 'Unknown';

      return {
        'userId': userDoc.id,
        'vyaparId': userData['msmeId'],
        'contactName': userData['name'] ?? 'Unknown',
        'companyName': companyName,
        'email': userData['email'],
      };
    } catch (e) {
      debugPrint('Error searching user by Vyapar ID: $e');
      return null;
    }
  }

  /// Get current user's sender info (Vyapar ID and company name)
  Future<Map<String, dynamic>> _getSenderInfo() async {
    final userId = _userId;
    if (userId == null) {
      return {'vyaparId': '', 'companyName': ''};
    }

    try {
      // Get user's Vyapar ID
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final vyaparId = userDoc.data()?['msmeId'] ?? '';
      final userName = userDoc.data()?['name'] ?? '';

      // Get company name from user document (profile data is stored in users collection)
      String companyName = userDoc.data()?['companyLegalName'] ?? userDoc.data()?['traderName'] ?? userName;

      return {
        'vyaparId': vyaparId,
        'companyName': companyName,
      };
    } catch (e) {
      debugPrint('Error getting sender info: $e');
      return {'vyaparId': '', 'companyName': ''};
    }
  }

  /// Share a document (quotation or invoice) to another Vyapar user
  Future<bool> shareDocument({
    required String documentType,
    required String documentId,
    required Map<String, dynamic> documentData,
    required String receiverVyaparId,
    required String receiverUserId,
  }) async {
    try {
      final currentUserId = _userId;
      if (currentUserId == null) {
        debugPrint('Cannot share document: User not logged in');
        return false;
      }

      // Prevent sending to self
      if (receiverUserId == currentUserId) {
        debugPrint('Cannot share document to yourself');
        return false;
      }

      final senderInfo = await _getSenderInfo();

      // Check if already shared to this user
      final existingShare = await _sharedDocumentsCollection
          .where('documentId', isEqualTo: documentId)
          .where('receiverUserId', isEqualTo: receiverUserId)
          .limit(1)
          .get();

      if (existingShare.docs.isNotEmpty) {
        debugPrint('Document already shared to this user');
        return false;
      }

      // Determine document number and date based on type
      String? documentNumber;
      DateTime? documentDate;

      if (documentType == 'quotation') {
        documentNumber = documentData['quotationNumber'];
        documentDate = documentData['quotationDate'] is Timestamp
            ? (documentData['quotationDate'] as Timestamp).toDate()
            : documentData['quotationDate'];
      } else if (documentType == 'invoice') {
        documentNumber = documentData['invoiceNumber'];
        documentDate = documentData['invoiceDate'] is Timestamp
            ? (documentData['invoiceDate'] as Timestamp).toDate()
            : documentData['invoiceDate'];
      } else if (documentType == 'creditNote') {
        documentNumber = documentData['creditNoteNumber'];
        documentDate = documentData['creditNoteDate'] is Timestamp
            ? (documentData['creditNoteDate'] as Timestamp).toDate()
            : documentData['creditNoteDate'];
      } else if (documentType == 'purchaseOrder') {
        documentNumber = documentData['poNumber'];
        documentDate = documentData['poDate'] is Timestamp
            ? (documentData['poDate'] as Timestamp).toDate()
            : documentData['poDate'];
      } else if (documentType == 'debitNote') {
        documentNumber = documentData['debitNoteNumber'];
        documentDate = documentData['debitNoteDate'] is Timestamp
            ? (documentData['debitNoteDate'] as Timestamp).toDate()
            : documentData['debitNoteDate'];
      }

      await _sharedDocumentsCollection.add({
        'documentType': documentType,
        'documentId': documentId,
        'documentNumber': documentNumber,
        'senderUserId': currentUserId,
        'senderVyaparId': senderInfo['vyaparId'],
        'senderCompanyName': senderInfo['companyName'],
        'receiverVyaparId': receiverVyaparId,
        'receiverUserId': receiverUserId,
        'grandTotal': documentData['grandTotal'] ?? 0,
        'documentDate': documentDate,
        'sharedAt': FieldValue.serverTimestamp(),
        'documentSnapshot': _sanitizeForFirestore(documentData),
        'status': 'pending',
      });

      debugPrint('Document shared successfully');
      return true;
    } catch (e) {
      debugPrint('Error sharing document: $e');
      return false;
    }
  }

  /// Sanitize data for Firestore (convert DateTime to Timestamp, etc.)
  Map<String, dynamic> _sanitizeForFirestore(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};

    for (final entry in data.entries) {
      final value = entry.value;
      if (value == null) {
        sanitized[entry.key] = null;
      } else if (value is DateTime) {
        sanitized[entry.key] = Timestamp.fromDate(value);
      } else if (value is Map) {
        sanitized[entry.key] = _sanitizeForFirestore(Map<String, dynamic>.from(value));
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

  /// Get stream of received quotations for current user
  Stream<List<SharedDocument>> getReceivedQuotations() {
    final userId = _userId;
    if (userId == null) {
      return Stream.value([]);
    }

    return _sharedDocumentsCollection
        .where('receiverUserId', isEqualTo: userId)
        .where('documentType', isEqualTo: 'quotation')
        .orderBy('sharedAt', descending: true)
        .snapshots()
        .handleError((error) {
          debugPrint('Error fetching received quotations: $error');
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => SharedDocument.fromFirestore(doc))
            .toList());
  }

  /// Get stream of received invoices for current user
  Stream<List<SharedDocument>> getReceivedInvoices() {
    final userId = _userId;
    if (userId == null) {
      return Stream.value([]);
    }

    return _sharedDocumentsCollection
        .where('receiverUserId', isEqualTo: userId)
        .where('documentType', isEqualTo: 'invoice')
        .orderBy('sharedAt', descending: true)
        .snapshots()
        .handleError((error) {
          debugPrint('Error fetching received invoices: $error');
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => SharedDocument.fromFirestore(doc))
            .toList());
  }

  /// Get stream of received credit notes for current user
  Stream<List<SharedDocument>> getReceivedCreditNotes() {
    final userId = _userId;
    if (userId == null) {
      return Stream.value([]);
    }

    return _sharedDocumentsCollection
        .where('receiverUserId', isEqualTo: userId)
        .where('documentType', isEqualTo: 'creditNote')
        .orderBy('sharedAt', descending: true)
        .snapshots()
        .handleError((error) {
          debugPrint('Error fetching received credit notes: $error');
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => SharedDocument.fromFirestore(doc))
            .toList());
  }

  /// Get stream of received debit notes for current user
  Stream<List<SharedDocument>> getReceivedDebitNotes() {
    final userId = _userId;
    if (userId == null) {
      return Stream.value([]);
    }

    return _sharedDocumentsCollection
        .where('receiverUserId', isEqualTo: userId)
        .where('documentType', isEqualTo: 'debitNote')
        .orderBy('sharedAt', descending: true)
        .snapshots()
        .handleError((error) {
          debugPrint('Error fetching received debit notes: $error');
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => SharedDocument.fromFirestore(doc))
            .toList());
  }

  /// Get a single shared document by ID
  Future<SharedDocument?> getSharedDocumentById(String id) async {
    try {
      final doc = await _sharedDocumentsCollection.doc(id).get();
      if (doc.exists) {
        return SharedDocument.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching shared document: $e');
      return null;
    }
  }

  /// Mark a shared document as viewed
  Future<void> markAsViewed(String sharedDocumentId) async {
    try {
      await _sharedDocumentsCollection.doc(sharedDocumentId).update({
        'status': 'viewed',
      });
    } catch (e) {
      debugPrint('Error marking document as viewed: $e');
    }
  }
}
