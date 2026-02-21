import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'accounting_service.dart';

class CompanyProfile {
  // Company Logo (base64 string)
  String? logoBase64;

  // Legal Entity Details
  String? companyLegalName;
  String? traderName;
  String? constitutionType;
  String? cin;
  String? pan;

  // GST and Tax Identity
  String? gstRegistrationStatus;
  String? gstin;
  String? gstRegistrationDate;
  String? gstStateCode;
  String? defaultGstRate;
  String? reverseChargeApplicable;

  // Registered Address
  String? addressLine1;
  String? addressLine2;
  String? city;
  String? district;
  String? state;
  String? pinCode;
  String? country;

  // Contact Details
  String? authorizedContactName;
  String? phoneNumber;
  String? alternatePhoneNumber;
  String? emailAddress;
  String? alternateEmailAddress;
  String? website;

  // Banking Details
  String? bankAccountHolderName;
  String? bankName;
  String? accountNumber;
  String? ifscCode;
  String? branchName;
  String? accountType;

  CompanyProfile({
    this.logoBase64,
    this.companyLegalName,
    this.traderName,
    this.constitutionType,
    this.cin,
    this.pan,
    this.gstRegistrationStatus,
    this.gstin,
    this.gstRegistrationDate,
    this.gstStateCode,
    this.defaultGstRate,
    this.reverseChargeApplicable,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.district,
    this.state,
    this.pinCode,
    this.country,
    this.authorizedContactName,
    this.phoneNumber,
    this.alternatePhoneNumber,
    this.emailAddress,
    this.alternateEmailAddress,
    this.website,
    this.bankAccountHolderName,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    this.branchName,
    this.accountType,
  });

  factory CompanyProfile.fromMap(Map<String, dynamic> map) {
    return CompanyProfile(
      logoBase64: map['logoBase64'],
      companyLegalName: map['companyLegalName'],
      traderName: map['traderName'],
      constitutionType: map['constitutionType'],
      cin: map['cin'],
      pan: map['pan'],
      gstRegistrationStatus: map['gstRegistrationStatus'],
      gstin: map['gstin'],
      gstRegistrationDate: map['gstRegistrationDate'],
      gstStateCode: map['gstStateCode'],
      defaultGstRate: map['defaultGstRate'],
      reverseChargeApplicable: map['reverseChargeApplicable'],
      addressLine1: map['addressLine1'],
      addressLine2: map['addressLine2'],
      city: map['city'],
      district: map['district'],
      state: map['state'],
      pinCode: map['pinCode'],
      country: map['country'],
      authorizedContactName: map['authorizedContactName'],
      phoneNumber: map['phoneNumber'],
      alternatePhoneNumber: map['alternatePhoneNumber'],
      emailAddress: map['emailAddress'],
      alternateEmailAddress: map['alternateEmailAddress'],
      website: map['website'],
      bankAccountHolderName: map['bankAccountHolderName'],
      bankName: map['bankName'],
      accountNumber: map['accountNumber'],
      ifscCode: map['ifscCode'],
      branchName: map['branchName'],
      accountType: map['accountType'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'logoBase64': logoBase64,
      'companyLegalName': companyLegalName,
      'traderName': traderName,
      'constitutionType': constitutionType,
      'cin': cin,
      'pan': pan,
      'gstRegistrationStatus': gstRegistrationStatus,
      'gstin': gstin,
      'gstRegistrationDate': gstRegistrationDate,
      'gstStateCode': gstStateCode,
      'defaultGstRate': defaultGstRate,
      'reverseChargeApplicable': reverseChargeApplicable,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'district': district,
      'state': state,
      'pinCode': pinCode,
      'country': country,
      'authorizedContactName': authorizedContactName,
      'phoneNumber': phoneNumber,
      'alternatePhoneNumber': alternatePhoneNumber,
      'emailAddress': emailAddress,
      'alternateEmailAddress': alternateEmailAddress,
      'website': website,
      'bankAccountHolderName': bankAccountHolderName,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'ifscCode': ifscCode,
      'branchName': branchName,
      'accountType': accountType,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // Convert image bytes to base64 string
  String imageToBase64(Uint8List imageBytes) {
    return base64Encode(imageBytes);
  }

  // Convert base64 string to image bytes
  Uint8List? base64ToImage(String? base64String) {
    if (base64String == null || base64String.isEmpty) return null;
    try {
      return base64Decode(base64String);
    } catch (e) {
      debugPrint('Error decoding base64 image: $e');
      return null;
    }
  }

  // Get company profile from user document
  Future<CompanyProfile?> getCompanyProfile() async {
    if (_userId == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .get();

      if (doc.exists && doc.data() != null) {
        return CompanyProfile.fromMap(doc.data()!);
      }
      return CompanyProfile();
    } catch (e) {
      debugPrint('Error getting company profile: $e');
      return null;
    }
  }

  // Save company profile to user document
  Future<bool> saveCompanyProfile(CompanyProfile profile) async {
    if (_userId == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .set(profile.toMap(), SetOptions(merge: true));

      // Sync bank accounts to chart of accounts
      try {
        final accountingService = AccountingService();
        await accountingService.syncBankAccountsFromProfile(profile);
      } catch (e) {
        debugPrint('Bank account sync error: $e');
        // Don't fail profile save if bank sync fails
      }

      return true;
    } catch (e) {
      debugPrint('Error saving company profile: $e');
      return false;
    }
  }
}
