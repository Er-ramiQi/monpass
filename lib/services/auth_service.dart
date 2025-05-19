import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'secure_storage_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SecureStorageService _secureStorage = SecureStorageService();

  // Obtenir l'utilisateur actuel
  User? get currentUser => _auth.currentUser;

  // Stream d'états d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();
// Vérifier si 2FA est activé (toujours retourne false dans cette version simplifiée)
  Future<bool> is2FAEnabled() async {
    // Dans la version simplifiée, on désactive la 2FA
    return false;
  }

  // Méthode de simulation d'envoi d'OTP (dans la version simplifiée, elle est inutilisée)
  Future<String?> sendOtpToPhone({
    required String phoneNumber,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(PhoneAuthCredential) onVerificationCompleted,
  }) async {
    // Retourne un ID de vérification fictif
    return 'verification-id-not-used';
  }

  // Méthode de simulation de vérification d'OTP (dans la version simplifiée, elle est inutilisée)
  Future<bool> verifyOtp(String verificationId, String smsCode) async {
    // Dans la version simplifiée, on ignore l'OTP
    return true;
  }
  // Connexion avec email et mot de passe
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password
      );
      User? user = result.user;
      
      // Stocker l'ID utilisateur localement pour accès hors ligne
      if (user != null) {
        await _secureStorage.write('user_id', user.uid);
        await _secureStorage.write('user_email', user.email ?? '');
      }
      
      return user;
    } catch (e) {
      debugPrint('Erreur de connexion: $e');
      rethrow;
    }
  }

  // Inscription avec email et mot de passe
  Future<User?> registerWithEmailPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password
      );
      User? user = result.user;
      
      // Stocker l'ID utilisateur localement pour accès hors ligne
      if (user != null) {
        await _secureStorage.write('user_id', user.uid);
        await _secureStorage.write('user_email', user.email ?? '');
      }
      
      return user;
    } catch (e) {
      debugPrint('Erreur d\'inscription: $e');
      rethrow;
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      // Ne pas effacer le stockage sécurisé, mais marquer l'utilisateur comme déconnecté
      await _secureStorage.write('is_logged_in', 'false');
    } catch (e) {
      debugPrint('Erreur de déconnexion: $e');
      rethrow;
    }
  }

  // Récupération de mot de passe
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Erreur de récupération de mot de passe: $e');
      rethrow;
    }
  }
  
  // Vérifier si l'utilisateur est connecté (pour mode hors ligne)
  Future<bool> isLoggedIn() async {
    User? user = currentUser;
    if (user != null) return true;
    
    // Vérifier dans le stockage local
    String? isLoggedIn = await _secureStorage.read('is_logged_in');
    return isLoggedIn == 'true';
  }
  
  // Obtenir l'ID utilisateur (même hors ligne)
  Future<String?> getUserId() async {
    User? user = currentUser;
    if (user != null) return user.uid;
    
    // Récupérer depuis le stockage local
    return await _secureStorage.read('user_id');
  }
}