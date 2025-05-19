// lib/services/user_service.dart - Updated version with 2FA support
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  // Clés pour le stockage local
  static const String _userProfileKey = 'user_profile';
  static const String _is2FAEnabledKey = 'is_2fa_enabled';
  
  // Firebase Auth
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtenir le profil utilisateur du stockage local
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? profileJson = prefs.getString(_userProfileKey);
      
      if (profileJson == null || profileJson.isEmpty) {
        // Créer un profil par défaut si aucun n'existe
        User? currentUser = _auth.currentUser;
        
        Map<String, dynamic> defaultProfile = {
          'email': currentUser?.email ?? '',
          'displayName': currentUser?.displayName ?? 'Utilisateur',
          'phoneNumber': currentUser?.phoneNumber ?? '',
          'photoURL': currentUser?.photoURL,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'is2FAEnabled': currentUser?.phoneNumber != null && currentUser!.phoneNumber!.isNotEmpty,
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        };
        
        await saveUserProfile(defaultProfile);
        return defaultProfile;
      }
      
      Map<String, dynamic> profile = jsonDecode(profileJson) as Map<String, dynamic>;
      
      // Synchroniser avec Firebase si nécessaire
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        bool needsUpdate = false;
        
        if (profile['email'] != currentUser.email) {
          profile['email'] = currentUser.email;
          needsUpdate = true;
        }
        
        if (currentUser.displayName != null && profile['displayName'] != currentUser.displayName) {
          profile['displayName'] = currentUser.displayName;
          needsUpdate = true;
        }
        
        if (currentUser.phoneNumber != null && profile['phoneNumber'] != currentUser.phoneNumber) {
          profile['phoneNumber'] = currentUser.phoneNumber;
          profile['is2FAEnabled'] = currentUser.phoneNumber != null && currentUser.phoneNumber!.isNotEmpty;
          needsUpdate = true;
        }
        
        if (needsUpdate) {
          profile['lastUpdated'] = DateTime.now().millisecondsSinceEpoch;
          await saveUserProfile(profile);
        }
      }
      
      return profile;
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
        // Mettre à jour les champs
        currentProfile.addAll(data);
        
        // Mettre à jour la date de dernière modification
        currentProfile['lastUpdated'] = DateTime.now().millisecondsSinceEpoch;
        
        // Synchroniser avec Firebase si possible
        User? currentUser = _auth.currentUser;
        if (currentUser != null) {
          try {
            if (data.containsKey('displayName') && 
                data['displayName'] != currentUser.displayName) {
              await currentUser.updateDisplayName(data['displayName']);
            }
            
            if (data.containsKey('photoURL') && 
                data['photoURL'] != currentUser.photoURL) {
              await currentUser.updatePhotoURL(data['photoURL']);
            }
          } catch (e) {
            debugPrint('Erreur de mise à jour Firebase: $e');
          }
        }
        
        return await saveUserProfile(currentProfile);
      }
      return false;
    } catch (e) {
      debugPrint('Erreur de mise à jour de profil: $e');
      return false;
    }
  }

  // Vérifier si 2FA est activé
  Future<bool> is2FAEnabled() async {
    try {
      // Vérifier d'abord dans Firebase
      User? currentUser = _auth.currentUser;
      if (currentUser != null && 
          currentUser.phoneNumber != null && 
          currentUser.phoneNumber!.isNotEmpty) {
        return true;
      }
      
      // Vérifier aussi dans le stockage local
      Map<String, dynamic>? profile = await getUserProfile();
      return profile != null && profile['is2FAEnabled'] == true;
    } catch (e) {
      debugPrint('Erreur de vérification 2FA: $e');
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
      await prefs.setBool(_is2FAEnabledKey, true);
      return true;
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
      await prefs.setBool(_is2FAEnabledKey, false);
      return true;
    } catch (e) {
      debugPrint('Erreur de désactivation 2FA: $e');
      return false;
    }
  }
  
  // Mettre à jour les informations de profil utilisateur
  Future<bool> updateDisplayName(String displayName) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        
        // Mettre également à jour le profil local
        await updateUserProfile({
          'displayName': displayName,
        });
        
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Erreur de mise à jour du nom: $e');
      return false;
    }
  }
  
  // Obtenir le niveau de sécurité du compte (0-100)
  Future<int> getSecurityScore() async {
    try {
      int score = 0;
      
      // Vérifier si 2FA est activé
      bool twoFA = await is2FAEnabled();
      if (twoFA) {
        score += 50; // 2FA représente 50% du score de sécurité
      }
      
      // Vérifier si l'email est vérifié
      User? user = _auth.currentUser;
      if (user != null && user.emailVerified) {
        score += 30; // Email vérifié représente 30%
      }
      
      // Vérifier s'il y a une photo de profil (indique un compte plus actif)
      if (user != null && user.photoURL != null) {
        score += 10;
      }
      
      // Si compte existe depuis plus d'un mois (indique compte établi)
      if (user != null && user.metadata.creationTime != null) {
        final DateTime creationTime = user.metadata.creationTime!;
        final Duration accountAge = DateTime.now().difference(creationTime);
        if (accountAge.inDays > 30) {
          score += 10;
        }
      }
      
      return score;
    } catch (e) {
      debugPrint('Erreur de calcul du score de sécurité: $e');
      return 0;
    }
  }
}