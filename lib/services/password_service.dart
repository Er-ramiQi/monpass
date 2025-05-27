import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/password_model.dart';
import 'secure_storage_service.dart';
import 'dart:math';

class PasswordService {
  final SecureStorageService _secureStorage;
  final String _userId;
  final random = Random.secure();

  // Liste en mémoire des mots de passe
  List<PasswordModel> _passwords = [];
  bool _isInitialized = false;

  PasswordService(this._secureStorage, this._userId);

  // Initialiser le service avec les mots de passe stockés
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _loadPasswords();
    _isInitialized = true;
  }

  // Charger tous les mots de passe
  Future<void> _loadPasswords() async {
    try {
      String? passwordsJson = await _secureStorage.read('passwords_$_userId');
      if (passwordsJson == null || passwordsJson.isEmpty) {
        _passwords = [];
        return;
      }

      List<dynamic> decodedList = jsonDecode(passwordsJson);
      _passwords =
          decodedList.map((item) => PasswordModel.fromMap(item)).toList();
    } catch (e) {
      debugPrint('Erreur de chargement des mots de passe: $e');
      _passwords = [];
    }
  }

  // Sauvegarder tous les mots de passe
  Future<bool> _savePasswords() async {
    try {
      List<Map<String, dynamic>> passwordMaps =
          _passwords.map((password) => password.toMap()).toList();

      String passwordsJson = jsonEncode(passwordMaps);
      await _secureStorage.write('passwords_$_userId', passwordsJson);
      return true;
    } catch (e) {
      debugPrint('Erreur de sauvegarde des mots de passe: $e');
      return false;
    }
  }

  // Obtenir tous les mots de passe
  Future<List<PasswordModel>> getAllPasswords() async {
    if (!_isInitialized) await initialize();
    return List.from(_passwords);
  }

  // Obtenir un mot de passe par ID
  Future<PasswordModel?> getPasswordById(String id) async {
    if (!_isInitialized) await initialize();
    try {
      return _passwords.firstWhere((password) => password.id == id);
    } catch (e) {
      return null;
    }
  }

  // Ajouter un nouveau mot de passe
  Future<bool> addPassword(PasswordModel password) async {
    if (!_isInitialized) await initialize();

    try {
      // S'assurer qu'il y a un ID unique
      if (password.id.isEmpty) {
        password = password.copyWith(id: const Uuid().v4());
      }

      _passwords.add(password);
      return await _savePasswords();
    } catch (e) {
      debugPrint('Erreur d\'ajout de mot de passe: $e');
      return false;
    }
  }

  // Mettre à jour un mot de passe existant
  Future<bool> updatePassword(PasswordModel updatedPassword) async {
    if (!_isInitialized) await initialize();

    try {
      int index = _passwords.indexWhere((p) => p.id == updatedPassword.id);
      if (index == -1) return false;

      _passwords[index] = updatedPassword.copyWith(updatedAt: DateTime.now());

      return await _savePasswords();
    } catch (e) {
      debugPrint('Erreur de mise à jour de mot de passe: $e');
      return false;
    }
  }

  // Supprimer un mot de passe
  Future<bool> deletePassword(String id) async {
    if (!_isInitialized) await initialize();

    try {
      _passwords.removeWhere((password) => password.id == id);
      return await _savePasswords();
    } catch (e) {
      debugPrint('Erreur de suppression de mot de passe: $e');
      return false;
    }
  }

  // Marquer un mot de passe comme favori
  Future<bool> toggleFavorite(String id) async {
    if (!_isInitialized) await initialize();

    try {
      int index = _passwords.indexWhere((p) => p.id == id);
      if (index == -1) return false;

      PasswordModel password = _passwords[index];
      _passwords[index] = password.copyWith(
        isFavorite: !password.isFavorite,
        updatedAt: DateTime.now(),
      );

      return await _savePasswords();
    } catch (e) {
      debugPrint('Erreur de marquage de favori: $e');
      return false;
    }
  }

  // Recherche de mots de passe
  Future<List<PasswordModel>> searchPasswords(String query) async {
    if (!_isInitialized) await initialize();

    query = query.toLowerCase();
    return _passwords.where((password) {
      return password.title.toLowerCase().contains(query) ||
          password.username.toLowerCase().contains(query) ||
          password.website.toLowerCase().contains(query);
    }).toList();
  }

  // Générer un mot de passe aléatoire
  String generatePassword({
    int length = 16,
    bool includeUppercase = true,
    bool includeLowercase = true,
    bool includeNumbers = true,
    bool includeSpecial = true,
    bool avoidAmbiguous = false,
  }) {
    const String uppercaseChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const String lowercaseChars = 'abcdefghijklmnopqrstuvwxyz';
    const String numberChars = '0123456789';
    const String specialChars = '!@#\$%^&*()_-+=[]{}|;:,.<>?';

    // Ambiguous characters that can be confused with others
    const String ambiguousChars = 'l1IO0';

    String chars = '';
    if (includeUppercase) chars += uppercaseChars;
    if (includeLowercase) chars += lowercaseChars;
    if (includeNumbers) chars += numberChars;
    if (includeSpecial) chars += specialChars;

    // Remove ambiguous characters if requested
    if (avoidAmbiguous) {
      for (var c in ambiguousChars.split('')) {
        chars = chars.replaceAll(c, '');
      }
    }

    // Ensure at least one character set is included
    if (chars.isEmpty) {
      chars = lowercaseChars + numberChars;
    }

    // Generate password
    final random = Random.secure();
    String password = '';

    // Ensure at least one of each required character type
    if (includeUppercase && length >= 1) {
      final randomIndex = random.nextInt(uppercaseChars.length);
      password += uppercaseChars[randomIndex];
    }

    if (includeLowercase && length >= password.length + 1) {
      final randomIndex = random.nextInt(lowercaseChars.length);
      password += lowercaseChars[randomIndex];
    }

    if (includeNumbers && length >= password.length + 1) {
      final randomIndex = random.nextInt(numberChars.length);
      password += numberChars[randomIndex];
    }

    if (includeSpecial && length >= password.length + 1) {
      final randomIndex = random.nextInt(specialChars.length);
      password += specialChars[randomIndex];
    }

    // Fill the rest with random characters
    while (password.length < length) {
      final randomIndex = random.nextInt(chars.length);
      password += chars[randomIndex];
    }

    // Shuffle the password to avoid predictable patterns
    final passwordChars = password.split('');
    passwordChars.shuffle(random);

    return passwordChars.join('');
  }
}
