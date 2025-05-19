// lib/services/phone_auth_service.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'twilio_whatsapp_service.dart';

class PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TwilioWhatsAppService _twilioService = TwilioWhatsAppService();
  
  // Envoyer OTP au numéro de téléphone fourni via WhatsApp
  Future<String?> sendOtp({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(PhoneAuthCredential) onVerificationCompleted,
  }) async {
    try {
      // Vérifier si le numéro est valide
      if (phoneNumber.isEmpty) {
        onVerificationFailed(
          FirebaseAuthException(
            code: 'invalid-phone-number',
            message: 'Le numéro de téléphone est vide',
          ),
        );
        return null;
      }
      
      // Envoyer OTP via Twilio WhatsApp
      bool success = await _twilioService.sendOtp(phoneNumber);
      
      if (success) {
        // Générer un ID de vérification unique 
        String verificationId = DateTime.now().millisecondsSinceEpoch.toString();
        
        // Appeler le callback pour informer que le code a été envoyé
        onCodeSent(verificationId);
        
        return verificationId;
      } else {
        // Échec de l'envoi
        onVerificationFailed(
          FirebaseAuthException(
            code: 'twilio-error',
            message: 'Impossible d\'envoyer le message WhatsApp via Twilio',
          ),
        );
        return null;
      }
    } catch (e) {
      debugPrint('Erreur d\'envoi OTP: $e');
      onVerificationFailed(
        FirebaseAuthException(
          code: 'unknown-error',
          message: e.toString(),
        ),
      );
      return null;
    }
  }
  
  // Vérifier le code OTP
  Future<UserCredential?> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      // Vérifier le code OTP avec notre service Twilio WhatsApp
      bool isValid = await _twilioService.verifyOtp(smsCode);
      
      if (isValid) {
        if (_auth.currentUser != null) {
          // C'est une configuration 2FA - mettre à jour le profil utilisateur
          String? phoneNumber = await _twilioService.getStoredPhoneNumber();
          
          // Simuler un credential pour la compatibilité API
          return null;
        } else {
          // Compatibilité avec le code qui attend un UserCredential
          return null;
        }
      } else {
        // Le code OTP n'est pas valide
        throw FirebaseAuthException(
          code: 'invalid-verification-code',
          message: 'Le code de vérification n\'est pas valide',
        );
      }
    } catch (e) {
      debugPrint('Erreur de vérification OTP: $e');
      return null;
    }
  }
  
  // Vérifier si l'utilisateur actuel a un numéro de téléphone lié
  bool isPhoneLinked() {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    return user.phoneNumber != null && user.phoneNumber!.isNotEmpty;
  }
  
  // Obtenir le numéro de téléphone de l'utilisateur actuel
  String? getLinkedPhoneNumber() {
    return _auth.currentUser?.phoneNumber;
  }
  
  // Dissocier le fournisseur d'authentification par téléphone (désactiver 2FA)
  Future<bool> unlinkPhoneProvider() async {
    try {
      if (_auth.currentUser == null) return false;
      
      for (var provider in _auth.currentUser!.providerData) {
        if (provider.providerId == PhoneAuthProvider.PROVIDER_ID) {
          await _auth.currentUser!.unlink(PhoneAuthProvider.PROVIDER_ID);
          return true;
        }
      }
      return false; // Aucun fournisseur téléphonique trouvé
    } catch (e) {
      debugPrint('Erreur de dissociation du fournisseur téléphonique: $e');
      return false;
    }
  }
}