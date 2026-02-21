import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'accounting_service.dart';

enum UserRole { admin, manager, employee }

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static bool _persistenceInitialized = false;

  // Initialize persistence for web platform
  static Future<void> initializePersistence() async {
    if (_persistenceInitialized) return;

    if (kIsWeb) {
      try {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
        debugPrint('Firebase Auth persistence set to LOCAL');
      } catch (e) {
        debugPrint('Error setting persistence: $e');
      }
    }
    _persistenceInitialized = true;
  }

  static const String _keyRememberMe = 'remember_me';
  static const String _keySavedEmail = 'saved_email';
  static const String _keySavedPassword = 'saved_password';

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if user is logged in
  bool isLoggedIn() {
    return _auth.currentUser != null;
  }

  // ============================================================
  // SHARED PREFERENCES HELPERS
  // ============================================================

  Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  Future<bool> getRememberMe() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyRememberMe) ?? false;
  }

  Future<Map<String, String?>> getSavedCredentials() async {
    final prefs = await _prefs;
    final rememberMe = prefs.getBool(_keyRememberMe) ?? false;
    if (rememberMe) {
      return {
        'email': prefs.getString(_keySavedEmail),
        'password': prefs.getString(_keySavedPassword),
      };
    }
    return {'email': null, 'password': null};
  }

  Future<void> _saveCredentials(String email, String password, bool rememberMe) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyRememberMe, rememberMe);
    if (rememberMe) {
      await prefs.setString(_keySavedEmail, email);
      await prefs.setString(_keySavedPassword, password);
    } else {
      await prefs.remove(_keySavedEmail);
      await prefs.remove(_keySavedPassword);
    }
  }

  // ============================================================
  // EMAIL/PASSWORD SIGN UP
  // ============================================================

  Future<AuthResult> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return AuthResult.failure('Failed to create account');
      }

      // Update display name
      await user.updateDisplayName(name);

      // Save user data to Firestore
      await _saveUserToFirestore(
        uid: user.uid,
        name: name,
        email: email.trim(),
        phone: phone.trim(),
      );

      // Sign out after registration (user needs to sign in)
      await _auth.signOut();

      return AuthResult.success(null, message: 'Account created successfully! Please sign in.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e.code));
    } catch (e) {
      debugPrint('Sign up error: $e');
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  // ============================================================
  // EMAIL/PASSWORD SIGN IN
  // ============================================================

  Future<AuthResult> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return AuthResult.failure('Failed to sign in');
      }

      // Get user data from Firestore
      final userData = await _getUserFromFirestore(user.uid);
      final name = userData['name'] ?? user.displayName ?? 'User';
      final role = userData['role'] ?? 'employee';

      // Migration: Generate Vyapar ID for existing users who don't have one
      if (userData['msmeId'] == null || userData['msmeId']!.isEmpty) {
        await _migrateMsmeId(user.uid);
      }

      // Initialize chart of accounts if not already done
      try {
        final accountingService = AccountingService();
        await accountingService.initializeAccounts();

        // Migrate existing invoices to accounting system
        // This creates journal entries for invoices that don't have them
        await accountingService.migrateExistingInvoices();
      } catch (e) {
        debugPrint('Account initialization/migration error: $e');
        // Don't fail sign in if account initialization fails
      }

      // Update last login timestamp
      await _updateLastLogin(user.uid);

      // Save credentials if remember me is checked
      await _saveCredentials(email, password, rememberMe);

      return AuthResult.success(
        user,
        message: 'Welcome back, $name!',
        role: role,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e.code));
    } catch (e) {
      debugPrint('Sign in error: $e');
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  // ============================================================
  // SIGN OUT
  // ============================================================

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  // ============================================================
  // PASSWORD RESET
  // ============================================================

  Future<AuthResult> forgotPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(null, message: 'Password reset link has been sent to your email.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e.code));
    } catch (e) {
      debugPrint('Password reset error: $e');
      return AuthResult.failure('Failed to send reset email');
    }
  }

  // ============================================================
  // GET CURRENT USER INFO
  // ============================================================

  Future<Map<String, String?>> getCurrentUserInfo() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'email': null, 'name': null, 'phone': null, 'role': null, 'msmeId': null};
    }

    final userData = await _getUserFromFirestore(user.uid);
    return {
      'email': user.email,
      'name': userData['name'] ?? user.displayName ?? 'User',
      'phone': userData['phone'] ?? '',
      'role': userData['role'] ?? 'employee',
      'msmeId': userData['msmeId'],
    };
  }

  // Get full user details including timestamps
  Future<Map<String, dynamic>> getFullUserDetails() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {};
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        return {
          'uid': user.uid,
          'msmeId': data?['msmeId'] ?? '',
          'email': user.email,
          'name': data?['name'] ?? user.displayName ?? 'User',
          'phone': data?['phone'] ?? '',
          'role': data?['role'] ?? 'employee',
          'createdAt': data?['createdAt'],
          'lastLoginAt': data?['lastLoginAt'],
        };
      }
    } catch (e) {
      debugPrint('Error getting full user details: $e');
    }
    return {
      'uid': user.uid,
      'msmeId': '',
      'email': user.email,
      'name': user.displayName ?? 'User',
      'role': 'employee',
    };
  }

  // ============================================================
  // CHANGE PASSWORD
  // ============================================================

  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        return AuthResult.failure('No user is currently signed in');
      }

      // Re-authenticate user before changing password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      return AuthResult.success(user, message: 'Password changed successfully');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e.code));
    } catch (e) {
      debugPrint('Change password error: $e');
      if (e.toString().contains('wrong-password') ||
          e.toString().contains('invalid-credential')) {
        return AuthResult.failure('Current password is incorrect');
      }
      return AuthResult.failure('Failed to change password. Please try again.');
    }
  }

  // Get user role
  Future<UserRole?> getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final userData = await _getUserFromFirestore(user.uid);
    final roleString = userData['role'];
    if (roleString == null) return UserRole.employee;

    return UserRole.values.firstWhere(
      (role) => role.name == roleString,
      orElse: () => UserRole.employee,
    );
  }

  // ============================================================
  // FIRESTORE HELPERS
  // ============================================================

  // Generate unique Vyapar ID (3 letters + 4 digits, e.g., "ABC1234")
  Future<String> _generateMsmeId() async {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const digits = '0123456789';
    final random = Random();

    for (int attempt = 0; attempt < 10; attempt++) {
      // Generate: 3 letters + 4 digits
      final letterPart = List.generate(3, (_) => letters[random.nextInt(26)]).join();
      final digitPart = List.generate(4, (_) => digits[random.nextInt(10)]).join();
      final msmeId = '$letterPart$digitPart';

      // Check uniqueness in users collection
      final exists = await _firestore
          .collection('users')
          .where('msmeId', isEqualTo: msmeId)
          .limit(1)
          .get();

      if (exists.docs.isEmpty) {
        return msmeId;
      }
    }

    // Fallback: use timestamp-based ID if random fails
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final letterPart = List.generate(3, (_) => letters[random.nextInt(26)]).join();
    return '$letterPart${timestamp.substring(timestamp.length - 4)}';
  }

  Future<void> _saveUserToFirestore({
    required String uid,
    required String name,
    required String email,
    required String phone,
  }) async {
    // Generate unique Vyapar ID for new user
    final msmeId = await _generateMsmeId();

    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'msmeId': msmeId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': UserRole.employee.name,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, String?>> _getUserFromFirestore(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        return {
          'name': data?['name'] as String?,
          'phone': data?['phone'] as String?,
          'role': data?['role'] as String?,
          'msmeId': data?['msmeId'] as String?,
        };
      }
    } catch (e) {
      debugPrint('Error getting user from Firestore: $e');
    }
    return {'name': null, 'phone': null, 'role': null, 'msmeId': null};
  }

  Future<void> _updateLastLogin(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating last login: $e');
    }
  }

  // Migration: Add Vyapar ID to existing users
  Future<void> _migrateMsmeId(String uid) async {
    try {
      final msmeId = await _generateMsmeId();
      await _firestore.collection('users').doc(uid).update({
        'msmeId': msmeId,
      });
      debugPrint('Migrated Vyapar ID for user $uid: $msmeId');
    } catch (e) {
      debugPrint('Error migrating Vyapar ID: $e');
    }
  }

  // ============================================================
  // ERROR MESSAGES
  // ============================================================

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled';
      case 'invalid-credential':
        return 'Invalid email or password';
      default:
        debugPrint('Firebase Auth Error: $code');
        return 'Authentication failed. Please try again';
    }
  }

  // ============================================================
  // STATIC HELPER
  // ============================================================

  static String getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.manager:
        return 'Manager';
      case UserRole.employee:
        return 'Employee';
    }
  }
}

// ============================================================
// AUTH RESULT CLASS
// ============================================================

class AuthResult {
  final bool isSuccess;
  final User? user;
  final String? message;
  final String? role;

  AuthResult._({
    required this.isSuccess,
    this.user,
    this.message,
    this.role,
  });

  factory AuthResult.success(User? user, {String? message, String? role}) {
    return AuthResult._(
      isSuccess: true,
      user: user,
      message: message,
      role: role,
    );
  }

  factory AuthResult.failure(String message) {
    return AuthResult._(
      isSuccess: false,
      message: message,
    );
  }
}
