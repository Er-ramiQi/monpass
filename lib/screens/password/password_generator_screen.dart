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

class _PasswordGeneratorScreenState extends State<PasswordGeneratorScreen> with SingleTickerProviderStateMixin {
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
  bool _avoidAmbiguous = true;
  bool _useWords = false;
  int _wordCount = 3;
  
  // UI state
  String _generatedPassword = '';
  bool _passwordCopied = false;
  bool _isLoading = false;
  List<String> _suggestions = [];
  
  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _strengthAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _strengthAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    
    _generatePassword();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _generatePassword() {
    setState(() {
      _isLoading = true;
    });
    
    // Avoid blocking the UI thread for longer passwords
    Future.delayed(Duration.zero, () {
      String password;
      
      if (_useWords) {
        // Générer un mot de passe basé sur des mots (style diceware)
        password = _generateWordBasedPassword();
      } else {
        // Générer un mot de passe classique avec caractères aléatoires
        password = _passwordService.generatePassword(
          length: _passwordLength,
          includeUppercase: _includeUppercase,
          includeLowercase: _includeLowercase,
          includeNumbers: _includeNumbers,
          includeSpecial: _includeSpecial,
          avoidAmbiguous: _avoidAmbiguous,
        );
      }
      
      // Calculer la force du mot de passe et obtenir les suggestions
      int strength = _calculatePasswordStrength(password);
      _suggestions = _getPasswordSuggestions(password);
      
      // Animer la barre de force du mot de passe
      _animationController.value = 0;
      _animationController.animateTo(strength / 100);
      
      setState(() {
        _generatedPassword = password;
        _isLoading = false;
        _passwordCopied = false;
      });
    });
  }
  
  String _generateWordBasedPassword() {
    // Liste de mots communs (dans une vraie implémentation, cela serait une liste bien plus grande)
    final List<String> commonWords = [
      "apple", "banana", "orange", "grape", "lemon", "cherry", "peach",
      "water", "ocean", "river", "mountain", "forest", "desert", "island",
      "castle", "palace", "temple", "pyramid", "bridge", "tunnel", "tower",
      "dragon", "phoenix", "unicorn", "griffin", "pegasus", "mermaid", "wizard",
      "diamond", "emerald", "sapphire", "ruby", "pearl", "crystal", "amber"
    ];
    
    final random = Random.secure();
    List<String> selectedWords = [];
    
    // Sélectionner des mots aléatoires
    for (int i = 0; i < _wordCount; i++) {
      String word = commonWords[random.nextInt(commonWords.length)];
      
      // Mettre en majuscule la première lettre ou ajouter un chiffre si demandé
      if (_includeUppercase && random.nextBool()) {
        word = word[0].toUpperCase() + word.substring(1);
      }
      
      selectedWords.add(word);
    }
    
    // Ajouter des chiffres et des caractères spéciaux
    String separator = "";
    if (_includeSpecial) {
      final List<String> specials = [".", "-", "_", "!", "@", "#", "%", "&", "*"];
      separator = specials[random.nextInt(specials.length)];
    } else if (_includeNumbers) {
      separator = random.nextInt(10).toString();
    }
    
    String password = selectedWords.join(separator);
    
    // Assurer qu'il y a au moins un chiffre si demandé
    if (_includeNumbers && !RegExp(r'\d').hasMatch(password)) {
      password += random.nextInt(100).toString();
    }
    
    return password;
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
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
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
  
  // Calcule un score de force du mot de passe (0-100)
  int _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    
    int score = 0;
    
    // Longueur (max 30 points)
    score += password.length * 2;
    if (score > 30) score = 30;
    
    // Diversité de caractères (max 40 points)
    Map<String, bool> characterTypes = {
      'lowercase': RegExp(r'[a-z]').hasMatch(password),
      'uppercase': RegExp(r'[A-Z]').hasMatch(password),
      'numbers': RegExp(r'[0-9]').hasMatch(password),
      'symbols': RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password),
      'uncommon': RegExp(r'[^\w!@#$%^&*(),.?":{}|<>]').hasMatch(password),
    };
    
    int typesCount = characterTypes.values.where((type) => type).length;
    score += typesCount * 10;
    
    // Variété (nombre de caractères uniques)
    int uniqueChars = password.split('').toSet().length;
    double varietyRatio = uniqueChars / password.length;
    score += (varietyRatio * 10).round();
    
    // Pénalités
    // 1. Séquences courantes (abc, 123, etc.)
    if (RegExp(r'(abc|bcd|cde|def|efg|fgh|ghi|hij|ijk|jkl|klm|lmn|mno|nop|opq|pqr|qrs|rst|stu|tuv|uvw|vwx|wxy|xyz|012|123|234|345|456|567|678|789|890)', caseSensitive: false).hasMatch(password)) {
      score -= 10;
    }
    
    // 2. Répétitions
    int repeats = 0;
    for (int i = 0; i < password.length - 1; i++) {
      if (password[i] == password[i + 1]) repeats++;
    }
    score -= repeats * 2;
    
    // 3. Mots de passe courants
    final List<String> commonPatterns = [
      'password', 'admin', '12345', 'qwerty', 'welcome', 'letmein',
      'monkey', 'login', 'abc123', 'passw0rd'
    ];
    
    for (final pattern in commonPatterns) {
      if (password.toLowerCase().contains(pattern)) {
        score -= 15;
        break;
      }
    }
    
    // Garantir un score entre 0 et 100
    return score < 0 ? 0 : (score > 100 ? 100 : score);
  }
  
  // Obtient des informations sur la force du mot de passe
  Map<String, dynamic> _getPasswordStrengthInfo(int score) {
    if (score < 40) {
      return {
        'label': 'Faible',
        'color': Colors.red,
        'feedback': 'Essayez d\'utiliser plus de caractères et de types différents.',
      };
    } else if (score < 60) {
      return {
        'label': 'Moyen',
        'color': Colors.orange,
        'feedback': 'Ajoutez plus de longueur et des caractères spéciaux.',
      };
    } else if (score < 80) {
      return {
        'label': 'Fort',
        'color': Colors.green,
        'feedback': 'Bon mot de passe. Assurez-vous qu\'il reste unique.',
      };
    } else {
      return {
        'label': 'Très fort',
        'color': Colors.green.shade700,
        'feedback': 'Excellent mot de passe!',
      };
    }
  }
  
  // Suggestions pour améliorer un mot de passe
  List<String> _getPasswordSuggestions(String password) {
    List<String> suggestions = [];
    
    if (password.length < 12) {
      suggestions.add("Augmentez la longueur à au moins 12 caractères");
    }
    
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      suggestions.add("Ajoutez des lettres majuscules");
    }
    
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      suggestions.add("Ajoutez des lettres minuscules");
    }
    
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      suggestions.add("Ajoutez des chiffres");
    }
    
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      suggestions.add("Ajoutez des caractères spéciaux");
    }
    
    // Patterns à éviter
    if (RegExp(r'(.)\1{2,}').hasMatch(password)) {
      suggestions.add("Évitez les caractères répétés (ex: 'aaa')");
    }
    
    if (RegExp(r'(abc|123|qwerty|password)', caseSensitive: false).hasMatch(password)) {
      suggestions.add("Évitez les séquences et mots de passe courants");
    }
    
    return suggestions;
  }

  @override
  Widget build(BuildContext context) {
    // Calculer la force du mot de passe
    final int strengthScore = _calculatePasswordStrength(_generatedPassword);
    final strengthInfo = _getPasswordStrengthInfo(strengthScore);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Générateur de mot de passe'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Aide sur les mots de passe',
            onPressed: () {
              _showPasswordHelpDialog();
            },
          ),
        ],
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
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: _generatePassword,
                                tooltip: 'Régénérer',
                                color: AppTheme.primaryColor,
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
                            : SelectableText(
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
                              child: AnimatedBuilder(
                                animation: _strengthAnimation,
                                builder: (context, child) {
                                  return LinearProgressIndicator(
                                    value: _strengthAnimation.value,
                                    backgroundColor: Colors.grey[200],
                                    color: strengthInfo['color'],
                                    minHeight: 8,
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      if (_suggestions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Suggestions d\'amélioration:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...List.generate(_suggestions.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.arrow_right, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _suggestions[index],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Type de génération
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
                        'Type de mot de passe',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      RadioListTile<bool>(
                        title: const Text('Caractères aléatoires'),
                        subtitle: const Text('Plus sécurisé mais plus difficile à mémoriser'),
                        value: false,
                        groupValue: _useWords,
                        onChanged: (value) {
                          setState(() {
                            _useWords = value!;
                          });
                          _generatePassword();
                        },
                        activeColor: AppTheme.primaryColor,
                        contentPadding: EdgeInsets.zero,
                      ),
                      
                      RadioListTile<bool>(
                        title: const Text('Mots aléatoires'),
                        subtitle: const Text('Plus facile à mémoriser'),
                        value: true,
                        groupValue: _useWords,
                        onChanged: (value) {
                          setState(() {
                            _useWords = value!;
                          });
                          _generatePassword();
                        },
                        activeColor: AppTheme.primaryColor,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Length slider or word count
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
                      _useWords
                          ? Text(
                              'Nombre de mots: $_wordCount',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : Text(
                              'Longueur: $_passwordLength caractères',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      const SizedBox(height: 20),
                      
                      _useWords
                          ? Slider(
                              value: _wordCount.toDouble(),
                              min: 2,
                              max: 6,
                              divisions: 4,
                              activeColor: AppTheme.primaryColor,
                              label: _wordCount.toString(),
                              onChanged: (value) {
                                setState(() {
                                  _wordCount = value.round();
                                });
                              },
                              onChangeEnd: (value) {
                                _generatePassword();
                              },
                            )
                          : Slider(
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
                        children: _useWords
                            ? [
                                Text('2', style: TextStyle(color: Colors.grey[600])),
                                Text('6', style: TextStyle(color: Colors.grey[600])),
                              ]
                            : [
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
              if (!_useWords) ...[
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
              ],
              
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
  
  void _showPasswordHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Comment choisir un bon mot de passe'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Un bon mot de passe doit être:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Long (au moins 12 caractères)'),
              const Text('• Unique pour chaque service'),
              const Text('• Difficile à deviner'),
              const Text('• Facile à retenir pour vous'),
              const SizedBox(height: 16),
              const Text(
                'Les mots de passe basés sur des mots aléatoires sont souvent plus faciles à mémoriser tout en restant sécurisés grâce à leur longueur.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              const Text(
                'Évitez:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Informations personnelles (dates, noms)'),
              const Text('• Séquences simples (123456, abcdef)'),
              const Text('• Mots de passe courants (password, admin)'),
              const Text('• Réutiliser le même mot de passe'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}