// lib/screens/auth/auth_gate.dart (corrigé)
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../password/password_list_screen.dart'; // Importation corrigée
import 'login_screen.dart';
import 'otp_verification_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  bool _isLoading = true;
  bool _needsOtp = false;
  
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }
  
  Future<void> _checkAuthStatus() async {
    try {
      // Vérifier si l'utilisateur est connecté
      bool isLoggedIn = await _authService.isLoggedIn();
      
      if (isLoggedIn) {
        // Vérifier si 2FA est activée
        bool is2FAEnabled = await _authService.is2FAEnabled();
        
        // Vérifier si 2FA a été validée
        bool is2FAVerified = await _authService.is2FAVerified();
        
        setState(() {
          _isLoading = false;
          // Si 2FA est activée mais pas encore vérifiée, afficher l'écran OTP
          _needsOtp = is2FAEnabled && !is2FAVerified;
        });
      } else {
        setState(() {
          _isLoading = false;
          _needsOtp = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur de vérification: $e');
      setState(() {
        _isLoading = false;
        _needsOtp = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    // Vérifier l'état du Firebase Auth actuel
    final hasUser = FirebaseAuth.instance.currentUser != null;
    
    if (!hasUser) {
      // Non connecté, afficher l'écran de connexion
      return const LoginScreen();
    } else if (_needsOtp) {
      // Connecté mais besoin de vérifier 2FA
      return const OtpVerificationScreen(isSetup: false);
    } else {
      // Authentification complète - afficher la liste des mots de passe
      return const PasswordListScreen(); // Correction ici
    }
  }
}