import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  // Clés pour le stockage des données
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _userEmailKey = 'secure_user_email';
  static const String _userPasswordKey = 'secure_user_password';
  
  // Vérifier si l'appareil supporte l'authentification biométrique
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      debugPrint('Erreur dans isBiometricAvailable: $e');
      return false;
    }
  }

  // Obtenir la liste des types biométriques disponibles
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      var biometrics = await _localAuth.getAvailableBiometrics();
      return biometrics;
    } catch (e) {
      debugPrint('Erreur dans getAvailableBiometrics: $e');
      return [];
    }
  }

  // Authentifier l'utilisateur avec biométrie
  static Future<bool> authenticateWithBiometrics() async {
    try {
      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Utilisez votre empreinte digitale pour vous connecter',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
      return authenticated;
    } on PlatformException catch (e) {
      debugPrint('PlatformException dans authenticateWithBiometrics: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Exception dans authenticateWithBiometrics: $e');
      return false;
    }
  }

  // Activer la biométrie ET sauvegarder les identifiants en une seule opération
  static Future<bool> enableBiometricWithCredentials(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Vérification des identifiants
      if (email.isEmpty || password.isEmpty) {
        return false;
      }
      
      // Utiliser le stockage sécurisé pour les identifiants
      await _secureStorage.write(key: _userEmailKey, value: email);
      await _secureStorage.write(key: _userPasswordKey, value: password);
      
      // Stocker uniquement le flag d'activation dans SharedPreferences
      bool biometricEnabled = await prefs.setBool(_biometricEnabledKey, true);
      
      // Vérifier que les identifiants ont bien été enregistrés
      String? savedEmail = await _secureStorage.read(key: _userEmailKey);
      String? savedPassword = await _secureStorage.read(key: _userPasswordKey);
      
      return biometricEnabled && savedEmail != null && savedPassword != null;
    } catch (e) {
      debugPrint('Exception dans enableBiometricWithCredentials: $e');
      return false;
    }
  }

  // Activer ou désactiver l'authentification biométrique
  static Future<bool> setBiometricEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool result = await prefs.setBool(_biometricEnabledKey, value);
      return result;
    } catch (e) {
      debugPrint('Erreur dans setBiometricEnabled: $e');
      return false;
    }
  }

  // Vérifier si l'authentification biométrique est activée
  static Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool enabled = prefs.getBool(_biometricEnabledKey) ?? false;
      return enabled;
    } catch (e) {
      debugPrint('Erreur dans isBiometricEnabled: $e');
      return false;
    }
  }
  
  // Enregistrer les identifiants pour l'authentification biométrique
  static Future<bool> saveCredentials(String email, String password) async {
    try {
      await _secureStorage.write(key: _userEmailKey, value: email);
      await _secureStorage.write(key: _userPasswordKey, value: password);
      return true;
    } catch (e) {
      debugPrint('Erreur lors de l\'enregistrement des identifiants: $e');
      return false;
    }
  }
  
  // Récupérer les identifiants enregistrés
  static Future<Map<String, String?>> getCredentials() async {
    try {
      String? email = await _secureStorage.read(key: _userEmailKey);
      String? password = await _secureStorage.read(key: _userPasswordKey);
      
      return {'email': email, 'password': password};
    } catch (e) {
      debugPrint('Erreur lors de la récupération des identifiants: $e');
      return {'email': null, 'password': null};
    }
  }
  
  // Vérifier si des identifiants sont enregistrés
  static Future<bool> hasCredentials() async {
    try {
      String? email = await _secureStorage.read(key: _userEmailKey);
      String? password = await _secureStorage.read(key: _userPasswordKey);
      
      return email != null && email.isNotEmpty && 
             password != null && password.isNotEmpty;
    } catch (e) {
      debugPrint('Erreur dans hasCredentials: $e');
      return false;
    }
  }

  // Désactiver complètement la biométrie et supprimer les identifiants
  static Future<bool> disableBiometricAndClearCredentials() async {
    try {
      // Supprimer les identifiants du stockage sécurisé
      await _secureStorage.delete(key: _userEmailKey);
      await _secureStorage.delete(key: _userPasswordKey);
      
      // Désactiver le flag biométrique
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, false);
      
      return true;
    } catch (e) {
      debugPrint('Erreur dans disableBiometricAndClearCredentials: $e');
      return false;
    }
  }
  
  // Désactiver uniquement la biométrie sans effacer les identifiants
  static Future<bool> disableBiometricOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, false);
      return true;
    } catch (e) {
      debugPrint('Erreur dans disableBiometricOnly: $e');
      return false;
    }
  }
}