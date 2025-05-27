// lib/screens/auth/auth_gate.dart
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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