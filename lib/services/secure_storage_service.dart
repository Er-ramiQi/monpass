import 'dart:convert';
import 'package:flutter/foundation.dart'; // Ajout de cet import pour debugPrint
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

class SecureStorageService {
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  // Clé de chiffrement dérivée du mot de passe master
  String? _encryptionKey;

  // Définir une clé d'encryption
  Future<void> setMasterPassword(String masterPassword) async {
    // Dériver une clé de chiffrement à partir du mot de passe master
    _encryptionKey = _deriveKeyFromPassword(masterPassword);
    // Stocker un hash du mot de passe pour vérification
    await _secureStorage.write(
      key: 'master_password_hash', 
      value: sha256.convert(utf8.encode(masterPassword)).toString()
    );
  }

  // Vérifier si le mot de passe master est correct
  Future<bool> verifyMasterPassword(String masterPassword) async {
    String? storedHash = await _secureStorage.read(key: 'master_password_hash');
    if (storedHash == null) return false;
    
    String inputHash = sha256.convert(utf8.encode(masterPassword)).toString();
    return storedHash == inputHash;
  }

  // Dériver une clé de chiffrement à partir du mot de passe
  String _deriveKeyFromPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
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
    if (_encryptionKey == null) {
      throw Exception('Encryption key not set. Call setMasterPassword first.');
    }
    
    try {
      // Convertir en JSON puis chiffrer avec la clé
      String jsonData = jsonEncode(data);
      
      // Simuler un chiffrement basique (remplacer par un vrai chiffrement en production)
      String encryptedData = _simpleEncrypt(jsonData, _encryptionKey!);
      
      await _secureStorage.write(key: key, value: encryptedData);
      return true;
    } catch (e) {
      debugPrint('Error writing encrypted data: $e');
      return false;
    }
  }

  // Lire et déchiffrer un objet
  Future<Map<String, dynamic>?> readEncrypted(String key) async {
    if (_encryptionKey == null) {
      throw Exception('Encryption key not set. Call setMasterPassword first.');
    }
    
    try {
      String? encryptedData = await _secureStorage.read(key: key);
      if (encryptedData == null) return null;
      
      // Déchiffrer
      String decryptedData = _simpleDecrypt(encryptedData, _encryptionKey!);
      
      return jsonDecode(decryptedData) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error reading encrypted data: $e');
      return null;
    }
  }
  
  // Méthode simplifiée d'encryption (pour démonstration - à remplacer par une vraie implémentation)
  String _simpleEncrypt(String data, String key) {
    // Dans une vraie application, utilisez un algorithme comme AES
    // Ceci est une simulation de chiffrement pour l'exemple
    List<int> dataBytes = utf8.encode(data);
    List<int> keyBytes = utf8.encode(key);
    
    // XOR basique (NE PAS UTILISER EN PRODUCTION)
    List<int> encrypted = [];
    for (int i = 0; i < dataBytes.length; i++) {
      encrypted.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    
    return base64.encode(encrypted);
  }

  // Méthode simplifiée de décryption
  String _simpleDecrypt(String encryptedData, String key) {
    // Inverse de la méthode encrypt ci-dessus
    List<int> encryptedBytes = base64.decode(encryptedData);
    List<int> keyBytes = utf8.encode(key);
    
    List<int> decrypted = [];
    for (int i = 0; i < encryptedBytes.length; i++) {
      decrypted.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    
    return utf8.decode(decrypted);
  }
}