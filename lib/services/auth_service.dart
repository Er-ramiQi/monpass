// lib/services/auth_service.dart (modifié)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'secure_storage_service.dart';
import 'user_service.dart'; // Ajouté pour vérifier l'état 2FA

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SecureStorageService _secureStorage = SecureStorageService();
  final UserService _userService = UserService(); // Ajouté pour vérifier l'état 2FA

  // Obtenir l'utilisateur actuel
  User? get currentUser => _auth.currentUser;

  // Stream d'états d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Vérifier si 2FA est activé
  Future<bool> is2FAEnabled() async {
    // Vérifier si l'utilisateur est connecté
    if (_auth.currentUser == null) {
      return false;
    }

    try {
      // Obtenez les infos utilisateur de UserService
      Map<String, dynamic>? userProfile = await _userService.getUserProfile();
      return userProfile != null && userProfile['is2FAEnabled'] == true;
    } catch (e) {
      debugPrint('Erreur lors de la vérification 2FA: $e');
      return false;
    }
  }

  // Méthode de simulation d'envoi d'OTP
  Future<String?> sendOtpToPhone({
    required String phoneNumber,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(PhoneAuthCredential) onVerificationCompleted,
  }) async {
    return 'verification-id-not-used';
  }

  // Méthode de simulation de vérification d'OTP
  Future<bool> verifyOtp(String verificationId, String smsCode) async {
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
        
        // Important: Stocker un flag indiquant que l'utilisateur est connecté
        // mais n'a pas encore passé la 2FA si celle-ci est activée
        await _secureStorage.write('is_logged_in', 'true');
        
        // Nouveau: marquer si la 2FA a été vérifiée ou non
        await _secureStorage.write('2fa_verified', 'false');
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
        await _secureStorage.write('is_logged_in', 'true');
        await _secureStorage.write('2fa_verified', 'true'); // Par défaut, 2FA n'est pas activée pour un nouvel utilisateur
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
      // Effacer le flag 2fa_verified
      await _secureStorage.write('2fa_verified', 'false');
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
  
  // Vérifier si l'authentification 2FA a été complétée
  Future<bool> is2FAVerified() async {
    String? verified = await _secureStorage.read('2fa_verified');
    return verified == 'true';
  }
  
  // Marquer l'authentification 2FA comme complétée
  Future<void> set2FAVerified() async {
    await _secureStorage.write('2fa_verified', 'true');
  }
  
  // Obtenir l'ID utilisateur (même hors ligne)
  Future<String?> getUserId() async {
    User? user = currentUser;
    if (user != null) return user.uid;
    
    // Récupérer depuis le stockage local
    return await _secureStorage.read('user_id');
  }
}