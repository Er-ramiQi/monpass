import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:monpass/services/two_factor_service.dart.dart'; // Assurez-vous que ce chemin est correct
import 'package:pin_code_fields/pin_code_fields.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({Key? key}) : super(key: key);

  @override
  _OtpVerificationScreenState createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TwoFactorService _twoFactorService = TwoFactorService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  
  bool _isLoading = false;
  bool _codeSent = false;
  String? _errorMessage;
  User? _user;

  // Couleurs du thème
  final Color _primaryColor = Colors.blue;
  final Color _backgroundColor = Colors.white;
  final Color _errorColor = Colors.red.shade400;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Récupérer l'utilisateur passé depuis l'écran de connexion
    final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (arguments != null && arguments.containsKey('user')) {
      _user = arguments['user'] as User?;
    }
  }

  // Envoyer un code OTP au numéro de téléphone
  Future<void> _sendOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String phoneNumber = _phoneController.text.trim();
    
    // Vérifier si le numéro de téléphone commence par un +
    if (!phoneNumber.startsWith('+')) {
      phoneNumber = '+$phoneNumber';
    }

    try {
      await _twoFactorService.sendOtpToPhone(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId) {
          setState(() {
            _codeSent = true;
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Code envoyé à $phoneNumber'),
              backgroundColor: _primaryColor,
            ),
          );
        },
        onVerificationFailed: (e) {
          setState(() {
            _isLoading = false;
            _errorMessage = e.message ?? 'Erreur lors de l\'envoi du code';
          });
        },
        onVerificationCompleted: (credential) async {
          // Auto-vérification sur Android (rare pour 2FA)
          try {
            bool success = await _twoFactorService.verifyOtpCode(
              smsCode: credential.smsCode ?? '',
            );
            
            if (success && mounted) {
              _navigateToHome();
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'Erreur d\'authentification: $e';
              });
            }
          }
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur: $e';
      });
    }
  }

  // Vérifier le code OTP saisi
  Future<void> _verifyOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      bool success = await _twoFactorService.verifyOtpCode(
        smsCode: _otpController.text.trim(),
      );
      
      if (success && mounted) {
        _navigateToHome();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Code incorrect. Veuillez réessayer.';
      });
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  // Si l'utilisateur annule la vérification à deux facteurs
  void _cancelTwoFactor() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _twoFactorService.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors de la déconnexion: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Empêcher le retour en arrière sans déconnexion
        _cancelTwoFactor();
        return false;
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          title: const Text('Vérification en deux étapes'),
          backgroundColor: _primaryColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _cancelTwoFactor,
          ),
        ),
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    
                    // Logo ou icône de l'application
                    Icon(
                      _codeSent ? Icons.message : Icons.phone_android,
                      size: 70,
                      color: _primaryColor,
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Titre
                    Text(
                      _codeSent 
                          ? 'Vérification du code' 
                          : 'Authentification à deux facteurs',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Description
                    Text(
                      _codeSent
                          ? 'Veuillez saisir le code à 6 chiffres que nous avons envoyé à votre téléphone'
                          : 'Pour renforcer la sécurité de votre compte, veuillez entrer votre numéro de téléphone pour recevoir un code de vérification',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Afficher l'email de l'utilisateur
                    if (_user != null && _user!.email != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_circle, size: 24, color: Colors.blue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Connecté en tant que: ${_user!.email}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                    
                    // Message d'erreur
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _errorColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _errorColor, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: _errorColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: _errorColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    // Formulaire
                    if (!_codeSent) ...[
                      // Saisie du numéro de téléphone
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Numéro de téléphone',
                          hintText: '+33612345678',
                          prefixIcon: const Icon(Icons.phone),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _primaryColor, width: 2),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Saisie du code OTP
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: PinCodeTextField(
                          appContext: context,
                          length: 6,
                          obscureText: false,
                          controller: _otpController,
                          animationType: AnimationType.fade,
                          keyboardType: TextInputType.number,
                          pinTheme: PinTheme(
                            shape: PinCodeFieldShape.box,
                            borderRadius: BorderRadius.circular(12),
                            fieldHeight: 55,
                            fieldWidth: 45,
                            activeFillColor: Colors.white,
                            inactiveFillColor: Colors.white,
                            selectedFillColor: Colors.blue.shade50,
                            activeColor: _primaryColor,
                            inactiveColor: Colors.grey.shade300,
                            selectedColor: _primaryColor,
                          ),
                          animationDuration: const Duration(milliseconds: 300),
                          enableActiveFill: true,
                          onCompleted: (v) {
                            _verifyOtp();
                          },
                          onChanged: (value) {},
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 30),
                    
                    // Bouton d'action principal
                    ElevatedButton(
                      onPressed: _isLoading 
                          ? null 
                          : (_codeSent ? _verifyOtp : _sendOtp),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: _primaryColor.withOpacity(0.5),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _codeSent ? 'Vérifier le code' : 'Envoyer le code',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Bouton secondaire
                    if (_codeSent)
                      TextButton.icon(
                        onPressed: _isLoading ? null : () {
                          setState(() {
                            _codeSent = false;
                            _otpController.clear();
                          });
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Changer de numéro'),
                        style: TextButton.styleFrom(
                          foregroundColor: _primaryColor,
                        ),
                      ),
                    
                    const SizedBox(height: 20),
                    
                    // Option pour ignorer cette étape (à utiliser avec précaution)
                    TextButton(
                      onPressed: _isLoading 
                        ? null 
                        : () {
                          // Dans une implémentation réelle, vous pourriez vouloir limiter cette option
                          // ou la désactiver complètement pour des raisons de sécurité
                          _navigateToHome();
                        },
                      child: const Text('Ignorer cette étape pour cette fois'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}