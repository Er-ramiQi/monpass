import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../models/password_model.dart';
import '../../services/auth_service.dart';
import '../../services/password_service.dart';
import '../../services/secure_storage_service.dart';

class AddPasswordScreen extends StatefulWidget {
  const AddPasswordScreen({super.key});

  @override
  _AddPasswordScreenState createState() => _AddPasswordScreenState();
}

class _AddPasswordScreenState extends State<AddPasswordScreen> {
  final AuthService _authService = AuthService();
  late SecureStorageService _secureStorage;
  late PasswordService _passwordService;
  
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  
  @override
  void initState() {
    super.initState();
    _initServices();
  }
  
  Future<void> _initServices() async {
    _secureStorage = SecureStorageService();
    await _secureStorage.setMasterPassword('masterpassword');
    
    String? userId = await _authService.getUserId();
    if (userId != null) {
      _passwordService = PasswordService(_secureStorage, userId);
    } else {
      // Gérer l'erreur
      Navigator.pop(context);
    }
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _websiteController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  Future<void> _generatePassword() async {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _PasswordGeneratorSheet(
        onGenerated: (password) {
          setState(() {
            _passwordController.text = password;
          });
        },
      ),
    );
  }
  
  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      PasswordModel newPassword = PasswordModel(
        id: const Uuid().v4(),
        title: _titleController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        website: _websiteController.text.trim(),
        notes: _notesController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isFavorite: false,
      );
      
      bool success = await _passwordService.addPassword(newPassword);
      
      if (success) {
        Navigator.pop(context, true);
      } else {
        _showErrorSnackBar('Erreur lors de l\'enregistrement');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de l\'ajout du mot de passe');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ajouter un mot de passe'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Titre
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Titre',
                          prefixIcon: Icon(Icons.title),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un titre';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Nom d'utilisateur
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Nom d\'utilisateur',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un nom d\'utilisateur';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Mot de passe
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: Icon(Icons.lock),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.refresh),
                                tooltip: 'Générer un mot de passe',
                                onPressed: _generatePassword,
                              ),
                            ],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un mot de passe';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Site web
                      TextFormField(
                        controller: _websiteController,
                        decoration: InputDecoration(
                          labelText: 'Site web (optionnel)',
                          prefixIcon: Icon(Icons.web),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Notes
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Notes (optionnel)',
                          prefixIcon: Icon(Icons.note),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Bouton d'enregistrement
                      ElevatedButton(
                        onPressed: _savePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Enregistrer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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

class _PasswordGeneratorSheet extends StatefulWidget {
  final Function(String) onGenerated;
  
  const _PasswordGeneratorSheet({
    required this.onGenerated,
  });

  @override
  __PasswordGeneratorSheetState createState() => __PasswordGeneratorSheetState();
}

class __PasswordGeneratorSheetState extends State<_PasswordGeneratorSheet> {
  int _passwordLength = 16;
  bool _includeUppercase = true;
  bool _includeLowercase = true;
  bool _includeNumbers = true;
  bool _includeSpecial = true;
  String _generatedPassword = '';
  
  @override
  void initState() {
    super.initState();
    _generatePassword();
  }
  
  void _generatePassword() {
    const String uppercaseChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const String lowercaseChars = 'abcdefghijklmnopqrstuvwxyz';
    const String numberChars = '0123456789';
    const String specialChars = '!@#\$%^&*()_-+=[]{}|;:,.<>?';
    
    String chars = '';
    if (_includeUppercase) chars += uppercaseChars;
    if (_includeLowercase) chars += lowercaseChars;
    if (_includeNumbers) chars += numberChars;
    if (_includeSpecial) chars += specialChars;
    
    if (chars.isEmpty) {
      chars = lowercaseChars + numberChars;
    }
    
    String password = '';
    for (int i = 0; i < _passwordLength; i++) {
      final random = DateTime.now().microsecondsSinceEpoch % chars.length;
      password += chars[random];
    }
    
    setState(() {
      _generatedPassword = password;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Générateur de mot de passe',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Mot de passe généré
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _generatedPassword,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _generatedPassword));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Mot de passe copié')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Longueur du mot de passe
          Row(
            children: [
              Text('Longueur: $_passwordLength'),
              Expanded(
                child: Slider(
                  value: _passwordLength.toDouble(),
                  min: 8,
                  max: 32,
                  divisions: 24,
                  onChanged: (value) {
                    setState(() {
                      _passwordLength = value.round();
                      _generatePassword();
                    });
                  },
                ),
              ),
            ],
          ),
          
          // Options
          CheckboxListTile(
            title: Text('Majuscules (A-Z)'),
            value: _includeUppercase,
            onChanged: (value) {
              setState(() {
                _includeUppercase = value!;
                _generatePassword();
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
          ),
          
          CheckboxListTile(
            title: Text('Minuscules (a-z)'),
            value: _includeLowercase,
            onChanged: (value) {
              setState(() {
                _includeLowercase = value!;
                _generatePassword();
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
          ),
          
          CheckboxListTile(
            title: Text('Chiffres (0-9)'),
            value: _includeNumbers,
            onChanged: (value) {
              setState(() {
                _includeNumbers = value!;
                _generatePassword();
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
          ),
          
          CheckboxListTile(
            title: Text('Caractères spéciaux (!@#\$%^&*)'),
            value: _includeSpecial,
            onChanged: (value) {
              setState(() {
                _includeSpecial = value!;
                _generatePassword();
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
          ),
          
          const SizedBox(height: 16),
          
          // Boutons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _generatePassword,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Régénérer'),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onGenerated(_generatedPassword);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Utiliser'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}