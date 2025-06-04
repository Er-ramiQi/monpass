// lib/services/user_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  // Keys for local storage
  static const String _userProfileKey = 'user_profile';
  static const String _is2FAEnabledKey = 'is_2fa_enabled';
  static const String _userPhoneNumberKey = 'user_phone_number';
  
  // Firebase Auth
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Créer un profil utilisateur initial après l'inscription
  Future<bool> createInitialProfile(User user) async {
    try {
      // Définir un numéro de téléphone par défaut pour la 2FA
      String defaultPhoneNumber = "+212703687923"; // Numéro par défaut
      
      // Création du profil utilisateur par défaut avec tous les nouveaux champs
      Map<String, dynamic> defaultProfile = {
        'email': user.email ?? '',
        'displayName': user.displayName ?? 'Utilisateur',
        'firstName': '',
        'lastName': '',
        'phoneNumber': defaultPhoneNumber,
        'birthDate': null,
        'gender': null,
        'photoURL': user.photoURL,
        'avatar': {
          'type': 'avatar',
          'iconCode': Icons.person_rounded.codePoint,
          'backgroundColor': 0xFF1E88E5,
          'name': 'Classique',
        },
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'is2FAEnabled': true, // Activer la 2FA par défaut
        'securityScore': 60, // Score initial avec 2FA mais profil incomplet
        'lastPasswordChange': DateTime.now().millisecondsSinceEpoch,
        'profileCompletionPercentage': 50, // Pourcentage initial avec email et avatar
      };
      
      // Stockage du profil
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userProfileKey, jsonEncode(defaultProfile));
      
      // Stocker l'ID de l'utilisateur pour référence future
      await prefs.setString('user_id', user.uid);
      
      // Sauvegarder le numéro de téléphone par défaut
      await savePhoneNumber(defaultPhoneNumber);
      
      // Initialiser les paramètres de sécurité par défaut avec 2FA activée
      await prefs.setBool(_is2FAEnabledKey, true);
      
      return true;
    } catch (e) {
      debugPrint('Error creating initial profile: $e');
      return false;
    }
  }

  // Get user profile from local storage
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? profileJson = prefs.getString(_userProfileKey);
      
      if (profileJson == null || profileJson.isEmpty) {
        // Create default profile if none exists
        User? currentUser = _auth.currentUser;
        
        if (currentUser == null) {
          return null;
        }
        
        // Créer un profil par défaut
        bool created = await createInitialProfile(currentUser);
        if (!created) {
          return null;
        }
        
        // Relire le profil nouvellement créé
        profileJson = prefs.getString(_userProfileKey);
        if (profileJson == null) {
          return null;
        }
      }
      
      Map<String, dynamic> profile = jsonDecode(profileJson) as Map<String, dynamic>;
      
      // Sync with Firebase if necessary
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
        
        // Get saved phone number if exists
        String? savedPhone = await getSavedPhoneNumber();
        if (savedPhone != null && savedPhone.isNotEmpty && profile['phoneNumber'] != savedPhone) {
          profile['phoneNumber'] = savedPhone;
          needsUpdate = true;
        }
        
        // Check 2FA status
        bool twoFAStatus = await is2FAEnabled();
        if (profile['is2FAEnabled'] != twoFAStatus) {
          profile['is2FAEnabled'] = twoFAStatus;
          needsUpdate = true;
        }
        
        // Ensure all new fields exist with default values
        if (!profile.containsKey('firstName')) {
          profile['firstName'] = '';
          needsUpdate = true;
        }
        if (!profile.containsKey('lastName')) {
          profile['lastName'] = '';
          needsUpdate = true;
        }
        if (!profile.containsKey('birthDate')) {
          profile['birthDate'] = null;
          needsUpdate = true;
        }
        if (!profile.containsKey('gender')) {
          profile['gender'] = null;
          needsUpdate = true;
        }
        if (!profile.containsKey('avatar')) {
          profile['avatar'] = {
            'type': 'avatar',
            'iconCode': Icons.person_rounded.codePoint,
            'backgroundColor': 0xFF1E88E5,
            'name': 'Classique',
          };
          needsUpdate = true;
        }
        
        // Update completion percentage
        int completionPercentage = _calculateCompletionPercentage(profile);
        if (profile['profileCompletionPercentage'] != completionPercentage) {
          profile['profileCompletionPercentage'] = completionPercentage;
          needsUpdate = true;
        }
        
        if (needsUpdate) {
          profile['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
          await saveUserProfile(profile);
        }
      }
      
      return profile;
    } catch (e) {
      debugPrint('Error retrieving profile: $e');
      return null;
    }
  }

  // Calculate profile completion percentage
  int _calculateCompletionPercentage(Map<String, dynamic> profile) {
    int completed = 0;
    int total = 6; // Total number of essential fields
    
    // Required fields
    if (profile['firstName']?.toString().isNotEmpty == true) completed++;
    if (profile['lastName']?.toString().isNotEmpty == true) completed++;
    if (profile['email']?.toString().isNotEmpty == true) completed++;
    if (profile['phoneNumber']?.toString().isNotEmpty == true) completed++;
    if (profile['birthDate'] != null) completed++;
    if (profile['avatar'] != null) completed++;
    
    return ((completed / total) * 100).round();
  }

  // Save user profile
  Future<bool> saveUserProfile(Map<String, dynamic> profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_userProfileKey, jsonEncode(profile));
    } catch (e) {
      debugPrint('Error saving profile: $e');
      return false;
    }
  }

  // Update user profile
  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    try {
      Map<String, dynamic>? currentProfile = await getUserProfile();
      if (currentProfile != null) {
        // Update fields
        currentProfile.addAll(data);
        
        // Update last modified date
        currentProfile['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
        
        // Update completion percentage
        currentProfile['profileCompletionPercentage'] = _calculateCompletionPercentage(currentProfile);
        
        // Update display name based on first and last name
        if (data.containsKey('firstName') || data.containsKey('lastName')) {
          String firstName = currentProfile['firstName']?.toString() ?? '';
          String lastName = currentProfile['lastName']?.toString() ?? '';
          if (firstName.isNotEmpty || lastName.isNotEmpty) {
            currentProfile['displayName'] = '$firstName $lastName'.trim();
          }
        }
        
        // Sync with Firebase if possible
        User? currentUser = _auth.currentUser;
        if (currentUser != null) {
          try {
            // Update display name in Firebase
            if (data.containsKey('displayName') && 
                data['displayName'] != currentUser.displayName) {
              await currentUser.updateDisplayName(data['displayName']);
            }
            
            // If phone number is updated, save it separately
            if (data.containsKey('phoneNumber') && data['phoneNumber'] != null) {
              await savePhoneNumber(data['phoneNumber']);
            }
          } catch (e) {
            debugPrint('Error updating Firebase: $e');
          }
        }
        
        return await saveUserProfile(currentProfile);
      }
      return false;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  // Check if 2FA is enabled
  Future<bool> is2FAEnabled() async {
    try {
      // First check with SharedPreferences for persistence
      final prefs = await SharedPreferences.getInstance();
      bool? storedValue = prefs.getBool(_is2FAEnabledKey);
      if (storedValue != null) {
        return storedValue;
      }
      
      // Par défaut, activer la 2FA pour tous les nouveaux utilisateurs
      await prefs.setBool(_is2FAEnabledKey, true);
      return true;
    } catch (e) {
      debugPrint('Error checking 2FA: $e');
      return true; // Par défaut activée
    }
  }

  // Enable 2FA
  Future<bool> enable2FA(String phoneNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save phone number
      await savePhoneNumber(phoneNumber);
      
      // Update profile
      Map<String, dynamic>? currentProfile = await getUserProfile();
      if (currentProfile != null) {
        currentProfile['phoneNumber'] = phoneNumber;
        currentProfile['is2FAEnabled'] = true;
        currentProfile['profileCompletionPercentage'] = _calculateCompletionPercentage(currentProfile);
        await saveUserProfile(currentProfile);
      }
      
      // Save 2FA status to preferences for faster access
      await prefs.setBool(_is2FAEnabledKey, true);
      return true;
    } catch (e) {
      debugPrint('Error enabling 2FA: $e');
      return false;
    }
  }

  // Disable 2FA
  Future<bool> disable2FA() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Update profile
      Map<String, dynamic>? currentProfile = await getUserProfile();
      if (currentProfile != null) {
        currentProfile['is2FAEnabled'] = false;
        currentProfile['profileCompletionPercentage'] = _calculateCompletionPercentage(currentProfile);
        await saveUserProfile(currentProfile);
      }
      
      // Save 2FA status
      await prefs.setBool(_is2FAEnabledKey, false);
      return true;
    } catch (e) {
      debugPrint('Error disabling 2FA: $e');
      return false;
    }
  }
  
  // Save user's phone number for future use
  Future<bool> savePhoneNumber(String phoneNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_userPhoneNumberKey, phoneNumber);
    } catch (e) {
      debugPrint('Error saving phone number: $e');
      return false;
    }
  }
  
  // Get saved phone number
  Future<String?> getSavedPhoneNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedPhone = prefs.getString(_userPhoneNumberKey);
      
      // Si aucun numéro sauvegardé, retourner le numéro par défaut
      if (savedPhone == null || savedPhone.isEmpty) {
        return "+212703687923"; // Numéro par défaut
      }
      
      return savedPhone;
    } catch (e) {
      debugPrint('Error getting saved phone number: $e');
      return "+212703687923"; // Numéro par défaut en cas d'erreur
    }
  }
  
  // Update display name
  Future<bool> updateDisplayName(String displayName) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        
        // Also update local profile
        await updateUserProfile({
          'displayName': displayName,
        });
        
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating name: $e');
      return false;
    }
  }
  
  // Get account security score (0-100)
  Future<int> getSecurityScore() async {
    try {
      int score = 0;
      
      Map<String, dynamic>? profile = await getUserProfile();
      if (profile == null) return 0;
      
      // Check if 2FA is enabled (50 points)
      bool twoFA = await is2FAEnabled();
      if (twoFA) {
        score += 50;
      }
      
      // Check if email is verified (20 points)
      User? user = _auth.currentUser;
      if (user != null && user.emailVerified) {
        score += 20;
      }
      
      // Check profile completion (20 points)
      int completion = profile['profileCompletionPercentage'] ?? 0;
      score += (completion * 0.2).round();
      
      // Check if account exists for more than a month (10 points)
      if (user != null && user.metadata.creationTime != null) {
        final DateTime creationTime = user.metadata.creationTime!;
        final Duration accountAge = DateTime.now().difference(creationTime);
        if (accountAge.inDays > 30) {
          score += 10;
        }
      }
      
      return score > 100 ? 100 : score;
    } catch (e) {
      debugPrint('Error calculating security score: $e');
      return 50; // Score par défaut avec 2FA
    }
  }

  // Get profile completion status
  Future<Map<String, dynamic>> getProfileCompletionStatus() async {
    try {
      Map<String, dynamic>? profile = await getUserProfile();
      if (profile == null) {
        return {
          'percentage': 0,
          'isComplete': false,
          'missingFields': [],
        };
      }
      
      List<String> missingFields = [];
      
      if (profile['firstName']?.toString().isEmpty ?? true) {
        missingFields.add('Prénom');
      }
      if (profile['lastName']?.toString().isEmpty ?? true) {
        missingFields.add('Nom de famille');
      }
      if (profile['birthDate'] == null) {
        missingFields.add('Date de naissance');
      }
      if (profile['phoneNumber']?.toString().isEmpty ?? true) {
        missingFields.add('Téléphone');
      }
      if (profile['avatar'] == null) {
        missingFields.add('Avatar');
      }
      
      int percentage = profile['profileCompletionPercentage'] ?? 0;
      bool isComplete = percentage >= 90; // Consider 90%+ as complete
      
      return {
        'percentage': percentage,
        'isComplete': isComplete,
        'missingFields': missingFields,
      };
    } catch (e) {
      debugPrint('Error getting completion status: $e');
      return {
        'percentage': 0,
        'isComplete': false,
        'missingFields': [],
      };
    }
  }

  // Update avatar
  Future<bool> updateAvatar(Map<String, dynamic> avatarData) async {
    try {
      return await updateUserProfile({
        'avatar': avatarData,
      });
    } catch (e) {
      debugPrint('Error updating avatar: $e');
      return false;
    }
  }

  // Clear all user data (for logout)
  Future<bool> clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userProfileKey);
      await prefs.remove(_is2FAEnabledKey);
      await prefs.remove(_userPhoneNumberKey);
      return true;
    } catch (e) {
      debugPrint('Error clearing user data: $e');
      return false;
    }
  }
}