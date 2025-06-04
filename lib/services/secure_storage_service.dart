// lib/services/secure_storage_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:uuid/uuid.dart';

class SecureStorageService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
  
  // Clé de chiffrement dérivée du mot de passe master
  encrypt.Key? _encryptionKey;
  encrypt.IV? _iv;
  String? _salt;

  // Définir une clé d'encryption avec dérivation sécurisée
  Future<void> setMasterPassword(String masterPassword) async {
    // Générer ou récupérer un sel unique pour l'utilisateur
    _salt = await _secureStorage.read(key: 'master_password_salt');
    if (_salt == null) {
      _salt = const Uuid().v4();
      await _secureStorage.write(key: 'master_password_salt', value: _salt);
    }
    
    // Dériver une clé de chiffrement forte à partir du mot de passe master
    final derivedKey = _deriveKeyFromPassword(masterPassword, _salt!);
_encryptionKey = encrypt.Key(Uint8List.fromList(derivedKey));
    
    // Générer ou récupérer un IV unique
    String? ivString = await _secureStorage.read(key: 'encryption_iv');
    if (ivString == null) {
      _iv = encrypt.IV.fromSecureRandom(16);
      await _secureStorage.write(key: 'encryption_iv', value: base64.encode(_iv!.bytes));
    } else {
      _iv = encrypt.IV(base64.decode(ivString));
    }
    
    // Stocker un hash du mot de passe pour vérification
    await _secureStorage.write(
      key: 'master_password_hash', 
      value: sha256.convert(utf8.encode(masterPassword + _salt!)).toString()
    );
  }

  // Vérifier si le mot de passe master est correct
  Future<bool> verifyMasterPassword(String masterPassword) async {
    String? storedHash = await _secureStorage.read(key: 'master_password_hash');
    String? salt = await _secureStorage.read(key: 'master_password_salt');
    
    if (storedHash == null || salt == null) return false;
    
    String inputHash = sha256.convert(utf8.encode(masterPassword + salt)).toString();
    return storedHash == inputHash;
  }

  // Dériver une clé de chiffrement avec PBKDF2 (simulé ici avec plusieurs itérations de SHA-256)
  List<int> _deriveKeyFromPassword(String password, String salt) {
    // Simuler PBKDF2 avec plusieurs itérations
    List<int> key = utf8.encode(password + salt);
    for (int i = 0; i < 10000; i++) {
      key = sha256.convert(key).bytes;
    }
    return key.sublist(0, 32); // 256 bits pour AES-256
  }

  // Lire une valeur
  Future<String?> read(String key) async {
    return await _secureStorage.read(key: key);
  }

  // Écrire une valeur
  Future<void> write(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  // Supprimer une valeur
  Future<void> delete(String key) async {
    await _secureStorage.delete(key: key);
  }

  // Vider le stockage
  Future<void> deleteAll() async {
    await _secureStorage.deleteAll();
  }

  // Stocker un objet chiffré (pour les mots de passe)
  Future<bool> writeEncrypted(String key, Map<String, dynamic> data) async {
    if (_encryptionKey == null || _iv == null) {
      throw Exception('Encryption key not set. Call setMasterPassword first.');
    }
    
    try {
      // Convertir en JSON puis chiffrer avec AES-256
      String jsonData = jsonEncode(data);
      
      // Chiffrement AES en mode CBC
      final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey!));
      final encrypted = encrypter.encrypt(jsonData, iv: _iv!);
      
      await _secureStorage.write(key: key, value: encrypted.base64);
      return true;
    } catch (e) {
      debugPrint('Error writing encrypted data: $e');
      return false;
    }
  }

  // Lire et déchiffrer un objet
  Future<Map<String, dynamic>?> readEncrypted(String key) async {
    if (_encryptionKey == null || _iv == null) {
      throw Exception('Encryption key not set. Call setMasterPassword first.');
    }
    
    try {
      String? encryptedData = await _secureStorage.read(key: key);
      if (encryptedData == null) return null;
      
      // Déchiffrer avec AES-256
      final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey!));
      final decrypted = encrypter.decrypt64(encryptedData, iv: _iv!);
      
      return jsonDecode(decrypted) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error reading encrypted data: $e');
      return null;
    }
  }
  
  // Vérifier si un verrouillage biométrique est configuré et disponible
  Future<bool> isBiometricAvailable() async {
    try {
      final biometricsEnabled = await _secureStorage.read(key: 'biometrics_enabled');
      return biometricsEnabled == 'true';
    } catch (e) {
      return false;
    }
  }
  
  // Activer/désactiver la biométrie
  Future<void> setBiometricsEnabled(bool enabled) async {
    await _secureStorage.write(key: 'biometrics_enabled', value: enabled ? 'true' : 'false');
  }
}