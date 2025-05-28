// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'secure_storage_service.dart';
import 'user_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SecureStorageService _secureStorage = SecureStorageService();
  final UserService _userService = UserService();
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Authentication state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if 2FA is enabled
  Future<bool> is2FAEnabled() async {
    if (_auth.currentUser == null) {
      return false;
    }

    try {
      return await _userService.is2FAEnabled();
    } catch (e) {
      debugPrint('Error checking 2FA: $e');
      return true; // Par défaut activée
    }
  }

  // Vérification biométrique
  Future<bool> authenticateWithBiometrics() async {
    bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
    bool isDeviceSupported = await _localAuth.isDeviceSupported();
    
    if (!canCheckBiometrics || !isDeviceSupported) {
      return false;
    }
    
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Veuillez vous authentifier pour accéder à vos mots de passe',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      debugPrint('Error with biometric authentication: $e');
      return false;
    }
  }

  // Sign in avec mot de passe et biométrie si activée
  Future<User?> signInWithEmailPassword(String email, String password, 
      {bool checkBiometrics = true}) async {
    try {
      // Vérifier si l'authentification biométrique est requise
      bool useBiometrics = await _secureStorage.isBiometricAvailable();
      
      if (checkBiometrics && useBiometrics) {
        bool authenticated = await authenticateWithBiometrics();
        if (!authenticated) {
          throw FirebaseAuthException(
            code: 'biometric-auth-failed',
            message: 'Authentication biométrique échouée',
          );
        }
      }
      
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password
      );
      User? user = result.user;
      
      if (user != null) {
        await _secureStorage.write('user_id', user.uid);
        await _secureStorage.write('user_email', user.email ?? '');
        await _secureStorage.write('is_logged_in', 'true');
        await _secureStorage.write('2fa_verified', 'false'); // Toujours false après connexion
        await _secureStorage.write('last_active', DateTime.now().millisecondsSinceEpoch.toString());
        
        // Initialiser le mot de passe maître
        await _secureStorage.setMasterPassword(password);
        
        // Initialize the user profile et s'assurer que la 2FA est activée
        await _userService.getUserProfile();
        
        // S'assurer qu'il y a un numéro de téléphone par défaut
        String? savedPhone = await _userService.getSavedPhoneNumber();
        if (savedPhone == null || savedPhone.isEmpty) {
          await _userService.savePhoneNumber("+212703687923");
        }
        
        // Activer la 2FA par défaut si pas encore fait
        bool is2FAEnabled = await _userService.is2FAEnabled();
        if (!is2FAEnabled) {
          await _userService.enable2FA(savedPhone ?? "+212703687923");
        }
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
      
      if (user != null) {
        await _secureStorage.write('user_id', user.uid);
        await _secureStorage.write('user_email', user.email ?? '');
        await _secureStorage.write('is_logged_in', 'true');
        await _secureStorage.write('2fa_verified', 'false'); // Nécessite vérification 2FA même après inscription
        await _secureStorage.write('last_active', DateTime.now().millisecondsSinceEpoch.toString());
        
        // Initialiser le mot de passe maître
        await _secureStorage.setMasterPassword(password);
        
        // Initialize user profile avec 2FA activée par défaut
        await _userService.createInitialProfile(user);
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
      await _secureStorage.write('2fa_verified', 'false');
      await _secureStorage.write('is_logged_in', 'false');
      
      // Ne pas effacer le mot de passe maître pour permettre l'accès hors ligne
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  // Method to verify OTP code
  Future<bool> verifyOtp(String verificationId, String smsCode) async {
    try {
      // Dans une implémentation réelle, nous utiliserions PhoneAuthProvider.credential
      // pour créer les identifiants de connexion, mais pour notre application simulée :
      
      // Vérification simplifiée - dans une vraie implémentation, cela devrait
      // être géré par Firebase Auth ou un backend sécurisé
      if (smsCode.length == 6 && RegExp(r'^\d{6}$').hasMatch(smsCode)) {
        // Simuler une vérification réussie
        // En production, on vérifierait avec le backend ou Firebase
        
        // Marquer que la 2FA a été vérifiée
        await set2FAVerified();
        
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('OTP verification error: $e');
      return false;
    }
  }

  // Vérifier session et verrouillage automatique
  Future<bool> checkSession() async {
    try {
      String? lastActiveStr = await _secureStorage.read('last_active');
      if (lastActiveStr == null) return false;
      
      int lastActive = int.parse(lastActiveStr);
      int now = DateTime.now().millisecondsSinceEpoch;
      
      // Vérifier si la session est expirée (10 minutes d'inactivité)
      bool sessionExpired = (now - lastActive) > 10 * 60 * 1000;
      
      // Mettre à jour le dernier timestamp d'activité
      await _secureStorage.write('last_active', now.toString());
      
      if (sessionExpired) {
        return false;
      }
      
      return true;
    } catch (e) {
      return false;
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
  
  // Activer l'authentification biométrique
  Future<bool> enableBiometrics() async {
    try {
      bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      bool isDeviceSupported = await _localAuth.isDeviceSupported();
      
      if (!canCheckBiometrics || !isDeviceSupported) {
        return false;
      }
      
      // Authentifier pour confirmer
      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Veuillez vous authentifier pour activer la biométrie',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      
      if (authenticated) {
        await _secureStorage.setBiometricsEnabled(true);
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error enabling biometrics: $e');
      return false;
    }
  }
  
  // Désactiver l'authentification biométrique
  Future<void> disableBiometrics() async {
    await _secureStorage.setBiometricsEnabled(false);
  }
}