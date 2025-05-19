// lib/services/twilio_service.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:twilio_flutter/twilio_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TwilioService {
  // Constantes Twilio - REMPLACEZ PAR VOS CREDENTIALS
  static const String _accountSid = 'AC9f8ecedbea3cb10855a19505c8123326';
  static const String _authToken = 'VOTRE_AUTH_TOKEN';
  static const String _twilioNumber = '+14155238886';
  
  // Clé pour stockage local du code OTP
  static const String _otpStorageKey = 'otp_verification_code';
  static const String _otpPhoneKey = '+212703687923';
  
  // Instance Twilio
  late TwilioFlutter _twilioFlutter;
  
  // Constructeur
  TwilioService() {
    _twilioFlutter = TwilioFlutter(
      accountSid: _accountSid,
      authToken: _authToken,
      twilioNumber: _twilioNumber,
    );
  }
  
  // Générer un code OTP à 6 chiffres
  String _generateOtpCode() {
    final random = Random();
    String otp = '';
    
    for (int i = 0; i < 6; i++) {
      otp += random.nextInt(10).toString();
    }
    
    return otp;
  }
  
  // Envoyer un code OTP
  Future<bool> sendOtp(String phoneNumber) async {
    try {
      // Générer un code OTP
      final String otpCode = _generateOtpCode();
      
      // Formater le numéro de téléphone si nécessaire
      String formattedPhone = phoneNumber;
      if (!formattedPhone.startsWith('+')) {
        formattedPhone = '+1$formattedPhone'; // Assumant un code pays par défaut +1 (USA)
      }
      
      // Message SMS
      String message = 'Votre code de vérification MonPass est: $otpCode';
      
      // Envoyer le SMS
      await _twilioFlutter.sendSMS(
        toNumber: formattedPhone,
        messageBody: message,
      );
      
      // Stocker localement le code OTP pour vérification ultérieure
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_otpStorageKey, otpCode);
      await prefs.setString(_otpPhoneKey, formattedPhone);
      
      debugPrint('OTP envoyé: $otpCode au numéro $formattedPhone');
      return true;
    } catch (e) {
      debugPrint('Erreur d\'envoi OTP: $e');
      return false;
    }
  }
  
  // Vérifier un code OTP
  Future<bool> verifyOtp(String otpCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? storedOtp = prefs.getString(_otpStorageKey);
      
      // Vérifier si le code entré correspond au code stocké
      if (storedOtp != null && storedOtp == otpCode.trim()) {
        // Effacer le code OTP après vérification réussie
        await prefs.remove(_otpStorageKey);
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Erreur de vérification OTP: $e');
      return false;
    }
  }
  
  // Obtenir le numéro de téléphone stocké
  Future<String?> getStoredPhoneNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_otpPhoneKey);
    } catch (e) {
      debugPrint('Erreur de récupération du numéro de téléphone: $e');
      return null;
    }
  }
}