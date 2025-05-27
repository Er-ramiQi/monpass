// lib/screens/settings/security_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:monpass/services/auth_service.dart';
import 'package:monpass/services/user_service.dart';
import 'package:monpass/screens/auth/otp_verification_screen.dart';

class SecuritySettingsScreen extends StatefulWidget {
  final bool is2FAEnabled;
  
  const SecuritySettingsScreen({
    super.key,
    required this.is2FAEnabled,
  });

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  
  bool _isLoading = false;
  bool _is2FAEnabled = false;
  String? _phoneNumber;

  @override
  void initState() {
    super.initState();
    _is2FAEnabled = widget.is2FAEnabled;
    _loadPhoneNumber();
  }
  
  Future<void> _loadPhoneNumber() async {
    String? phone = await _userService.getSavedPhoneNumber();
    setState(() {
      _phoneNumber = phone;
    });
  }

  Future<void> _toggle2FA(bool value) async {
    if (value == _is2FAEnabled) return;
    
    if (value) {
      // Enable 2FA
      final user = _authService.currentUser;
      if (user != null) {
        Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              isSetup: true,
              phoneNumber: _phoneNumber,
            ),
          ),
        ).then((result) {
          // Refresh 2FA status when returning from OTP screen
          _checkStatus();
        });
      }
    } else {
      // Disable 2FA
      _showDisable2FADialog();
    }
  }
  
  Future<void> _checkStatus() async {
    bool status = await _userService.is2FAEnabled();
    setState(() {
      _is2FAEnabled = status;
    });
  }

  Future<void> _disable2FA() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      bool result = await _userService.disable2FA();
      if (result) {
        setState(() {
          _is2FAEnabled = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showDisable2FADialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Désactiver l\'authentification à deux facteurs?'),
        content: const Text(
          'Cela rendra votre compte moins sécurisé. Êtes-vous sûr de vouloir continuer?'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _disable2FA();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres de sécurité'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Authentification à deux facteurs',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _is2FAEnabled
                                    ? Icons.verified_user
                                    : Icons.security,
                                color: _is2FAEnabled
                                    ? Colors.green
                                    : Theme.of(context).primaryColor,
                                size: 30,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _is2FAEnabled
                                          ? 'Authentification à deux facteurs activée'
                                          : 'Authentification à deux facteurs désactivée',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _is2FAEnabled
                                          ? 'Votre compte est protégé par une vérification en deux étapes'
                                          : 'Activez la vérification en deux étapes pour une sécurité renforcée',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (_phoneNumber != null && _is2FAEnabled) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Numéro associé: $_phoneNumber',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text(
                              'Activer l\'authentification à deux facteurs',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            value: _is2FAEnabled,
                            onChanged: _toggle2FA,
                            activeColor: Theme.of(context).primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 2FA Information
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'À propos de l\'authentification à deux facteurs',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'L\'authentification à deux facteurs ajoute une couche de sécurité supplémentaire à votre compte en exigeant un code de vérification envoyé à votre téléphone en plus de votre mot de passe.',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}