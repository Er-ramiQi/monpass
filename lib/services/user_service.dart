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
      // Création du profil utilisateur par défaut
      Map<String, dynamic> defaultProfile = {
        'email': user.email ?? '',
        'displayName': user.displayName ?? 'Utilisateur',
        'phoneNumber': user.phoneNumber ?? '',
        'photoURL': user.photoURL,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'is2FAEnabled': false,
        'securityScore': 50, // Score initial
        'lastPasswordChange': DateTime.now().millisecondsSinceEpoch,
      };
      
      // Stockage du profil
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userProfileKey, jsonEncode(defaultProfile));
      
      // Stocker l'ID de l'utilisateur pour référence future
      await prefs.setString('user_id', user.uid);
      
      // Initialiser les paramètres de sécurité par défaut
      await prefs.setBool(_is2FAEnabledKey, false);
      
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
        
        if (needsUpdate) {
          profile['lastUpdated'] = DateTime.now().millisecondsSinceEpoch;
          await saveUserProfile(profile);
        }
      }
      
      return profile;
    } catch (e) {
      debugPrint('Error retrieving profile: $e');
      return null;
    }
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
        
        // Sync with Firebase if possible
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
      
      // Then check in Firebase
      User? currentUser = _auth.currentUser;
      bool firebaseEnabled = currentUser != null && 
          currentUser.phoneNumber != null && 
          currentUser.phoneNumber!.isNotEmpty;
          
      // If Firebase has it enabled, save that to preferences
      if (firebaseEnabled) {
        await prefs.setBool(_is2FAEnabledKey, true);
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error checking 2FA: $e');
      return false;
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
      return prefs.getString(_userPhoneNumberKey);
    } catch (e) {
      debugPrint('Error getting saved phone number: $e');
      return null;
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
      
      // Check if 2FA is enabled
      bool twoFA = await is2FAEnabled();
      if (twoFA) {
        score += 50; // 2FA represents 50% of security score
      }
      
      // Check if email is verified
      User? user = _auth.currentUser;
      if (user != null && user.emailVerified) {
        score += 30; // Verified email represents 30%
      }
      
      // Check if there's a profile picture (indicates more active account)
      if (user != null && user.photoURL != null) {
        score += 10;
      }
      
      // If account exists for more than a month (indicates established account)
      if (user != null && user.metadata.creationTime != null) {
        final DateTime creationTime = user.metadata.creationTime!;
        final Duration accountAge = DateTime.now().difference(creationTime);
        if (accountAge.inDays > 30) {
          score += 10;
        }
      }
      
      return score;
    } catch (e) {
      debugPrint('Error calculating security score: $e');
      return 0;
    }
  }
}