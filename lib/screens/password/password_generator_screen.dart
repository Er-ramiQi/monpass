// lib/screens/password/password_generator_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/password_service.dart';
import '../../services/secure_storage_service.dart';
import '../../theme/app_theme.dart';

class PasswordGeneratorScreen extends StatefulWidget {
  final Function(String)? onPasswordGenerated;
  
  const PasswordGeneratorScreen({
    super.key, 
    this.onPasswordGenerated,
  });

  @override
  State<PasswordGeneratorScreen> createState() => _PasswordGeneratorScreenState();
}

class _PasswordGeneratorScreenState extends State<PasswordGeneratorScreen> {
  // Créer une instance correcte de PasswordService avec les bons types
  final PasswordService _passwordService = PasswordService(
    SecureStorageService(), // Instance de SecureStorageService
    FirebaseAuth.instance.currentUser?.uid ?? 'anonymous', // ID utilisateur
  );
  
  // Password configuration
  int _passwordLength = 16;
  bool _includeUppercase = true;
  bool _includeLowercase = true;
  bool _includeNumbers = true;
  bool _includeSpecial = true;
  bool _avoidAmbiguous = false;
  
  // UI state
  String _generatedPassword = '';
  bool _passwordCopied = false;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _generatePassword();
  }
  
  void _generatePassword() {
    setState(() {
      _isLoading = true;
    });
    
    // Avoid blocking the UI thread for longer passwords
    Future.delayed(Duration.zero, () {
      final password = _passwordService.generatePassword(
        length: _passwordLength,
        includeUppercase: _includeUppercase,
        includeLowercase: _includeLowercase,
        includeNumbers: _includeNumbers,
        includeSpecial: _includeSpecial,
        avoidAmbiguous: _avoidAmbiguous,
      );
      
      setState(() {
        _generatedPassword = password;
        _isLoading = false;
        _passwordCopied = false;
      });
    });
  }
  
  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _generatedPassword));
    setState(() {
      _passwordCopied = true;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Mot de passe copié dans le presse-papiers'),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
    
    // Reset copied status after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _passwordCopied = false;
        });
      }
    });
  }
  
  void _usePassword() {
    if (widget.onPasswordGenerated != null) {
      widget.onPasswordGenerated!(_generatedPassword);
    }
    Navigator.pop(context, _generatedPassword);
  }
  
  // Calculate password strength score (0-100)
  int _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    
    int score = 0;
    
    // Length (up to 40 points)
    score += password.length * 2;
    if (score > 40) score = 40;
    
    // Character variety (up to 40 points)
    int varietyScore = 0;
    if (RegExp(r'[A-Z]').hasMatch(password)) varietyScore += 10;
    if (RegExp(r'[a-z]').hasMatch(password)) varietyScore += 10;
    if (RegExp(r'[0-9]').hasMatch(password)) varietyScore += 10;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) varietyScore += 10;
    
    // Penalty for repeating characters
    int repeats = 0;
    for (int i = 0; i < password.length - 1; i++) {
      if (password[i] == password[i + 1]) repeats++;
    }
    int repeatPenalty = min(repeats * 2, 20);
    
    return min(score + varietyScore - repeatPenalty, 100);
  }
  
  // Get a human-readable strength label and color
  Map<String, dynamic> _getStrengthInfo(int score) {
    if (score < 40) {
      return {'label': 'Faible', 'color': Colors.red};
    } else if (score < 70) {
      return {'label': 'Moyen', 'color': Colors.orange};
    } else if (score < 90) {
      return {'label': 'Fort', 'color': Colors.green};
    } else {
      return {'label': 'Très fort', 'color': Colors.green[700]};
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Calculate strength
    final strengthScore = _calculatePasswordStrength(_generatedPassword);
    final strengthInfo = _getStrengthInfo(strengthScore);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Générateur de mot de passe'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Generated password display
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mot de passe généré',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _passwordCopied ? Icons.check : Icons.copy,
                              color: _passwordCopied ? Colors.green : AppTheme.primaryColor,
                            ),
                            onPressed: _copyToClipboard,
                            tooltip: 'Copier',
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Password text
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: _isLoading
                            ? Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryColor,
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : Text(
                                _generatedPassword,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Strength indicator
                      Row(
                        children: [
                          const Text(
                            'Force: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF616161), // gray700
                            ),
                          ),
                          Text(
                            strengthInfo['label'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: strengthInfo['color'],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: strengthScore / 100,
                                backgroundColor: Colors.grey[200],
                                color: strengthInfo['color'],
                                minHeight: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Length slider
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Longueur: $_passwordLength caractères',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Slider(
                        value: _passwordLength.toDouble(),
                        min: 8,
                        max: 32,
                        divisions: 24,
                        activeColor: AppTheme.primaryColor,
                        label: _passwordLength.toString(),
                        onChanged: (value) {
                          setState(() {
                            _passwordLength = value.round();
                          });
                        },
                        onChangeEnd: (value) {
                          _generatePassword();
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('8', style: TextStyle(color: Colors.grey[600])),
                          Text('32', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Character options
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Caractères à inclure',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      SwitchListTile(
                        title: const Text('Lettres majuscules (A-Z)'),
                        value: _includeUppercase,
                        secondary: Icon(
                          Icons.text_fields,
                          color: _includeUppercase 
                              ? AppTheme.primaryColor 
                              : Colors.grey,
                        ),
                        onChanged: (value) {
                          // Ensure at least one character type is selected
                          if (value || _includeLowercase || _includeNumbers || _includeSpecial) {
                            setState(() {
                              _includeUppercase = value;
                            });
                            _generatePassword();
                          }
                        },
                      ),
                      
                      SwitchListTile(
                        title: const Text('Lettres minuscules (a-z)'),
                        value: _includeLowercase,
                        secondary: Icon(
                          Icons.text_fields,
                          color: _includeLowercase 
                              ? AppTheme.primaryColor 
                              : Colors.grey,
                        ),
                        onChanged: (value) {
                          // Ensure at least one character type is selected
                          if (value || _includeUppercase || _includeNumbers || _includeSpecial) {
                            setState(() {
                              _includeLowercase = value;
                            });
                            _generatePassword();
                          }
                        },
                      ),
                      
                      SwitchListTile(
                        title: const Text('Chiffres (0-9)'),
                        value: _includeNumbers,
                        secondary: Icon(
                          Icons.numbers,
                          color: _includeNumbers 
                              ? AppTheme.primaryColor 
                              : Colors.grey,
                        ),
                        onChanged: (value) {
                          // Ensure at least one character type is selected
                          if (value || _includeUppercase || _includeLowercase || _includeSpecial) {
                            setState(() {
                              _includeNumbers = value;
                            });
                            _generatePassword();
                          }
                        },
                      ),
                      
                      SwitchListTile(
                        title: const Text('Caractères spéciaux (!@#\$%^&*)'),
                        value: _includeSpecial,
                        secondary: Icon(
                          Icons.star,
                          color: _includeSpecial 
                              ? AppTheme.primaryColor 
                              : Colors.grey,
                        ),
                        onChanged: (value) {
                          // Ensure at least one character type is selected
                          if (value || _includeUppercase || _includeLowercase || _includeNumbers) {
                            setState(() {
                              _includeSpecial = value;
                            });
                            _generatePassword();
                          }
                        },
                      ),
                      
                      SwitchListTile(
                        title: const Text('Éviter les caractères ambigus (1, l, I, 0, O)'),
                        value: _avoidAmbiguous,
                        secondary: Icon(
                          Icons.remove_red_eye,
                          color: _avoidAmbiguous 
                              ? AppTheme.primaryColor 
                              : Colors.grey,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _avoidAmbiguous = value;
                          });
                          _generatePassword();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _generatePassword,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Regénérer'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppTheme.primaryColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _usePassword,
                      icon: const Icon(Icons.check),
                      label: const Text('Utiliser'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}