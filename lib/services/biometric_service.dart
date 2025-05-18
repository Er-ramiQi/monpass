// BiometricService corrigé avec toutes les méthodes nécessaires
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class BiometricService {
  static final LocalAuthentication _localAuth = LocalAuthentication();
  
  // Clés pour SharedPreferences
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _userEmailKey = 'secure_user_email';
  static const String _userPasswordKey = 'secure_user_password';
  
  // Méthode de débogage pour voir toutes les valeurs stockées
  static Future<void> debugPrintAllStoredValues() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      debugPrint('==== TOUTES LES VALEURS STOCKÉES ====');
      for (String key in keys) {
        dynamic value = prefs.get(key);
        // Masquer les mots de passe pour la sécurité
        if (key == _userPasswordKey && value != null) {
          value = "***MASQUÉ***";
        }
        debugPrint('$key: $value');
      }
      debugPrint('===================================');
    } catch (e) {
      debugPrint('Erreur lors du débogage: $e');
    }
  }
  
  // Vérifier si l'appareil supporte l'authentification biométrique
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      debugPrint('Support biométrique: $canAuthenticate');
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
      debugPrint('Types biométriques disponibles: $biometrics');
      return biometrics;
    } catch (e) {
      debugPrint('Erreur dans getAvailableBiometrics: $e');
      return [];
    }
  }

  // Authentifier l'utilisateur avec biométrie
  static Future<bool> authenticateWithBiometrics() async {
    try {
      debugPrint('Tentative d\'authentification biométrique...');
      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Utilisez votre empreinte digitale pour vous connecter',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
      debugPrint('Résultat authentification: $authenticated');
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
    
    // Vérifiez les valeurs d'entrée
    if (email.isEmpty || password.isEmpty) {
      debugPrint('⚠️ ERREUR: Tentative d\'activer la biométrie avec des identifiants vides!');
      return false;
    }
    
    // Stocker les identifiants AVANT d'activer la biométrie
    bool emailSaved = await prefs.setString('secure_user_email', email);
    bool passwordSaved = await prefs.setString('secure_user_password', password);
    
    // Vérifier que les identifiants ont bien été sauvegardés
    if (!emailSaved || !passwordSaved) {
      debugPrint('⚠️ ERREUR: Échec du stockage des identifiants!');
      return false;
    }
    
    // Vérifier que les valeurs sont bien présentes
    String? savedEmail = prefs.getString('secure_user_email');
    String? savedPassword = prefs.getString('secure_user_password');
    
    if (savedEmail == null || savedPassword == null) {
      debugPrint('⚠️ ERREUR: Les identifiants sont null après sauvegarde!');
      return false;
    }
    
    // Activer la biométrie SEULEMENT si les identifiants sont bien stockés
    bool biometricEnabled = await prefs.setBool('biometric_enabled', true);
    
    debugPrint('✅ Activation biométrique: $biometricEnabled');
    debugPrint('✅ Email sauvegardé: ${savedEmail.isNotEmpty}');
    debugPrint('✅ Mot de passe sauvegardé: ${savedPassword.isNotEmpty}');
    
    // Vérifier immédiatement après activation
    bool hasEmail = prefs.containsKey('secure_user_email') && prefs.getString('secure_user_email') != null;
    bool hasPassword = prefs.containsKey('secure_user_password') && prefs.getString('secure_user_password') != null;
    
    debugPrint('✅ Vérification finale - Email présent: $hasEmail, Mot de passe présent: $hasPassword');
    
    return biometricEnabled && hasEmail && hasPassword;
  } catch (e) {
    debugPrint('⚠️ Exception dans enableBiometricWithCredentials: $e');
    return false;
  }
}
  // Activer ou désactiver l'authentification biométrique
  static Future<bool> setBiometricEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool result = await prefs.setBool(_biometricEnabledKey, value);
      debugPrint('Biométrie ${value ? "activée" : "désactivée"}: $result');
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
      debugPrint('Statut biométrie activée: $enabled');
      return enabled;
    } catch (e) {
      debugPrint('Erreur dans isBiometricEnabled: $e');
      return false;
    }
  }
  
  // Enregistrer les identifiants pour l'authentification biométrique
  static Future<bool> saveCredentials(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userEmailKey, email);
      await prefs.setString(_userPasswordKey, password);
      debugPrint('Identifiants enregistrés pour: $email');
      return true;
    } catch (e) {
      debugPrint('Erreur lors de l\'enregistrement des identifiants: $e');
      return false;
    }
  }
  
  // Récupérer les identifiants enregistrés
  static Future<Map<String, String?>> getCredentials() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Utiliser des clés constantes
    const String emailKey = 'secure_user_email';
    const String passwordKey = 'secure_user_password';
    
    String? email = prefs.getString(emailKey);
    String? password = prefs.getString(passwordKey);
    
    debugPrint('🔍 Récupération des identifiants:');
    debugPrint('🔍 Email récupéré: ${email != null ? email.substring(0, min(3, email.length)) + "***" : "null"}');
    debugPrint('🔍 Mot de passe récupéré: ${password != null ? "***" : "null"}');
    
    return {'email': email, 'password': password};
  } catch (e) {
    debugPrint('⚠️ Erreur lors de la récupération des identifiants: $e');
    return {'email': null, 'password': null};
  }
}
  
  // Vérifier si des identifiants sont enregistrés
  static Future<bool> hasCredentials() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Utiliser des clés constantes pour éviter les erreurs de frappe
    const String emailKey = 'secure_user_email';
    const String passwordKey = 'secure_user_password';
    
    // Vérifier si les clés existent
    bool hasEmailKey = prefs.containsKey(emailKey);
    bool hasPasswordKey = prefs.containsKey(passwordKey);
    
    // Vérifier si les valeurs ne sont pas null ou vides
    String? emailValue = prefs.getString(emailKey);
    String? passwordValue = prefs.getString(passwordKey);
    
    bool hasEmailValue = emailValue != null && emailValue.isNotEmpty;
    bool hasPasswordValue = passwordValue != null && passwordValue.isNotEmpty;
    
    // Log détaillé
    debugPrint('🔍 Vérification des identifiants:');
    debugPrint('🔍 Email - Clé présente: $hasEmailKey, Valeur valide: $hasEmailValue');
    debugPrint('🔍 Mot de passe - Clé présente: $hasPasswordKey, Valeur valide: $hasPasswordValue');
    
    // Les deux doivent être présents et valides
    return hasEmailValue && hasPasswordValue;
  } catch (e) {
    debugPrint('⚠️ Erreur dans hasCredentials: $e');
    return false;
  }
}

  // CETTE MÉTHODE ÉTAIT MANQUANTE - Désactiver complètement la biométrie et supprimer les identifiants
  static Future<bool> disableBiometricAndClearCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Supprimer toutes les valeurs
      await prefs.remove(_userEmailKey);
      await prefs.remove(_userPasswordKey);
      await prefs.setBool(_biometricEnabledKey, false);
      
      debugPrint('Biométrie complètement désactivée et identifiants supprimés');
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
      debugPrint('Biométrie désactivée mais identifiants conservés');
      return true;
    } catch (e) {
      debugPrint('Erreur dans disableBiometricOnly: $e');
      return false;
    }
  }
}