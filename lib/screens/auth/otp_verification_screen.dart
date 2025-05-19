// lib/screens/auth/otp_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:monpass/services/phone_auth_service.dart';
import 'package:monpass/services/user_service.dart';
import 'package:monpass/services/auth_service.dart';
import 'package:monpass/screens/password/password_list_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final bool isSetup; // true if 2FA setup, false if verification
  final String? phoneNumber; // Pre-filled phone number if available
  
  const OtpVerificationScreen({
    super.key,
    this.isSetup = false,
    this.phoneNumber,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final PhoneAuthService _phoneAuthService = PhoneAuthService();
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  bool _isLoading = false;
  bool _codeSent = false;
  bool _isResending = false;
  int _resendCountdown = 60;
  String? _errorMessage;
  String? _verificationId;
  
  // For smooth error animation
  final _errorAnimationController = GlobalKey();
  
  @override
  void initState() {
    super.initState();
    
    _loadPhoneNumber();
  }
  
  Future<void> _loadPhoneNumber() async {
    // Try to get saved phone number if not provided
    if (widget.phoneNumber != null && widget.phoneNumber!.isNotEmpty) {
      _phoneController.text = widget.phoneNumber!;
      
      // Auto-send OTP if phone number is valid
      if (_isValidPhoneNumber(widget.phoneNumber!)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _sendOtp();
        });
      }
    } else {
      // Try to get previously saved phone number
      String? savedPhone = await _userService.getSavedPhoneNumber();
      if (savedPhone != null && savedPhone.isNotEmpty) {
        setState(() {
          _phoneController.text = savedPhone;
        });
        
        // Auto-send OTP if phone number is valid
        if (_isValidPhoneNumber(savedPhone)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _sendOtp();
          });
        }
      }
    }
  }
  
  @override
  void dispose() {
    _otpController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
  
  bool _isValidPhoneNumber(String phone) {
    // International format without the "+"
    return phone.replaceAll(RegExp(r'[^0-9]'), '').length >= 8;
  }

  // Start countdown for OTP resend
  void _startResendCountdown() {
    setState(() {
      _resendCountdown = 60;
      _isResending = false;
    });
    
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
        _startResendCountdown();
      } else if (mounted) {
        setState(() {
          _isResending = true;
        });
      }
    });
  }
  
  // Send OTP to phone number via WhatsApp
  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    String phoneNumber = _phoneController.text.trim();
    
    // Make sure number starts with country code for Morocco
    if (!phoneNumber.startsWith('+')) {
      if (phoneNumber.startsWith('0')) {
        phoneNumber = '+212' + phoneNumber.substring(1);
      } else if (!phoneNumber.startsWith('212')) {
        phoneNumber = '+212' + phoneNumber;
      } else {
        phoneNumber = '+' + phoneNumber;
      }
    }
    
    try {
      // Save the phone number for future use
      await _userService.savePhoneNumber(phoneNumber);
      
      String? verificationId = await _phoneAuthService.sendOtp(
        phoneNumber: phoneNumber,
        onVerificationCompleted: (credential) async {
          // Auto-verification (not available for WhatsApp)
          // But kept for API compatibility
        },
        onVerificationFailed: (e) {
          String errorMessage;
          switch (e.code) {
            case 'invalid-phone-number':
              errorMessage = 'Le numéro de téléphone est invalide.';
              break;
            case 'too-many-requests':
              errorMessage = 'Trop de tentatives. Veuillez réessayer plus tard.';
              break;
            case 'quota-exceeded':
              errorMessage = 'Quota dépassé. Veuillez réessayer plus tard.';
              break;
            case 'twilio-error':
              errorMessage = 'Erreur d\'envoi WhatsApp. Veuillez réessayer.';
              break;
            default:
              errorMessage = 'Une erreur s\'est produite: ${e.message}';
          }
          
          setState(() {
            _isLoading = false;
            _errorMessage = errorMessage;
          });
        },
        onCodeSent: (String verId) {
          setState(() {
            _verificationId = verId;
            _codeSent = true;
            _isLoading = false;
          });
          _startResendCountdown();
        },
      );
      
      if (verificationId == null && !_codeSent) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Échec de l\'envoi du code. Veuillez réessayer.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur: $e';
      });
    }
  }
  
  // Verify OTP code
  Future<void> _verifyOtp() async {
    if (_otpController.text.length < 6) {
      setState(() {
        _errorMessage = 'Veuillez entrer le code complet à 6 chiffres';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      bool isVerified = await _authService.verifyOtp(
        _verificationId!,
        _otpController.text.trim(),
      );
      
      if (isVerified) {
        // Mark that 2FA has been successfully verified
        await _authService.set2FAVerified();
        
        if (widget.isSetup) {
          // Enable 2FA in user profile
          await _userService.enable2FA(_phoneController.text.trim());
        }
        
        if (mounted) {
          // Redirect to password list after 2FA verification
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => PasswordListScreen()),
            (route) => false,
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Code incorrect. Veuillez réessayer.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        if (e is FirebaseAuthException && e.code == 'invalid-verification-code') {
          _errorMessage = 'Code incorrect. Veuillez réessayer.';
        } else {
          _errorMessage = 'Une erreur s\'est produite. Veuillez réessayer.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.isSetup 
              ? 'Configurer la vérification à deux facteurs'
              : 'Vérification à deux facteurs'
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header illustration
                  Container(
                    height: 120,
                    alignment: Alignment.center,
                    child: Icon(
                      _codeSent ? Icons.message_outlined : Icons.phone_android,
                      size: 80,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  
                  // Title
                  Text(
                    _codeSent 
                        ? 'Entrez le code de vérification'
                        : 'Vérification par WhatsApp',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Subtitle
                  Text(
                    _codeSent
                        ? 'Nous avons envoyé un code WhatsApp à ${_phoneController.text}'
                        : 'Saisissez votre numéro de téléphone pour recevoir un code via WhatsApp',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Error message
                  if (_errorMessage != null) ...[
                    AnimatedSize(
                      key: _errorAnimationController,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Phone input or OTP input
                  if (!_codeSent) ...[
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Numéro WhatsApp',
                        hintText: '06XXXXXXXX ou +212XXXXXXXX',
                        prefixIcon: Icon(Icons.phone, color: Theme.of(context).primaryColor),
                        filled: true,
                        fillColor: Colors.grey[100],
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.red, width: 1),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un numéro de téléphone';
                        }
                        if (!_isValidPhoneNumber(value)) {
                          return 'Numéro de téléphone invalide';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // WhatsApp note
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.green),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Assurez-vous que ce numéro est actif sur WhatsApp.',
                              style: TextStyle(color: Colors.green[800]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // PIN code field
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: PinCodeTextField(
                        appContext: context,
                        length: 6,
                        obscureText: false,
                        animationType: AnimationType.fade,
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        pinTheme: PinTheme(
                          shape: PinCodeFieldShape.box,
                          borderRadius: BorderRadius.circular(12),
                          fieldHeight: 56,
                          fieldWidth: 44,
                          activeFillColor: Colors.white,
                          inactiveFillColor: Colors.grey[100],
                          selectedFillColor: Colors.grey[200],
                          activeColor: Theme.of(context).primaryColor,
                          inactiveColor: Colors.grey[400],
                          selectedColor: Theme.of(context).primaryColor,
                        ),
                        enableActiveFill: true,
                        onCompleted: (v) {
                          _verifyOtp();
                        },
                        onChanged: (value) {
                          if (_errorMessage != null) {
                            setState(() {
                              _errorMessage = null;
                            });
                          }
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Resend code
                    Center(
                      child: _isResending
                          ? TextButton.icon(
                              onPressed: _sendOtp,
                              icon: Icon(Icons.refresh, color: Theme.of(context).primaryColor),
                              label: Text(
                                'Renvoyer le code',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : Text(
                              'Renvoyer le code dans $_resendCountdown s',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // Action button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : _codeSent
                              ? _verifyOtp
                              : _sendOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[500],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _codeSent ? 'Vérifier' : 'Envoyer le code',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Change phone number
                  if (_codeSent) ...[
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _codeSent = false;
                            _otpController.clear();
                          });
                        },
                        icon: Icon(Icons.arrow_back, size: 16),
                        label: Text('Changer de numéro'),
                      ),
                    ),
                  ],
                  
                  // Skip for now (only in verification mode, not setup)
                  if (!widget.isSetup && !_codeSent) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          // Redirect to password list
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => PasswordListScreen()),
                            (route) => false,
                          );
                        },
                        child: Text(
                          'Ignorer pour cette fois',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
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