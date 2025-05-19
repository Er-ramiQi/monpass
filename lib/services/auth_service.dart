// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'secure_storage_service.dart';
import 'user_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SecureStorageService _secureStorage = SecureStorageService();
  final UserService _userService = UserService();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Authentication state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if 2FA is enabled
  Future<bool> is2FAEnabled() async {
    // Check if user is logged in
    if (_auth.currentUser == null) {
      return false;
    }

    try {
      // Get user info from UserService
      return await _userService.is2FAEnabled();
    } catch (e) {
      debugPrint('Error checking 2FA: $e');
      return false;
    }
  }

  // Method to simulate sending OTP
  Future<String?> sendOtpToPhone({
    required String phoneNumber,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(PhoneAuthCredential) onVerificationCompleted,
  }) async {
    // Save the phone number for future use
    await _userService.savePhoneNumber(phoneNumber);
    
    // In a real app, this would actually send an OTP
    // For this example we're creating a simulated verification ID
    return 'verification-id-${DateTime.now().millisecondsSinceEpoch}';
  }

  // Method to simulate verifying OTP
  Future<bool> verifyOtp(String verificationId, String smsCode) async {
    // In a real app, we would validate the OTP against a service
    // For this example, we'll simulate successful verification with any 6-digit code
    bool isValid = smsCode.length == 6 && RegExp(r'^\d{6}$').hasMatch(smsCode);
    
    if (isValid) {
      // Mark 2FA as verified
      await set2FAVerified();
    }
    
    return isValid;
  }

  // Sign in with email and password
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password
      );
      User? user = result.user;
      
      // Store user ID locally for offline access
      if (user != null) {
        await _secureStorage.write('user_id', user.uid);
        await _secureStorage.write('user_email', user.email ?? '');
        
        // Important: Store a flag indicating user is logged in
        // but hasn't completed 2FA if it's enabled
        await _secureStorage.write('is_logged_in', 'true');
        
        // New: mark if 2FA has been verified or not
        await _secureStorage.write('2fa_verified', 'false');
        
        // Initialize the user profile
        await _userService.getUserProfile();
      }
      
      return user;
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
  }

  // Register with email and password
  Future<User?> registerWithEmailPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password
      );
      User? user = result.user;
      
      // Store user ID locally for offline access
      if (user != null) {
        await _secureStorage.write('user_id', user.uid);
        await _secureStorage.write('user_email', user.email ?? '');
        await _secureStorage.write('is_logged_in', 'true');
        await _secureStorage.write('2fa_verified', 'true'); // By default, 2FA is not enabled for new users
        
        // Initialize user profile
        await _userService.getUserProfile();
      }
      
      return user;
    } catch (e) {
      debugPrint('Registration error: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      // Clear the 2fa_verified flag
      await _secureStorage.write('2fa_verified', 'false');
      await _secureStorage.write('is_logged_in', 'false');
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  // Password reset
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Password reset error: $e');
      rethrow;
    }
  }
  
  // Check if user is logged in (for offline mode)
  Future<bool> isLoggedIn() async {
    User? user = currentUser;
    if (user != null) return true;
    
    // Check in local storage
    String? isLoggedIn = await _secureStorage.read('is_logged_in');
    return isLoggedIn == 'true';
  }
  
  // Check if 2FA verification is complete
  Future<bool> is2FAVerified() async {
    String? verified = await _secureStorage.read('2fa_verified');
    return verified == 'true';
  }
  
  // Mark 2FA verification as complete
  Future<void> set2FAVerified() async {
    await _secureStorage.write('2fa_verified', 'true');
  }
  
  // Get user ID (even offline)
  Future<String?> getUserId() async {
    User? user = currentUser;
    if (user != null) return user.uid;
    
    // Retrieve from local storage
    return await _secureStorage.read('user_id');
  }
}