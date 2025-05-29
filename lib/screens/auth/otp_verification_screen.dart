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
import 'dart:async';

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
  
  final TextEditingController _otpController = TextEditingController();
  
  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 60; // 1 minute = 60 secondes
  String? _errorMessage;
  String? _verificationId;
  String? _phoneNumber;
  Timer? _countdownTimer;
  
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
    _loadPhoneNumberAndSendOtp();
  }
  
  void _initAnimations() {
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
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
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
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
  
  Future<void> _loadPhoneNumberAndSendOtp() async {
    // Récupérer le numéro de téléphone sauvegardé
    String? savedPhone = await _userService.getSavedPhoneNumber();
    
    if (savedPhone != null && savedPhone.isNotEmpty) {
      setState(() {
        _phoneNumber = savedPhone;
      });
      // Envoyer automatiquement l'OTP
      _sendOtp();
    } else {
      // Si pas de numéro sauvegardé, utiliser un numéro par défaut (à modifier selon vos besoins)
      setState(() {
        _phoneNumber = "+212703687923"; // Numéro par défaut
      });
      _sendOtp();
    }
  }
  
  @override
  void dispose() {
    _otpController.dispose();
    _countdownTimer?.cancel();
    _slideController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }
  
  // Fonction pour déconnecter et retourner à la page de connexion
  Future<void> _signOutAndReturnToLogin() async {
    try {
      await _authService.signOut();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Erreur lors de la déconnexion: $e');
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  void _startResendCountdown() {
    setState(() {
      _resendCountdown = 60; // 1 minute
    });
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isResending = false;
        });
      }
    });
  }
  
  String _formatCountdown(int seconds) {
    return '${seconds.toString().padLeft(2, '0')}s';
  }
  
  // Fonction pour masquer le numéro de téléphone, ne montrant que les 2 derniers chiffres
  String _maskPhoneNumber(String phoneNumber) {
    if (phoneNumber.length < 4) return phoneNumber;
    
    String visiblePart = phoneNumber.substring(phoneNumber.length - 2);
    String maskedPart = '*' * (phoneNumber.length - 4);
    String countryCode = phoneNumber.startsWith('+') ? phoneNumber.substring(0, 4) : '';
    
    return '$countryCode$maskedPart$visiblePart';
  }
  
  Future<void> _sendOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isResending = true;
    });
    
    if (_phoneNumber == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Numéro de téléphone non disponible';
      });
      return;
    }
    
    try {
      String? verificationId = await _phoneAuthService.sendOtp(
        phoneNumber: _phoneNumber!,
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
            _isResending = false;
          });
          _shakeController.forward().then((_) => _shakeController.reset());
        },
        onCodeSent: (String verId) {
          setState(() {
            _verificationId = verId;
            _isLoading = false;
          });
          _startResendCountdown();
        },
      );
      
      if (verificationId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Échec de l\'envoi du code. Veuillez réessayer.';
          _isResending = false;
        });
        _shakeController.forward().then((_) => _shakeController.reset());
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur: $e';
        _isResending = false;
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
        
        if (widget.isSetup && _phoneNumber != null) {
          await _userService.enable2FA(_phoneNumber!);
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
      canPop: widget.isSetup,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        if (!widget.isSetup) {
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
                Colors.blue[900]!.withOpacity(0.9),
                Colors.blue[700]!.withOpacity(0.8),
                Colors.blue[500]!.withOpacity(0.7),
                Colors.white.withOpacity(0.9),
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
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
                            if (widget.isSetup) {
                              Navigator.pop(context);
                            } else {
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
                      const SizedBox(width: 48),
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
                          child: Column(
                            children: [
                              const SizedBox(height: 20),
                              
                              // Icône principale avec animation
                              AnimatedBuilder(
                                animation: Listenable.merge([_pulseAnimation]),
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _pulseAnimation.value,
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.9),
                                            Colors.white.withOpacity(0.7),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.blue.withOpacity(0.3),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                          BoxShadow(
                                            color: Colors.blue.withOpacity(0.2),
                                            blurRadius: 15,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.sms_outlined,
                                        size: 40,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              
                              const SizedBox(height: 15),
                              
                              // Éléments décoratifs modernes
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 50,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Colors.blue.withOpacity(0.6),
                                          Colors.white.withOpacity(0.4),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 15),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue.withOpacity(0.2),
                                          Colors.white.withOpacity(0.1),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.verified_user,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Container(
                                    width: 50,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.4),
                                          Colors.blue.withOpacity(0.6),
                                          Colors.transparent,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Titre
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [
                                    Colors.white,
                                    Colors.white.withOpacity(0.8),
                                  ],
                                ).createShader(bounds),
                                child: const Text(
                                  'Code de vérification',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w300,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              
                              const SizedBox(height: 8),
                              
                              // Sous-titre avec numéro masqué
                              Text(
                                'Code envoyé via WhatsApp au\n${_phoneNumber != null ? _maskPhoneNumber(_phoneNumber!) : 'votre numéro'}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                  height: 1.5,
                                  fontWeight: FontWeight.w300,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              
                              const SizedBox(height: 25),
                              
                              // Contenu principal avec design moderne
                              AnimatedBuilder(
                                animation: _shakeAnimation,
                                builder: (context, child) {
                                  return Transform.translate(
                                    offset: _shakeController.isAnimating
                                        ? Offset(_shakeAnimation.value, 0)
                                        : Offset.zero,
                                    child: Container(
                                      padding: const EdgeInsets.all(28),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.95),
                                        borderRadius: BorderRadius.circular(28),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 30,
                                            offset: const Offset(0, 15),
                                          ),
                                          BoxShadow(
                                            color: Colors.purple.withOpacity(0.1),
                                            blurRadius: 40,
                                            offset: const Offset(0, 25),
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
                                                borderRadius: BorderRadius.circular(16),
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
                                          
                                          // Code PIN
                                          const Text(
                                            'Entrez le code à 6 chiffres',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
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
                                              inactiveFillColor: Colors.white,
                                              selectedFillColor: Colors.blue[50],
                                              activeColor: Colors.blue[600]!,
                                              inactiveColor: Colors.grey[300],
                                              selectedColor: Colors.blue[600]!,
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
                                          
                                          // Timer et bouton renvoyer
                                          if (_resendCountdown > 0) ...[
                                            Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.blue[50]!,
                                                    Colors.blue[100]!,
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: Colors.blue[200]!,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.timer,
                                                    color: Colors.blue[600],
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Renvoyer dans ${_formatCountdown(_resendCountdown)}',
                                                    style: TextStyle(
                                                      color: Colors.blue[600],
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ] else ...[
                                            // Bouton renvoyer
                                            OutlinedButton.icon(
                                              onPressed: _isResending ? null : _sendOtp,
                                              icon: _isResending
                                                  ? SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.blue[600],
                                                      ),
                                                    )
                                                  : Icon(
                                                      Icons.refresh,
                                                      color: Colors.blue[600],
                                                    ),
                                              label: Text(
                                                _isResending ? 'Envoi en cours...' : 'Renvoyer le code',
                                                style: TextStyle(
                                                  color: Colors.blue[600],
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(
                                                  color: Colors.blue[600]!,
                                                  width: 2,
                                                ),
                                                padding: const EdgeInsets.symmetric(
                                                  vertical: 12,
                                                  horizontal: 20,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                          ],
                                          
                                          const SizedBox(height: 24),
                                          
                                          // Bouton de vérification
                                          Container(
                                            height: 58,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(18),
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.blue[600]!,
                                                  Colors.blue[500]!,
                                                  Colors.white.withOpacity(0.9),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.blue.withOpacity(0.4),
                                                  blurRadius: 15,
                                                  offset: const Offset(0, 8),
                                                ),
                                              ],
                                            ),
                                            child: ElevatedButton(
                                              onPressed: _isLoading ? null : _verifyOtp,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(18),
                                                ),
                                              ),
                                              child: _isLoading
                                                  ? const SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child: CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2.5,
                                                      ),
                                                    )
                                                  : const Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(
                                                          Icons.verified_user,
                                                          color: Colors.white,
                                                          size: 22,
                                                        ),
                                                        SizedBox(width: 10),
                                                        Text(
                                                          'Vérifier',
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.w600,
                                                            color: Colors.white,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              
                              const SizedBox(height: 20),
                            ],
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