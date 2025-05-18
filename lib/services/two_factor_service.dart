import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TwoFactorService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Variables pour stocker les informations de vérification
  String? _verificationId;
  int? _resendToken;
  User? _authenticatedUser;

  // Première étape : Authentification avec email et mot de passe
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Stockage temporaire de l'utilisateur
      _authenticatedUser = userCredential.user;
      return userCredential.user;
    } catch (e) {
      debugPrint('Erreur dans signInWithEmailPassword: $e');
      rethrow;
    }
  }

  // Deuxième étape : Envoyer un code OTP au numéro de téléphone de l'utilisateur
  Future<void> sendOtpToPhone({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(PhoneAuthCredential) onVerificationCompleted,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) {
          // Auto-vérification sur Android
          onVerificationCompleted(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('Échec de la vérification du téléphone: ${e.code} - ${e.message}');
          onVerificationFailed(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      debugPrint('Erreur dans sendOtpToPhone: $e');
      rethrow;
    }
  }

  // Vérifier le code OTP saisi par l'utilisateur
  Future<bool> verifyOtpCode({required String smsCode}) async {
    try {
      if (_verificationId == null) {
        throw Exception('ID de vérification non disponible');
      }

      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      try {
        if (_authenticatedUser != null) {
          // Lier cette credential au compte déjà authentifié
          await _authenticatedUser!.linkWithCredential(credential);
          
          // IMPORTANT: Recharger l'utilisateur pour mettre à jour ses propriétés
          await _authenticatedUser!.reload();
          _authenticatedUser = _auth.currentUser;
          
          return true;
        } else {
          throw Exception("L'utilisateur n'est pas authentifié");
        }
      } catch (e) {
        // Si le téléphone est déjà lié à cet utilisateur, c'est OK
        if (e is FirebaseAuthException && e.code == 'provider-already-linked') {
          return true;
        }
        debugPrint('Erreur lors de la vérification OTP: $e');
        rethrow;
      }
    } catch (e) {
      debugPrint('Exception dans verifyOtpCode: $e');
      rethrow;
    }
  }

  // Déconnexion
  Future<void> logout() async {
    try {
      await _auth.signOut();
      _authenticatedUser = null;
    } catch (e) {
      debugPrint('Erreur lors de la déconnexion: $e');
      rethrow;
    }
  }
  
  // Vérifier si l'utilisateur est pleinement authentifié (2FA)
  bool isUserFullyAuthenticated() {
    User? user = _auth.currentUser;
    if (user == null) return false;
    
    // Vérifier si l'utilisateur a un fournisseur de téléphone lié
    return user.providerData.any((element) => element.providerId == 'phone');
  }
  
  // Obtenir l'utilisateur actuellement connecté
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}