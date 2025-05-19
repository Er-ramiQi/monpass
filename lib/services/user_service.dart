import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  // Clés pour le stockage local
  static const String _userProfileKey = 'user_profile';
  static const String _is2FAEnabledKey = 'is_2fa_enabled';

  // Obtenir le profil utilisateur du stockage local
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? profileJson = prefs.getString(_userProfileKey);
      
      if (profileJson == null || profileJson.isEmpty) {
        // Créer un profil par défaut si aucun n'existe
        Map<String, dynamic> defaultProfile = {
          'email': '',
          'displayName': 'Utilisateur',
          'phoneNumber': '',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'is2FAEnabled': false,
        };
        
        await saveUserProfile(defaultProfile);
        return defaultProfile;
      }
      
      return jsonDecode(profileJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Erreur de récupération de profil: $e');
      return null;
    }
  }

  // Sauvegarder le profil utilisateur
  Future<bool> saveUserProfile(Map<String, dynamic> profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_userProfileKey, jsonEncode(profile));
    } catch (e) {
      debugPrint('Erreur de sauvegarde de profil: $e');
      return false;
    }
  }

  // Mettre à jour le profil utilisateur
  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    try {
      Map<String, dynamic>? currentProfile = await getUserProfile();
      if (currentProfile != null) {
        currentProfile.addAll(data);
        return await saveUserProfile(currentProfile);
      }
      return false;
    } catch (e) {
      debugPrint('Erreur de mise à jour de profil: $e');
      return false;
    }
  }

  // Activer 2FA
  Future<bool> enable2FA(String phoneNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Mettre à jour le profil
      Map<String, dynamic>? currentProfile = await getUserProfile();
      if (currentProfile != null) {
        currentProfile['phoneNumber'] = phoneNumber;
        currentProfile['is2FAEnabled'] = true;
        await saveUserProfile(currentProfile);
      }
      
      // Enregistrer le statut 2FA
      return await prefs.setBool(_is2FAEnabledKey, true);
    } catch (e) {
      debugPrint('Erreur d\'activation 2FA: $e');
      return false;
    }
  }

  // Désactiver 2FA
  Future<bool> disable2FA() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Mettre à jour le profil
      Map<String, dynamic>? currentProfile = await getUserProfile();
      if (currentProfile != null) {
        currentProfile['is2FAEnabled'] = false;
        await saveUserProfile(currentProfile);
      }
      
      // Enregistrer le statut 2FA
      return await prefs.setBool(_is2FAEnabledKey, false);
    } catch (e) {
      debugPrint('Erreur de désactivation 2FA: $e');
      return false;
    }
  }
}