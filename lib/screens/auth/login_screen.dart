// lib/screens/auth/login_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/biometric_service.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'package:monpass/services/two_factor_service.dart.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TwoFactorService _twoFactorService = TwoFactorService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  // Vérifier si la biométrie est disponible et activée
  Future<void> _checkBiometrics() async {
    if (!mounted) return;
    
    bool isAvailable = await BiometricService.isBiometricAvailable();
    bool isEnabled = false;
    
    if (isAvailable) {
      isEnabled = await BiometricService.isBiometricEnabled();
    }
    
    if (mounted) {
      setState(() {
        _isBiometricAvailable = isAvailable;
        _isBiometricEnabled = isEnabled;
      });
      
      // Tenter l'authentification biométrique si activée
      if (_isBiometricAvailable && _isBiometricEnabled) {
        // Petit délai pour permettre à l'UI de se construire
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _authenticateWithBiometrics();
          }
        });
      }
    }
  }

  // Authentification avec biométrie
  // Authentification avec biométrie
// Remplacez votre méthode existante par celle-ci:

Future<void> _authenticateWithBiometrics() async {
  if (!mounted) return;
  
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  // Vérifier que des identifiants sont enregistrés
  bool hasCredentials = await BiometricService.hasCredentials();
  if (!hasCredentials) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Pas d\'identifiants enregistrés pour la biométrie';
      });
    }
    return;
  }

  try {
    bool authenticated = await BiometricService.authenticateWithBiometrics();
    
    if (!mounted) return;

    if (authenticated) {
      // Si authentifié, utiliser les identifiants enregistrés pour se connecter
      Map<String, String?> credentials = await BiometricService.getCredentials();
      String? email = credentials['email'];
      String? password = credentials['password'];
      
      if (email != null && password != null) {
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          // La redirection sera gérée par AuthGate
        } on FirebaseAuthException catch (e) {
          // Si la connexion échoue, désactiver la biométrie
          await BiometricService.disableBiometricAndClearCredentials();
          if (mounted) {
            setState(() {
              _errorMessage = 'Authentification biométrique échouée: ${_getMessageFromErrorCode(e.code)}';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Identifiants incomplets';
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _errorMessage = 'Authentification biométrique annulée';
        });
      }
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _errorMessage = 'Erreur d\'authentification biométrique: $e';
      });
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
  // Fonction de connexion manuelle (avec email et mot de passe)
// Fonction de connexion manuelle (avec email et mot de passe)
Future<void> _signIn() async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  String email = _emailController.text.trim();
  String password = _passwordController.text;
  
  if (email.isEmpty || password.isEmpty) {
    setState(() {
      _isLoading = false;
      _errorMessage = 'Veuillez remplir tous les champs';
    });
    return;
  }

  try {
    // Utiliser le service TwoFactorService au lieu de FirebaseAuth directement
    User? user = await _twoFactorService.signInWithEmailPassword(email, password);
    
    if (user != null && mounted) {
      // Si l'authentification réussit, passer à l'étape OTP
      Navigator.pushReplacementNamed(
        context, 
        '/otp-verification',
        arguments: {'user': user},
      );
    }
  } catch (e) {
    setState(() {
      _isLoading = false;
      _errorMessage = 'Erreur d\'authentification: $e';
    });
  }
}


  // Afficher une boîte de dialogue pour activer l'authentification biométrique
  Future<void> _showBiometricPrompt() async {
  if (!mounted) return;
  
  bool shouldActivate = await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Activer l\'authentification biométrique'),
      content: const Text(
        'Voulez-vous utiliser votre empreinte digitale pour vous connecter plus rapidement à l\'avenir?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Pas maintenant'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Activer'),
        ),
      ],
    ),
  ) ?? false;
  
  if (!shouldActivate || !mounted) return;
  
  // Afficher un indicateur de chargement
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(
      child: CircularProgressIndicator(),
    ),
  );
  
  try {
    // Vérifier si l'utilisateur peut s'authentifier avec biométrie
    bool authenticated = await BiometricService.authenticateWithBiometrics();
    
    if (!mounted) return;
    
    // Fermer le dialogue de chargement
    Navigator.pop(context);
    
    if (authenticated) {
      // IMPORTANT: Sauvegarder email et mot de passe avec la méthode améliorée
      // Utiliser les identifiants exacts qui ont servi à se connecter
      String email = _emailController.text.trim();
      String password = _passwordController.text;
      
      bool success = await BiometricService.enableBiometricWithCredentials(email, password);
      
      if (success) {
        setState(() {
          _isBiometricEnabled = true;
        });
        
        // Vérifier immédiatement que les identifiants ont bien été enregistrés
        bool hasCredentials = await BiometricService.hasCredentials();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                hasCredentials 
                  ? 'Authentification biométrique activée avec succès!'
                  : 'Authentification biométrique activée, mais les identifiants n\'ont pas été correctement sauvegardés.'
              ),
              backgroundColor: hasCredentials ? Colors.green : Colors.orange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Échec de l\'activation biométrique'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  } catch (e) {
    if (mounted) {
      // Fermer le dialogue de chargement si une erreur se produit
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  String _getMessageFromErrorCode(String errorCode) {
    switch (errorCode) {
      case 'invalid-email':
        return 'L\'adresse email est mal formatée';
      case 'user-disabled':
        return 'Ce compte a été désactivé';
      case 'user-not-found':
        return 'Aucun compte trouvé avec cet email';
      case 'wrong-password':
        return 'Mot de passe incorrect';
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect';
      case 'too-many-requests':
        return 'Trop de tentatives. Veuillez réessayer plus tard';
      default:
        return 'Erreur d\'authentification: $errorCode';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo et titre
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock,
                          size: 60,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'MonPass',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Connectez-vous à votre compte',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Message d'erreur
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade800, size: 20),
                              const SizedBox(width: 8),
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
                      
                      // Option d'authentification biométrique
                      if (_isBiometricAvailable) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Se connecter avec l\'empreinte'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            onPressed: _isLoading ? null : _authenticateWithBiometrics,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.grey[300],
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OU',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.grey[300],
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Champ Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Entrez votre adresse email',
                          filled: true,
                          fillColor: Colors.grey[100],
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer votre email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Veuillez entrer un email valide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Champ Mot de passe
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          hintText: 'Entrez votre mot de passe',
                          filled: true,
                          fillColor: Colors.grey[100],
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.grey[600],
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer votre mot de passe';
                          }
                          return null;
                        },
                      ),
                      
                      // Mot de passe oublié
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16, 
                              horizontal: 8
                            ),
                          ),
                          child: Text(
                            'Mot de passe oublié?',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Bouton de connexion
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Text(
                                  'Se connecter',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      if (!_isBiometricAvailable) ...[
                        // Séparateur OU (uniquement si pas de biométrie)
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.grey[300],
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OU',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.grey[300],
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // Lien d'inscription
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Pas encore de compte?",
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[700],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegisterScreen(),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8, 
                                vertical: 8
                              ),
                            ),
                            child: Text(
                              'Créer un compte',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}