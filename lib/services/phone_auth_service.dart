// lib/services/phone_auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Send OTP code to the provided phone number
  Future<String?> sendOtp({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(PhoneAuthCredential) onVerificationCompleted,
  }) async {
    try {
      String verificationId = '';
      
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: onVerificationCompleted,
        verificationFailed: onVerificationFailed,
        codeSent: (String verId, int? resendToken) {
          verificationId = verId;
          onCodeSent(verId);
        },
        codeAutoRetrievalTimeout: (String verId) {
          verificationId = verId;
        },
        timeout: const Duration(seconds: 120),
      );
      
      return verificationId;
    } catch (e) {
      debugPrint('Error sending OTP: $e');
      return null;
    }
  }
  
  // Verify OTP code
  Future<UserCredential?> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      
      // Sign in or link with credential
      if (_auth.currentUser != null) {
        // Link to existing account (for 2FA setup)
        await _auth.currentUser!.linkWithCredential(credential);
        return null; // No need to return credential for linking
      } else {
        // Sign in with phone number (for 2FA verification)
        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      return null;
    }
  }
  
  // Check if current user has phone number linked
  bool isPhoneLinked() {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    return user.phoneNumber != null && user.phoneNumber!.isNotEmpty;
  }
  
  // Get current user's phone number
  String? getLinkedPhoneNumber() {
    return _auth.currentUser?.phoneNumber;
  }
  
  // Unlink phone auth provider (disable 2FA)
  Future<bool> unlinkPhoneProvider() async {
    try {
      if (_auth.currentUser == null) return false;
      
      for (var provider in _auth.currentUser!.providerData) {
        if (provider.providerId == PhoneAuthProvider.PROVIDER_ID) {
          await _auth.currentUser!.unlink(PhoneAuthProvider.PROVIDER_ID);
          return true;
        }
      }
      return false; // No phone provider found
    } catch (e) {
      debugPrint('Error unlinking phone provider: $e');
      return false;
    }
  }
}