// lib/services/twilio_whatsapp_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TwilioWhatsAppService {
  // Constantes Twilio - UTILISANT VOS CREDENTIALS
 //....
  // Clés pour stockage local du code OTP
  static const String _otpStorageKey = 'otp_verification_code';
  static const String _otpPhoneKey = 'otp_verification_phone';
  
  // Générer un code OTP à 6 chiffres
  String _generateOtpCode() {
    final random = Random();
    String otp = '';
    
    for (int i = 0; i < 6; i++) {
      otp += random.nextInt(10).toString();
    }
    
    return otp;
  }
  
  // Envoyer un code OTP via WhatsApp
  Future<bool> sendOtp(String phoneNumber) async {
    try {
      // Générer un code OTP
      final String otpCode = _generateOtpCode();
      
      // S'assurer que le numéro est au format international pour WhatsApp
      if (!phoneNumber.startsWith('+')) {
        phoneNumber = '+$phoneNumber';
      }
      
      // Préparer l'URL pour l'API Twilio
      final String url = 'https://api.twilio.com/2010-04-01/Accounts/$_accountSid/Messages.json';
      
      // Préparer les en-têtes avec l'authentification de base
      String basicAuth = 'Basic ${base64Encode(utf8.encode('$_accountSid:$_authToken'))}';
      
      // Préparer le corps de la requête
      final Map<String, String> body = {
        'From': 'whatsapp:$_fromWhatsApp',
        'To': 'whatsapp:$phoneNumber',
        'ContentSid': _templateSid,
        'ContentVariables': jsonEncode({"1": otpCode}),
        'Body': 'Votre code de vérification MonPass est: $otpCode', // Message de secours
      };
      
      // Faire la requête HTTP
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': basicAuth,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );
      
      // Vérifier la réponse
      if (response.statusCode == 201 || response.statusCode == 200) {
        // Stocker localement le code OTP pour vérification ultérieure
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_otpStorageKey, otpCode);
        await prefs.setString(_otpPhoneKey, phoneNumber);
        
        debugPrint('OTP envoyé: $otpCode au numéro WhatsApp $phoneNumber');
        return true;
      } else {
        debugPrint('Erreur Twilio: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Erreur d\'envoi OTP WhatsApp: $e');
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