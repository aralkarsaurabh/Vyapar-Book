import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class Vendor {
  String? id;
  String? userId; // Link to the user who created this vendor

  // Basic Information
  String? vendorName;
  String? vendorType; // Individual or Business
  String? contactPersonName;
  String? gstNumber;
  String? panNumber;

  // Contact Information
  String? email;
  String? phoneNumber;

  // Address
  String? addressLine1;
  String? addressLine2;
  String? city;
  String? state;
  String? pinCode;
  String? country;

  // Business Details
  String? gstRegistrationStatus;
  String? placeOfSupplyState;
  String? legalNameAsPerGst;
  String? traderName;
  String? vendorCategory;
  String? defaultPaymentTerms;

  // Vyapar Link (if added via Vyapar ID)
  String? linkedVyaparId; // e.g., "ABC1234"
  String? linkedUserId; // Firebase UID of vendor
  DateTime? linkedAt; // When was link created

  // Outstanding balance (computed from accounting - future use)
  double? outstandingBalance;

  DateTime? createdAt;
  DateTime? updatedAt;

  Vendor({
    this.id,
    this.userId,
    this.vendorName,
    this.vendorType,
    this.contactPersonName,
    this.gstNumber,
    this.panNumber,
    this.email,
    this.phoneNumber,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.pinCode,
    this.country,
    this.gstRegistrationStatus,
    this.placeOfSupplyState,
    this.legalNameAsPerGst,
    this.traderName,
    this.vendorCategory,
    this.defaultPaymentTerms,
    this.linkedVyaparId,
    this.linkedUserId,
    this.linkedAt,
    this.outstandingBalance,
    this.createdAt,
    this.updatedAt,
  });

  factory Vendor.fromMap(Map<String, dynamic> map, String docId) {
    return Vendor(
      id: docId,
      userId: map['userId'],
      vendorName: map['vendorName'],
      vendorType: map['vendorType'],
      contactPersonName: map['contactPersonName'],
      gstNumber: map['gstNumber'],
      panNumber: map['panNumber'],
      email: map['email'],
      phoneNumber: map['phoneNumber'],
      addressLine1: map['addressLine1'],
      addressLine2: map['addressLine2'],
      city: map['city'],
      state: map['state'],
      pinCode: map['pinCode'],
      country: map['country'],
      gstRegistrationStatus: map['gstRegistrationStatus'],
      placeOfSupplyState: map['placeOfSupplyState'],
      legalNameAsPerGst: map['legalNameAsPerGst'],
      traderName: map['traderName'],
      vendorCategory: map['vendorCategory'],
      defaultPaymentTerms: map['defaultPaymentTerms'],
      linkedVyaparId: map['linkedVyaparId'],
      linkedUserId: map['linkedUserId'],
      linkedAt: map['linkedAt']?.toDate(),
      outstandingBalance: (map['outstandingBalance'] ?? 0).toDouble(),
      createdAt: map['createdAt']?.toDate(),
      updatedAt: map['updatedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'vendorName': vendorName,
      'vendorType': vendorType,
      'contactPersonName': contactPersonName,
      'gstNumber': gstNumber,
      'panNumber': panNumber,
      'email': email,
      'phoneNumber': phoneNumber,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'state': state,
      'pinCode': pinCode,
      'country': country,
      'gstRegistrationStatus': gstRegistrationStatus,
      'placeOfSupplyState': placeOfSupplyState,
      'legalNameAsPerGst': legalNameAsPerGst,
      'traderName': traderName,
      'vendorCategory': vendorCategory,
      'defaultPaymentTerms': defaultPaymentTerms,
      'linkedVyaparId': linkedVyaparId,
      'linkedUserId': linkedUserId,
      'linkedAt': linkedAt != null ? Timestamp.fromDate(linkedAt!) : null,
      'outstandingBalance': outstandingBalance ?? 0,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class VendorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference get _vendorsCollection =>
      _firestore.collection('vendors');

  // Get all vendors for the current user
  Stream<List<Vendor>> getVendors() {
    if (_userId == null) return Stream.value([]);

    return _vendorsCollection
        .where('userId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
      debugPrint('===========================================');
      debugPrint('FIRESTORE ERROR: $error');
      if (error.toString().contains('index')) {
        debugPrint('');
        debugPrint('Please create the required index by visiting the URL above.');
        debugPrint('Or visit Firebase Console > Firestore > Indexes');
      }
      debugPrint('===========================================');
    }).map((snapshot) {
      return snapshot.docs.map((doc) {
        return Vendor.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // Get all vendors as a one-time Future (for non-streaming contexts)
  Future<List<Vendor>> getVendorsOnce() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _vendorsCollection
          .where('userId', isEqualTo: _userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return Vendor.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Error getting vendors once: $e');
      return [];
    }
  }

  // Get a single vendor by ID
  Future<Vendor?> getVendorById(String vendorId) async {
    if (_userId == null) return null;

    try {
      final doc = await _vendorsCollection.doc(vendorId).get();
      if (doc.exists) {
        final vendor = Vendor.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        // Verify the vendor belongs to the current user
        if (vendor.userId == _userId) {
          return vendor;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting vendor: $e');
      return null;
    }
  }

  // Check if vendor with Vyapar ID already exists
  Future<bool> vendorExistsWithVyaparId(String vyaparId) async {
    if (_userId == null) return false;

    try {
      final query = await _vendorsCollection
          .where('userId', isEqualTo: _userId)
          .where('linkedVyaparId', isEqualTo: vyaparId.toUpperCase())
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking vendor: $e');
      return false;
    }
  }

  // Search user by Vyapar ID (for adding as vendor)
  Future<Map<String, dynamic>?> searchUserByVyaparId(String vyaparId) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('msmeId', isEqualTo: vyaparId.toUpperCase())
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final doc = query.docs.first;
      final data = doc.data();

      // Can't add yourself as vendor
      if (doc.id == _userId) {
        return {'error': 'self', 'message': 'You cannot add yourself as a vendor'};
      }

      // Profile data is stored directly in the users document
      // No need for a second query - 'data' already contains all profile fields
      return {
        'userId': doc.id,
        'vyaparId': data['msmeId'],
        'contactName': data['authorizedContactName'] ?? data['name'],
        'email': data['emailAddress'] ?? data['email'],
        'companyName': data['companyLegalName'] ?? data['traderName'] ?? data['name'],
        'gstNumber': data['gstin'],
        'panNumber': data['pan'],
        'phone': data['phoneNumber'] ?? data['phone'],
        'addressLine1': data['addressLine1'],
        'addressLine2': data['addressLine2'],
        'city': data['city'],
        'state': data['state'],
        'pinCode': data['pinCode'],
        'country': data['country'] ?? 'India',
        // Business Details
        'gstRegistrationStatus': data['gstRegistrationStatus'],
        'legalNameAsPerGst': data['companyLegalName'],
        'traderName': data['traderName'],
        'placeOfSupplyState': data['state'], // Default to company state
      };
    } catch (e) {
      debugPrint('Error searching user by Vyapar ID: $e');
      return null;
    }
  }

  // Add a new vendor
  Future<String?> addVendor(Vendor vendor) async {
    if (_userId == null) return null;

    try {
      vendor.userId = _userId;
      final map = vendor.toMap();
      map['createdAt'] = FieldValue.serverTimestamp();

      final docRef = await _vendorsCollection.add(map);
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding vendor: $e');
      return null;
    }
  }

  // Add vendor from Vyapar ID lookup
  Future<String?> addVendorFromVyaparId(Map<String, dynamic> userData) async {
    if (_userId == null) return null;

    try {
      // Check if already exists
      final exists = await vendorExistsWithVyaparId(userData['vyaparId']);
      if (exists) {
        return null; // Vendor already exists
      }

      final vendor = Vendor(
        userId: _userId,
        vendorName: userData['companyName'],
        vendorType: 'Business',
        contactPersonName: userData['contactName'],
        gstNumber: userData['gstNumber'],
        panNumber: userData['panNumber'],
        email: userData['email'],
        phoneNumber: userData['phone'],
        addressLine1: userData['addressLine1'],
        addressLine2: userData['addressLine2'],
        city: userData['city'],
        state: userData['state'],
        pinCode: userData['pinCode'],
        country: userData['country'] ?? 'India',
        // Business Details
        gstRegistrationStatus: userData['gstRegistrationStatus'],
        placeOfSupplyState: userData['placeOfSupplyState'],
        legalNameAsPerGst: userData['legalNameAsPerGst'],
        traderName: userData['traderName'],
        // Vyapar Link
        linkedVyaparId: userData['vyaparId'],
        linkedUserId: userData['userId'],
        linkedAt: DateTime.now(),
        outstandingBalance: 0,
      );

      final map = vendor.toMap();
      map['createdAt'] = FieldValue.serverTimestamp();

      final docRef = await _vendorsCollection.add(map);
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding vendor from Vyapar ID: $e');
      return null;
    }
  }

  // Update a vendor
  Future<bool> updateVendor(Vendor vendor) async {
    if (_userId == null || vendor.id == null) return false;

    try {
      // Verify the vendor belongs to the current user
      final existingVendor = await getVendorById(vendor.id!);
      if (existingVendor == null || existingVendor.userId != _userId) {
        return false;
      }

      await _vendorsCollection.doc(vendor.id).update(vendor.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating vendor: $e');
      return false;
    }
  }

  // Delete a vendor
  Future<bool> deleteVendor(String vendorId) async {
    if (_userId == null) return false;

    try {
      // Verify the vendor belongs to the current user
      final existingVendor = await getVendorById(vendorId);
      if (existingVendor == null || existingVendor.userId != _userId) {
        return false;
      }

      await _vendorsCollection.doc(vendorId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting vendor: $e');
      return false;
    }
  }

  // Refresh vendor data from Vyapar ID (if linked)
  Future<bool> refreshVendorFromVyaparId(String vendorId) async {
    if (_userId == null) return false;

    try {
      final vendor = await getVendorById(vendorId);
      if (vendor == null || vendor.linkedVyaparId == null) {
        return false;
      }

      final userData = await searchUserByVyaparId(vendor.linkedVyaparId!);
      if (userData == null || userData.containsKey('error')) {
        return false;
      }

      // Update vendor with fresh data
      vendor.vendorName = userData['companyName'];
      vendor.contactPersonName = userData['contactName'];
      vendor.gstNumber = userData['gstNumber'];
      vendor.panNumber = userData['panNumber'];
      vendor.email = userData['email'];
      vendor.phoneNumber = userData['phone'];
      vendor.addressLine1 = userData['addressLine1'];
      vendor.addressLine2 = userData['addressLine2'];
      vendor.city = userData['city'];
      vendor.state = userData['state'];
      vendor.pinCode = userData['pinCode'];
      vendor.country = userData['country'] ?? 'India';
      // Business Details
      vendor.gstRegistrationStatus = userData['gstRegistrationStatus'];
      vendor.placeOfSupplyState = userData['placeOfSupplyState'];
      vendor.legalNameAsPerGst = userData['legalNameAsPerGst'];
      vendor.traderName = userData['traderName'];

      return await updateVendor(vendor);
    } catch (e) {
      debugPrint('Error refreshing vendor: $e');
      return false;
    }
  }

  // ==================== OUTSTANDING BALANCE TRACKING ====================

  /// Update vendor outstanding balance directly
  /// Positive amount increases balance (recording a bill)
  /// Negative amount decreases balance (making a payment)
  Future<bool> updateOutstandingBalance(String vendorId, double amount) async {
    if (_userId == null) return false;

    try {
      // Verify the vendor belongs to the current user
      final existingVendor = await getVendorById(vendorId);
      if (existingVendor == null || existingVendor.userId != _userId) {
        return false;
      }

      await _vendorsCollection.doc(vendorId).update({
        'outstandingBalance': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating vendor outstanding balance: $e');
      return false;
    }
  }

  /// Get total outstanding balance across all vendors
  Future<double> getTotalOutstandingPayables() async {
    if (_userId == null) return 0;

    try {
      final snapshot = await _vendorsCollection
          .where('userId', isEqualTo: _userId)
          .get();

      double total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total += (data['outstandingBalance'] ?? 0).toDouble();
      }
      return total;
    } catch (e) {
      debugPrint('Error getting total outstanding payables: $e');
      return 0;
    }
  }

  /// Get vendors with outstanding balance (payables)
  Future<List<Vendor>> getVendorsWithOutstanding() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _vendorsCollection
          .where('userId', isEqualTo: _userId)
          .where('outstandingBalance', isGreaterThan: 0)
          .orderBy('outstandingBalance', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return Vendor.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Error getting vendors with outstanding: $e');
      return [];
    }
  }

  /// Get vendor by linked Vyapar ID
  Future<Vendor?> getVendorByVyaparId(String vyaparId) async {
    if (_userId == null) return null;

    try {
      final query = await _vendorsCollection
          .where('userId', isEqualTo: _userId)
          .where('linkedVyaparId', isEqualTo: vyaparId.toUpperCase())
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      return Vendor.fromMap(
          query.docs.first.data() as Map<String, dynamic>, query.docs.first.id);
    } catch (e) {
      debugPrint('Error getting vendor by Vyapar ID: $e');
      return null;
    }
  }
}
