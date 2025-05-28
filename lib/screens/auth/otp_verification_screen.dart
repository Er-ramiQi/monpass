// lib/screens/auth/otp_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:monpass/services/phone_auth_service.dart';
import 'package:monpass/services/user_service.dart';
import 'package:monpass/services/auth_service.dart';
import 'package:monpass/screens/password/password_list_screen.dart';
import 'package:monpass/screens/auth/login_screen.dart';
import 'package:monpass/theme/app_theme.dart';

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

class _OtpVerificationScreenState extends State<OtpVerificationScreen> 
    with TickerProviderStateMixin {
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
  
  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;
  
  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadPhoneNumber();
  }
  
  void _initAnimations() {
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 24,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }
  
  Future<void> _loadPhoneNumber() async {
    if (widget.phoneNumber != null && widget.phoneNumber!.isNotEmpty) {
      _phoneController.text = widget.phoneNumber!;
      
      if (_isValidPhoneNumber(widget.phoneNumber!)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _sendOtp();
        });
      }
    } else {
      String? savedPhone = await _userService.getSavedPhoneNumber();
      if (savedPhone != null && savedPhone.isNotEmpty) {
        setState(() {
          _phoneController.text = savedPhone;
        });
        
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
    _slideController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }
  
  // Fonction pour déconnecter et retourner à la page de connexion
  Future<void> _signOutAndReturnToLogin() async {
    try {
      // Déconnecter l'utilisateur
      await _authService.signOut();
      
      if (mounted) {
        // Import nécessaire pour LoginScreen
        final loginScreen = MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        );
        
        // Retourner à la page de connexion en supprimant toutes les pages précédentes
        Navigator.of(context).pushAndRemoveUntil(
          loginScreen,
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Erreur lors de la déconnexion: $e');
      if (mounted) {
        // En cas d'erreur, forcer le retour avec pop
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }
  
  bool _isValidPhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9]'), '').length >= 8;
  }

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
  
  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    String phoneNumber = _phoneController.text.trim();
    
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
      await _userService.savePhoneNumber(phoneNumber);
      
      String? verificationId = await _phoneAuthService.sendOtp(
        phoneNumber: phoneNumber,
        onVerificationCompleted: (credential) async {
          // Auto-verification not available for WhatsApp
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
          _shakeController.forward().then((_) => _shakeController.reset());
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
        _shakeController.forward().then((_) => _shakeController.reset());
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur: $e';
      });
      _shakeController.forward().then((_) => _shakeController.reset());
    }
  }
  
  Future<void> _verifyOtp() async {
    if (_otpController.text.length < 6) {
      setState(() {
        _errorMessage = 'Veuillez entrer le code complet à 6 chiffres';
      });
      _shakeController.forward().then((_) => _shakeController.reset());
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
        await _authService.set2FAVerified();
        
        if (widget.isSetup) {
          await _userService.enable2FA(_phoneController.text.trim());
        }
        
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const PasswordListScreen()),
            (route) => false,
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Code incorrect. Veuillez réessayer.';
        });
        _shakeController.forward().then((_) => _shakeController.reset());
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
      _shakeController.forward().then((_) => _shakeController.reset());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isSetup, // Permet de revenir seulement si c'est une configuration
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        // Si ce n'est pas une configuration mais une vérification obligatoire
        if (!widget.isSetup) {
          // Demander confirmation avant de déconnecter
          bool? shouldSignOut = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Quitter la vérification ?'),
              content: const Text(
                'La vérification à deux facteurs est obligatoire. Quitter vous déconnectera de l\'application.',
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
                  child: const Text('Se déconnecter'),
                ),
              ],
            ),
          );
          
          if (shouldSignOut == true) {
            _signOutAndReturnToLogin();
          }
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor,
                AppTheme.secondaryColor,
                AppTheme.accentColor.withOpacity(0.8),
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            // Si c'est une configuration 2FA, on peut revenir
                            if (widget.isSetup) {
                              Navigator.pop(context);
                            } else {
                              // Si c'est une vérification obligatoire, on déconnecte l'utilisateur
                              _signOutAndReturnToLogin();
                            }
                          },
                        ),
                      ),
                      const Spacer(),
                      Text(
                        widget.isSetup 
                            ? 'Configuration 2FA'
                            : 'Vérification 2FA',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48), // Balance
                    ],
                  ),
                ),
                
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                const SizedBox(height: 20),
                                
                                // Icône principale avec animation
                                AnimatedBuilder(
                                  animation: _pulseAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _codeSent ? 1.0 : _pulseAnimation.value,
                                      child: Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          _codeSent 
                                              ? Icons.sms_outlined 
                                              : Icons.phone_android,
                                          size: 60,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                
                                const SizedBox(height: 32),
                                
                                // Titre
                                Text(
                                  _codeSent 
                                      ? 'Entrez le code de vérification'
                                      : 'Authentification à deux facteurs',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Sous-titre
                                Text(
                                  _codeSent
                                      ? 'Nous avons envoyé un code WhatsApp au\n${_phoneController.text}'
                                      : 'Pour votre sécurité, nous devons vérifier votre identité via WhatsApp',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                
                                const SizedBox(height: 40),
                                
                                // Contenu principal
                                AnimatedBuilder(
                                  animation: _shakeAnimation,
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset: _shakeController.isAnimating
                                          ? Offset(_shakeAnimation.value, 0)
                                          : Offset.zero,
                                      child: Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(24),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.1),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            // Message d'erreur
                                            if (_errorMessage != null) ...[
                                              Container(
                                                padding: const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade50,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.red.shade200,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.error_outline,
                                                      color: Colors.red.shade700,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        _errorMessage!,
                                                        style: TextStyle(
                                                          color: Colors.red.shade700,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                            ],
                                            
                                            // Saisie du numéro ou du code
                                            if (!_codeSent) ...[
                                              // Numéro de téléphone
                                              TextFormField(
                                                controller: _phoneController,
                                                keyboardType: TextInputType.phone,
                                                decoration: InputDecoration(
                                                  labelText: 'Numéro WhatsApp',
                                                  hintText: '06XXXXXXXX ou +212XXXXXXXX',
                                                  prefixIcon: const Icon(
                                                    Icons.phone,
                                                    color: AppTheme.primaryColor,
                                                  ),
                                                  filled: true,
                                                  fillColor: Colors.grey[50],
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                    borderSide: BorderSide.none,
                                                  ),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                    borderSide: BorderSide(
                                                      color: Colors.grey[300]!,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                    borderSide: const BorderSide(
                                                      color: AppTheme.primaryColor,
                                                      width: 2,
                                                    ),
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
                                              
                                              // Note WhatsApp
                                              Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.green.withOpacity(0.3),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.info_outline,
                                                      color: Colors.green,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        'Assurez-vous que ce numéro est actif sur WhatsApp.',
                                                        style: TextStyle(
                                                          color: Colors.green[800],
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ] else ...[
                                              // Code PIN
                                              const Text(
                                                'Code de vérification',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primaryColor,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 20),
                                              
                                              PinCodeTextField(
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
                                                  selectedFillColor: AppTheme.accentColor.withOpacity(0.3),
                                                  activeColor: AppTheme.primaryColor,
                                                  inactiveColor: Colors.grey[400],
                                                  selectedColor: AppTheme.primaryColor,
                                                  borderWidth: 2,
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
                                              
                                              const SizedBox(height: 24),
                                              
                                              // Renvoyer le code
                                              Center(
                                                child: _isResending
                                                    ? TextButton.icon(
                                                        onPressed: _sendOtp,
                                                        icon: const Icon(
                                                          Icons.refresh,
                                                          color: AppTheme.primaryColor,
                                                        ),
                                                        label: const Text(
                                                          'Renvoyer le code',
                                                          style: TextStyle(
                                                            color: AppTheme.primaryColor,
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
                                            
                                            const SizedBox(height: 24),
                                            
                                            // Bouton d'action principal
                                            Container(
                                              height: 56,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(16),
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    AppTheme.primaryColor,
                                                    AppTheme.secondaryColor,
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppTheme.primaryColor.withOpacity(0.3),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: ElevatedButton(
                                                onPressed: _isLoading
                                                    ? null
                                                    : _codeSent
                                                        ? _verifyOtp
                                                        : _sendOtp,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.transparent,
                                                  shadowColor: Colors.transparent,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                ),
                                                child: _isLoading
                                                    ? const SizedBox(
                                                        width: 24,
                                                        height: 24,
                                                        child: CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2,
                                                        ),
                                                      )
                                                    : Text(
                                                        _codeSent ? 'Vérifier' : 'Envoyer le code',
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                            
                                            // Changer de numéro (uniquement si code envoyé)
                                            if (_codeSent) ...[
                                              const SizedBox(height: 16),
                                              TextButton.icon(
                                                onPressed: () {
                                                  setState(() {
                                                    _codeSent = false;
                                                    _otpController.clear();
                                                  });
                                                },
                                                icon: const Icon(
                                                  Icons.arrow_back,
                                                  size: 16,
                                                  color: AppTheme.primaryColor,
                                                ),
                                                label: const Text(
                                                  'Changer de numéro',
                                                  style: TextStyle(
                                                    color: AppTheme.primaryColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                
                                const SizedBox(height: 32),
                                
                                // Informations de sécurité
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.security,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Authentification sécurisée',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'La 2FA protège votre compte même si votre mot de passe est compromis. Ce processus est obligatoire pour votre sécurité.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                          height: 1.5,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}