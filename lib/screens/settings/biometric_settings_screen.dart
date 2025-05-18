// lib/screens/settings/biometric_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/biometric_service.dart';

class BiometricSettingsScreen extends StatefulWidget {
  const BiometricSettingsScreen({super.key});

  @override
  State<BiometricSettingsScreen> createState() => _BiometricSettingsScreenState();
}

class _BiometricSettingsScreenState extends State<BiometricSettingsScreen> {
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  bool _isLoading = true;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _loadBiometricSettings();
  }

  Future<void> _loadBiometricSettings() async {
    setState(() {
      _isLoading = true;
    });

    bool isAvailable = await BiometricService.isBiometricAvailable();
    bool isEnabled = false;
    List<BiometricType> availableBiometrics = [];

    if (isAvailable) {
      isEnabled = await BiometricService.isBiometricEnabled();
      availableBiometrics = await BiometricService.getAvailableBiometrics();
    }

    setState(() {
      _isBiometricAvailable = isAvailable;
      _isBiometricEnabled = isEnabled;
      _availableBiometrics = availableBiometrics;
      _isLoading = false;
    });
  }

  String _getBiometricTypeText() {
    if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Empreinte digitale';
    } else if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Reconnaissance faciale';
    } else if (_availableBiometrics.contains(BiometricType.iris)) {
      return 'Scan de l\'iris';
    } else if (_availableBiometrics.contains(BiometricType.strong)) {
      return 'Biométrie avancée';
    } else if (_availableBiometrics.contains(BiometricType.weak)) {
      return 'Biométrie basique';
    }
    return 'Inconnu';
  }

  Future<void> _toggleBiometricAuth(bool value) async {
    if (value) {
      // Si on active, vérifier que l'utilisateur peut s'authentifier
      bool authenticated = await BiometricService.authenticateWithBiometrics();
      if (authenticated) {
        await BiometricService.setBiometricEnabled(true);
        setState(() {
          _isBiometricEnabled = true;
        });
      }
    } else {
      // Si on désactive, juste désactiver
      await BiometricService.setBiometricEnabled(false);
      
      // Supprimer les identifiants enregistrés
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_email');
      await prefs.remove('user_password');
      
      setState(() {
        _isBiometricEnabled = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Authentification biométrique'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isBiometricAvailable) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber.shade800,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Votre appareil ne prend pas en charge l\'authentification biométrique',
                              style: TextStyle(color: Colors.amber.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              leading: Icon(
                                Icons.fingerprint,
                                color: Theme.of(context).colorScheme.primary,
                                size: 40,
                              ),
                              title: const Text(
                                'Connexion biométrique',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Utiliser ${_getBiometricTypeText()} pour vous connecter rapidement à votre compte',
                              ),
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              title: const Text('Activer l\'authentification biométrique'),
                              value: _isBiometricEnabled,
                              onChanged: _toggleBiometricAuth,
                              activeColor: Theme.of(context).colorScheme.primary,
                            ),
                            if (_isBiometricEnabled) ...[
                              const Divider(),
                              ListTile(
                                leading: const Icon(Icons.security),
                                title: const Text('Vérifier l\'authentification'),
                                subtitle: const Text(
                                  'Testez votre authentification biométrique',
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () async {
                                  bool authenticated = await BiometricService.authenticateWithBiometrics();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          authenticated
                                              ? 'Authentification réussie!'
                                              : 'Authentification échouée',
                                        ),
                                        backgroundColor: authenticated ? Colors.green : Colors.red,
                                      ),
                                    );
                                  }
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.delete_outline),
                                title: const Text('Supprimer les données biométriques'),
                                subtitle: const Text(
                                  'Effacer les identifiants stockés pour l\'authentification biométrique',
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () async {
                                  bool confirm = await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Supprimer les données biométriques?'),
                                      content: const Text(
                                        'Cela désactivera l\'authentification biométrique. Vous devrez la reconfigurer pour l\'utiliser à nouveau.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Annuler'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Supprimer'),
                                        ),
                                      ],
                                    ),
                                  ) ?? false;

                                  if (confirm) {
                                    await _toggleBiometricAuth(false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Données biométriques supprimées'),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade800,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'L\'authentification biométrique utilise les systèmes de sécurité de votre appareil. Aucune donnée biométrique n\'est stockée par l\'application.',
                              style: TextStyle(color: Colors.blue.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}