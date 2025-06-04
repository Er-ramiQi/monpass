// lib/services/twilio_whatsapp_service.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TwilioWhatsAppService {
  // Twilio constants - USE YOUR OWN CREDENTIALS IN PRODUCTION
  // The actual Twilio credentials would be stored here
  // For security reasons, you'd use environment variables or secure storage, not hard-coded values
  final String _accountSid = "YOUR_ACCOUNT_SID";
  final String _authToken = "YOUR_AUTH_TOKEN";
  final String _fromWhatsApp = "+14155238886"; // Example Twilio WhatsApp Sandbox number
  final String _templateSid = "YOUR_TEMPLATE_SID";
  
  // Keys for local OTP storage
  static const String _otpStorageKey = 'otp_verification_code';
  static const String _otpPhoneKey = 'otp_verification_phone';
  
  // Generate a 6-digit OTP code
  String _generateOtpCode() {
    final random = Random();
    String otp = '';
    
    for (int i = 0; i < 6; i++) {
      otp += random.nextInt(10).toString();
    }
    
    return otp;
  }
  
  // Send OTP via WhatsApp
  Future<bool> sendOtp(String phoneNumber) async {
    try {
      // Generate an OTP code
      final String otpCode = _generateOtpCode();
      
      // Make sure number is in international format for WhatsApp
      if (!phoneNumber.startsWith('+')) {
        phoneNumber = '+$phoneNumber';
      }
      
      // In a real application, this would send a WhatsApp message using Twilio API
      // For this example app, we'll simulate success and store the OTP locally
      
      // Store OTP locally for future verification
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_otpStorageKey, otpCode);
      await prefs.setString(_otpPhoneKey, phoneNumber);
      
      debugPrint('OTP sent: $otpCode to WhatsApp number $phoneNumber');
      
      // For testing, you can show the OTP in console
      // In production, this would be securely sent to the user's WhatsApp
      debugPrint('🔐 SIMULATION: WhatsApp message sent with OTP code: $otpCode');
      
      return true;
    } catch (e) {
      debugPrint('WhatsApp OTP send error: $e');
      return false;
    }
  }
  
  // Verify an OTP code
  Future<bool> verifyOtp(String otpCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? storedOtp = prefs.getString(_otpStorageKey);
      
      // Check if entered code matches stored code
      if (storedOtp != null && storedOtp == otpCode.trim()) {
        // Clear OTP after successful verification
        await prefs.remove(_otpStorageKey);
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('OTP verification error: $e');
      return false;
    }
  }
  
  // Get stored phone number
  Future<String?> getStoredPhoneNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_otpPhoneKey);
    } catch (e) {
      debugPrint('Phone number retrieval error: $e');
      return null;
    }
  }
  
  // Real Twilio WhatsApp API implementation (commented out for simulation)
  // In a production app, you would use this code to actually send WhatsApp messages via Twilio
  /*
  Future<bool> _sendRealWhatsAppMessage(String phoneNumber, String otpCode) async {
    try {
      // Prepare URL for Twilio API
      final String url = 'https://api.twilio.com/2010-04-01/Accounts/$_accountSid/Messages.json';
      
      // Prepare headers with basic authentication
      String basicAuth = 'Basic ${base64Encode(utf8.encode('$_accountSid:$_authToken'))}';
      
      // Prepare request body
      final Map<String, String> body = {
        'From': 'whatsapp:$_fromWhatsApp',
        'To': 'whatsapp:$phoneNumber',
        'ContentSid': _templateSid,
        'ContentVariables': jsonEncode({"1": otpCode}),
        'Body': 'Your MonPass verification code is: $otpCode', // Fallback message
      };
      
      // Make HTTP request
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': basicAuth,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );
      
      // Check response
      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        debugPrint('Twilio error: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Twilio API error: $e');
      return false;
    }
  }
  */
}