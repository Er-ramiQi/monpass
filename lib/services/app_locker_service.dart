// lib/services/app_locker_service.dart
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:shared_preferences/shared_preferences.dart';
import 'secure_storage_service.dart';
import 'package:flutter/services.dart';

class AppLockerService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final SecureStorageService _secureStorage;
  
  // Durée d'inactivité avant verrouillage automatique (en minutes)
  static const int _autoLockDuration = 5;
  
  // Clés pour le stockage de préférences
  static const String _autoLockKey = 'auto_lock_enabled';
  static const String _bioAuthKey = 'biometric_auth_enabled';
  static const String _lastActiveKey = 'last_active_timestamp';
  
  AppLockerService(this._secureStorage);
  
  // Vérifier si l'application doit être verrouillée
  Future<bool> shouldLockApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoLockEnabled = prefs.getBool(_autoLockKey) ?? true;
      
      if (!autoLockEnabled) return false;
      
      final lastActiveString = await _secureStorage.read(_lastActiveKey);
      if (lastActiveString == null) return false;
      
      final lastActive = int.parse(lastActiveString);
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Vérifier si le délai d'inactivité est dépassé
      return (now - lastActive) > (_autoLockDuration * 60 * 1000);
    } catch (e) {
      debugPrint('Error checking app lock status: $e');
      return false;
    }
  }
  
  // Mettre à jour le timestamp d'activité
  Future<void> updateActivityTimestamp() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch.toString();
      await _secureStorage.write(_lastActiveKey, now);
    } catch (e) {
      debugPrint('Error updating activity timestamp: $e');
    }
  }
  
  // Vérifier les capacités biométriques
  Future<Map<String, dynamic>> checkBiometricCapabilities() async {
    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      
      if (!canCheckBiometrics || !isDeviceSupported) {
        return {
          'available': false,
          'reason': 'Votre appareil ne supporte pas l\'authentification biométrique'
        };
      }
      
      final List<BiometricType> availableBiometrics = 
          await _localAuth.getAvailableBiometrics();
      
      return {
        'available': availableBiometrics.isNotEmpty,
        'biometrics': availableBiometrics,
        'hasFaceId': availableBiometrics.contains(BiometricType.face),
        'hasFingerprint': availableBiometrics.contains(BiometricType.fingerprint),
      };
    } catch (e) {
      return {
        'available': false,
        'reason': 'Erreur lors de la vérification des capacités biométriques'
      };
    }
  }
  
  // Authentifier l'utilisateur avec biométrie
  Future<bool> authenticateWithBiometrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bioAuthEnabled = prefs.getBool(_bioAuthKey) ?? false;
      
      if (!bioAuthEnabled) {
        return true; // Si l'authentification biométrique n'est pas activée, ne pas la vérifier
      }
      
      final capabilities = await checkBiometricCapabilities();
      if (!(capabilities['available'] as bool)) {
        return false;
      }
      
      return await _localAuth.authenticate(
        localizedReason: 'Veuillez vous authentifier pour accéder à vos mots de passe',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      if (e is PlatformException) {
        if (e.code == auth_error.notAvailable || 
            e.code == auth_error.notEnrolled || 
            e.code == auth_error.passcodeNotSet) {
          // Si la biométrie n'est pas disponible, laisser passer
          return true;
        }
      }
      
      debugPrint('Error during biometric authentication: $e');
      return false;
    }
  }
  
  // Activer ou désactiver le verrouillage automatique
  Future<void> setAutoLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoLockKey, enabled);
  }
  
  // Activer ou désactiver l'authentification biométrique
  Future<void> setBiometricAuthEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bioAuthKey, enabled);
  }
  
  // Vérifier si le verrouillage automatique est activé
  Future<bool> isAutoLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoLockKey) ?? true;
  }
  
  // Vérifier si l'authentification biométrique est activée
  Future<bool> isBiometricAuthEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_bioAuthKey) ?? false;
  }
}