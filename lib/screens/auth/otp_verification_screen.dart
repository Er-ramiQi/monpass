import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:monpass/services/auth_service.dart';
import 'package:monpass/screens/home/home_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final User? user;
  final bool isRegistration; // true si c'est l'activation initiale, false si c'est une connexion

  const OtpVerificationScreen({
    Key? key,
    required this.user,
    this.isRegistration = false,
  }) : super(key: key);

  @override
  _OtpVerificationScreenState createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  bool _isLoading = false;
  bool _codeSent = false;
  String? _errorMessage;
  String? _verificationId;

  @override
  void dispose() {
    _otpController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Envoyer le code OTP
  Future<void> _sendOtp() async {
    if (_phoneController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Veuillez entrer un numéro de téléphone';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String phoneNumber = _phoneController.text.trim();
    // Formater le numéro de téléphone
    if (!phoneNumber.startsWith('+')) {
      phoneNumber = '+$phoneNumber';
    }

    try {
      _verificationId = await _authService.sendOtpToPhone(
        phoneNumber: phoneNumber,
        onVerificationCompleted: (credential) async {
          // Vérification automatique (Android uniquement)
          if (widget.isRegistration) {
            // Activation de 2FA
            await _authService.verifyOtp(_verificationId!, credential.smsCode ?? '');
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomeScreen()),
              );
            }
          } else {
            // Connexion avec 2FA
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomeScreen()),
              );
            }
          }
        },
        onVerificationFailed: (e) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Erreur: ${e.message ?? e.code}';
          });
        },
      );

      if (_verificationId != null) {
        setState(() {
          _codeSent = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur d\'envoi du code. Veuillez réessayer.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur: $e';
      });
    }
  }

  // Vérifier le code OTP
  Future<void> _verifyOtp() async {
    if (_otpController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Veuillez entrer le code OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      bool success = await _authService.verifyOtp(
        _verificationId!,
        _otpController.text.trim(),
      );

      if (success) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen()),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Vérification échouée. Veuillez réessayer.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Code incorrect. Veuillez réessayer.';
      });
    }
  }

  // Annuler l'authentification
  void _cancel() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Empêcher le retour arrière accidentel
        _cancel();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isRegistration 
              ? 'Activer la vérification en deux étapes'
              : 'Vérification en deux étapes'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: _cancel,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    _codeSent ? Icons.sms_outlined : Icons.phone_android_outlined,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    _codeSent 
                        ? 'Entrez le code de vérification'
                        : 'Entrez votre numéro de téléphone',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    _codeSent
                        ? 'Nous avons envoyé un code à votre numéro de téléphone.'
                        : 'Nous vous enverrons un code de vérification par SMS.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Message d'erreur
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade800, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Formulaire
                  if (!_codeSent) ...[
                    // Champ Numéro de téléphone
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Numéro de téléphone',
                        hintText: '+33612345678',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    ElevatedButton(
                      onPressed: _isLoading ? null : _sendOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Envoyer le code',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ] else ...[
                    // Champ OTP
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: PinCodeTextField(
                        appContext: context,
                        length: 6,
                        obscureText: false,
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        animationType: AnimationType.fade,
                        pinTheme: PinTheme(
                          shape: PinCodeFieldShape.box,
                          borderRadius: BorderRadius.circular(10),
                          fieldHeight: 50,
                          fieldWidth: 40,
                          activeFillColor: Colors.white,
                          inactiveFillColor: Colors.white,
                          selectedFillColor: Colors.grey[100],
                          activeColor: Theme.of(context).primaryColor,
                          inactiveColor: Colors.grey[400],
                          selectedColor: Theme.of(context).primaryColor,
                        ),
                        enableActiveFill: true,
                        onCompleted: (v) {
                          _verifyOtp();
                        },
                        onChanged: (value) {
                          // Ne rien faire
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Vérifier',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                    
                    TextButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _codeSent = false;
                                _otpController.clear();
                              });
                            },
                      icon: Icon(Icons.arrow_back),
                      label: Text('Changer de numéro'),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Si c'est une authentification (pas une activation)
                  if (!widget.isRegistration) ...[
                    TextButton(
                      onPressed: () {
                        // Ignorer 2FA uniquement pour cette session (pas recommandé en production)
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => HomeScreen()),
                        );
                      },
                      child: Text('Ignorer cette étape pour cette fois'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}