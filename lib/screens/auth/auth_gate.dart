// lib/screens/auth/auth_gate.dart
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../password/password_list_screen.dart';
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
  String? _phoneNumber;
  
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }
  
  Future<void> _checkAuthStatus() async {
    try {
      // Check if user is logged in
      bool isLoggedIn = await _authService.isLoggedIn();
      
      if (isLoggedIn) {
        // Check if 2FA is enabled
        bool is2FAEnabled = await _authService.is2FAEnabled();
        
        // Check if 2FA has been verified
        bool is2FAVerified = await _authService.is2FAVerified();
        
        // Get saved phone number
        _phoneNumber = await _userService.getSavedPhoneNumber();
        
        setState(() {
          _isLoading = false;
          // If 2FA is enabled but not yet verified, show OTP screen
          _needsOtp = is2FAEnabled && !is2FAVerified;
        });
      } else {
        setState(() {
          _isLoading = false;
          _needsOtp = false;
        });
      }
    } catch (e) {
      debugPrint('Verification error: $e');
      setState(() {
        _isLoading = false;
        _needsOtp = false;
      });
    }
  }

  // Gérer le bouton retour système
  Future<bool> _onWillPop() async {
    // Si on est sur l'écran de connexion, permettre la fermeture de l'app
    if (!_isLoading && !_needsOtp && FirebaseAuth.instance.currentUser == null) {
      // Fermer l'application proprement
      SystemNavigator.pop();
      return false;
    }
    
    // Dans les autres cas, empêcher la fermeture
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: _buildContent(),
    );
  }
  
  Widget _buildContent() {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF667eea),
                const Color.fromARGB(255, 75, 94, 162),
              ],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
                SizedBox(height: 24),
                Text(
                  'MonPass',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Chargement en cours...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Check current Firebase Auth state
    final hasUser = FirebaseAuth.instance.currentUser != null;
    
    if (!hasUser) {
      // Not logged in, show login screen
      return const LoginScreen();
    } else if (_needsOtp) {
      // Logged in but needs to verify 2FA
      return OtpVerificationScreen(
        isSetup: false, 
        phoneNumber: _phoneNumber,
      );
    } else {
      // Authentication complete - show password list
      return const PasswordListScreen();
    }
  }
}