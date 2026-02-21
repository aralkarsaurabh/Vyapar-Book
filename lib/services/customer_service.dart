import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class Customer {
  String? id;
  String? userId; // Link to the user who created this customer

  // Basic Information
  String? customerName;
  String? customerType; // Individual or Business
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
  String? customerCategory;
  String? defaultPaymentTerms;

  DateTime? createdAt;
  DateTime? updatedAt;

  Customer({
    this.id,
    this.userId,
    this.customerName,
    this.customerType,
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
    this.customerCategory,
    this.defaultPaymentTerms,
    this.createdAt,
    this.updatedAt,
  });

  factory Customer.fromMap(Map<String, dynamic> map, String docId) {
    return Customer(
      id: docId,
      userId: map['userId'],
      customerName: map['customerName'],
      customerType: map['customerType'],
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
      customerCategory: map['customerCategory'],
      defaultPaymentTerms: map['defaultPaymentTerms'],
      createdAt: map['createdAt']?.toDate(),
      updatedAt: map['updatedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'customerName': customerName,
      'customerType': customerType,
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
      'customerCategory': customerCategory,
      'defaultPaymentTerms': defaultPaymentTerms,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class CustomerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference get _customersCollection =>
      _firestore.collection('customers');

  // Get all customers for the current user
  Stream<List<Customer>> getCustomers() {
    if (_userId == null) return Stream.value([]);

    return _customersCollection
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
        return Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // Get a single customer by ID
  Future<Customer?> getCustomerById(String customerId) async {
    if (_userId == null) return null;

    try {
      final doc = await _customersCollection.doc(customerId).get();
      if (doc.exists) {
        final customer = Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        // Verify the customer belongs to the current user
        if (customer.userId == _userId) {
          return customer;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting customer: $e');
      return null;
    }
  }

  // Add a new customer
  Future<String?> addCustomer(Customer customer) async {
    if (_userId == null) return null;

    try {
      customer.userId = _userId;
      final map = customer.toMap();
      map['createdAt'] = FieldValue.serverTimestamp();

      final docRef = await _customersCollection.add(map);
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding customer: $e');
      return null;
    }
  }

  // Update a customer
  Future<bool> updateCustomer(Customer customer) async {
    if (_userId == null || customer.id == null) return false;

    try {
      // Verify the customer belongs to the current user
      final existingCustomer = await getCustomerById(customer.id!);
      if (existingCustomer == null || existingCustomer.userId != _userId) {
        return false;
      }

      await _customersCollection.doc(customer.id).update(customer.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating customer: $e');
      return false;
    }
  }

  // Delete a customer
  Future<bool> deleteCustomer(String customerId) async {
    if (_userId == null) return false;

    try {
      // Verify the customer belongs to the current user
      final existingCustomer = await getCustomerById(customerId);
      if (existingCustomer == null || existingCustomer.userId != _userId) {
        return false;
      }

      await _customersCollection.doc(customerId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting customer: $e');
      return false;
    }
  }
}
