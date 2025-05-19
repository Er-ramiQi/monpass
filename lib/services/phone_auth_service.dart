// lib/services/phone_auth_service.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'twilio_whatsapp_service.dart';
import 'user_service.dart';

class PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TwilioWhatsAppService _twilioService = TwilioWhatsAppService();
  final UserService _userService = UserService();
  
  // Send OTP to provided phone number via WhatsApp
  Future<String?> sendOtp({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(PhoneAuthCredential) onVerificationCompleted,
  }) async {
    try {
      // Check if phone number is valid
      if (phoneNumber.isEmpty) {
        onVerificationFailed(
          FirebaseAuthException(
            code: 'invalid-phone-number',
            message: 'Le numéro de téléphone est vide',
          ),
        );
        return null;
      }
      
      // Save phone number for future use
      await _userService.savePhoneNumber(phoneNumber);
      
      // Send OTP via Twilio WhatsApp
      bool success = await _twilioService.sendOtp(phoneNumber);
      
      if (success) {
        // Generate a unique verification ID 
        String verificationId = DateTime.now().millisecondsSinceEpoch.toString();
        
        // Call the callback to inform that the code has been sent
        onCodeSent(verificationId);
        
        return verificationId;
      } else {
        // Send failure
        onVerificationFailed(
          FirebaseAuthException(
            code: 'twilio-error',
            message: 'Unable to send WhatsApp message via Twilio',
          ),
        );
        return null;
      }
    } catch (e) {
      debugPrint('OTP send error: $e');
      onVerificationFailed(
        FirebaseAuthException(
          code: 'unknown-error',
          message: e.toString(),
        ),
      );
      return null;
    }
  }
  
  // Verify OTP code
  Future<UserCredential?> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      // Verify OTP code with our Twilio WhatsApp service
      bool isValid = await _twilioService.verifyOtp(smsCode);
      
      if (isValid) {
        if (_auth.currentUser != null) {
          // This is a 2FA setup - update user profile
          String? phoneNumber = await _twilioService.getStoredPhoneNumber();
          if (phoneNumber != null) {
            await _userService.enable2FA(phoneNumber);
          }
          
          // Simulate a credential for API compatibility
          return null;
        } else {
          // Compatibility with code expecting a UserCredential
          return null;
        }
      } else {
        // OTP code is not valid
        throw FirebaseAuthException(
          code: 'invalid-verification-code',
          message: 'The verification code is not valid',
        );
      }
    } catch (e) {
      debugPrint('OTP verification error: $e');
      rethrow;
    }
  }
  
  // Check if current user has a linked phone number
  bool isPhoneLinked() {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    return user.phoneNumber != null && user.phoneNumber!.isNotEmpty;
  }
  
  // Get current user's phone number
  String? getLinkedPhoneNumber() {
    return _auth.currentUser?.phoneNumber;
  }
}