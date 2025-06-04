// lib/screens/password/add_password_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../models/password_model.dart';
import '../../services/auth_service.dart';
import '../../services/password_service.dart';
import '../../services/secure_storage_service.dart';
import '../../theme/app_theme.dart';

class AddPasswordScreen extends StatefulWidget {
  const AddPasswordScreen({super.key});

  @override
  _AddPasswordScreenState createState() => _AddPasswordScreenState();
}

class _AddPasswordScreenState extends State<AddPasswordScreen>
    with TickerProviderStateMixin {
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
  bool _isFavorite = false;
  int _passwordStrength = 0;
  String _detectedCategory = 'Général';
  IconData _categoryIcon = Icons.lock_rounded;
  Color _categoryColor = AppTheme.primaryColor;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  // Sites web populaires pour auto-complétion
  final List<Map<String, dynamic>> _popularSites = [
    {'name': 'Gmail', 'url': 'gmail.com', 'category': 'Email', 'icon': Icons.email_rounded, 'color': Colors.red},
    {'name': 'Facebook', 'url': 'facebook.com', 'category': 'Réseaux sociaux', 'icon': Icons.people_rounded, 'color': Colors.blue},
    {'name': 'Instagram', 'url': 'instagram.com', 'category': 'Réseaux sociaux', 'icon': Icons.camera_alt_rounded, 'color': Colors.purple},
    {'name': 'LinkedIn', 'url': 'linkedin.com', 'category': 'Réseaux sociaux', 'icon': Icons.business_rounded, 'color': Colors.blue},
    {'name': 'Netflix', 'url': 'netflix.com', 'category': 'Divertissement', 'icon': Icons.movie_rounded, 'color': Colors.red},
    {'name': 'PayPal', 'url': 'paypal.com', 'category': 'Banques', 'icon': Icons.payment_rounded, 'color': Colors.blue},
    {'name': 'Amazon', 'url': 'amazon.com', 'category': 'Shopping', 'icon': Icons.shopping_cart_rounded, 'color': Colors.orange},
    {'name': 'GitHub', 'url': 'github.com', 'category': 'Développement', 'icon': Icons.code_rounded, 'color': Colors.black87},
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initServices();
    _passwordController.addListener(_updatePasswordStrength);
    _titleController.addListener(_detectCategoryFromTitle);
    _websiteController.addListener(_detectCategoryFromWebsite);
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _websiteController.dispose();
    _notesController.dispose();
    _passwordController.removeListener(_updatePasswordStrength);
    _titleController.removeListener(_detectCategoryFromTitle);
    _websiteController.removeListener(_detectCategoryFromWebsite);
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initServices() async {
    _secureStorage = SecureStorageService();
    await _secureStorage.setMasterPassword('masterpassword');

    String? userId = await _authService.getUserId();
    if (userId != null) {
      _passwordService = PasswordService(_secureStorage, userId);
    } else {
      Navigator.pop(context);
    }
  }

  void _updatePasswordStrength() {
    setState(() {
      _passwordStrength = _calculatePasswordStrength(_passwordController.text);
    });
  }

  void _detectCategoryFromTitle() {
    _detectCategory(_titleController.text, _websiteController.text);
  }

  void _detectCategoryFromWebsite() {
    _detectCategory(_titleController.text, _websiteController.text);
  }

  void _detectCategory(String title, String website) {
    final titleLower = title.toLowerCase();
    final websiteLower = website.toLowerCase();

    // Recherche dans les sites populaires
    for (final site in _popularSites) {
      if (titleLower.contains(site['name'].toLowerCase()) ||
          websiteLower.contains(site['url']) ||
          titleLower.contains(site['url'].split('.')[0])) {
        setState(() {
          _detectedCategory = site['category'];
          _categoryIcon = site['icon'];
          _categoryColor = site['color'];
        });
        return;
      }
    }

    // Détection par mots-clés
    if (titleLower.contains('bank') || titleLower.contains('banque') || 
        titleLower.contains('credit') || titleLower.contains('paypal') ||
        websiteLower.contains('bank') || websiteLower.contains('paypal')) {
      setState(() {
        _detectedCategory = 'Banques';
        _categoryIcon = Icons.account_balance_rounded;
        _categoryColor = Colors.green;
      });
    } else if (titleLower.contains('email') || titleLower.contains('mail') ||
               titleLower.contains('gmail') || titleLower.contains('outlook') ||
               websiteLower.contains('gmail') || websiteLower.contains('outlook')) {
      setState(() {
        _detectedCategory = 'Email';
        _categoryIcon = Icons.email_rounded;
        _categoryColor = Colors.red;
      });
    } else if (titleLower.contains('social') || titleLower.contains('facebook') ||
               titleLower.contains('instagram') || titleLower.contains('twitter') ||
               websiteLower.contains('facebook') || websiteLower.contains('instagram')) {
      setState(() {
        _detectedCategory = 'Réseaux sociaux';
        _categoryIcon = Icons.people_rounded;
        _categoryColor = Colors.purple;
      });
    } else {
      setState(() {
        _detectedCategory = 'Général';
        _categoryIcon = Icons.lock_rounded;
        _categoryColor = AppTheme.primaryColor;
      });
    }
  }

  int _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;

    int score = 0;

    // Length (up to 40 points)
    score += password.length * 2;
    if (score > 40) score = 40;

    // Complexity (up to 60 additional points)
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 10;
    if (RegExp(r'[a-z]').hasMatch(password)) score += 10;
    if (RegExp(r'[0-9]').hasMatch(password)) score += 10;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score += 20;

    // Variety bonus
    int uniqueChars = password.split('').toSet().length;
    if (password.isNotEmpty) {
      int varietyBonus = (uniqueChars / password.length * 10).round();
      score += varietyBonus;
    }

    // Penalties for patterns
    int repeats = 0;
    for (int i = 0; i < password.length - 1; i++) {
      if (password[i] == password[i + 1]) repeats++;
    }
    score -= repeats * 2;

    // Common patterns penalty
    if (RegExp(r'123|abc|qwerty|password|admin', caseSensitive: false)
        .hasMatch(password)) {
      score -= 20;
    }

    return score < 0 ? 0 : (score > 100 ? 100 : score);
  }

  String _getPasswordStrengthText() {
    if (_passwordStrength < 40) {
      return 'Faible';
    } else if (_passwordStrength < 70) {
      return 'Moyen';
    } else if (_passwordStrength < 90) {
      return 'Fort';
    } else {
      return 'Très fort';
    }
  }

  Color _getPasswordStrengthColor() {
    if (_passwordStrength < 40) {
      return Colors.red;
    } else if (_passwordStrength < 70) {
      return Colors.orange;
    } else if (_passwordStrength < 90) {
      return Colors.green;
    } else {
      return Colors.green.shade700;
    }
  }

  List<String> _getPasswordSuggestions() {
    List<String> suggestions = [];
    String password = _passwordController.text;
    
    if (password.length < 12) {
      suggestions.add("Utilisez au moins 12 caractères");
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      suggestions.add("Ajoutez des majuscules");
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      suggestions.add("Ajoutez des minuscules");
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      suggestions.add("Ajoutez des chiffres");
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      suggestions.add("Ajoutez des caractères spéciaux");
    }
    
    return suggestions;
  }

  Future<void> _generatePassword() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => _PasswordGeneratorSheet(
          onGenerated: (password) {
            setState(() {
              _passwordController.text = password;
            });
          },
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showWebsiteSuggestions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sites populaires',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _popularSites.length,
                    itemBuilder: (context, index) {
                      final site = _popularSites[index];
                      return GestureDetector(
                        onTap: () {
                          _titleController.text = site['name'];
                          _websiteController.text = 'https://${site['url']}';
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                site['color'].withOpacity(0.1),
                                site['color'].withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: site['color'].withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                site['icon'],
                                color: site['color'],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  site['name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: site['color'],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
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
        isFavorite: _isFavorite,
      );

      bool success = await _passwordService.addPassword(newPassword);

      if (success) {
        _showSuccessSnackBar('Mot de passe ajouté avec succès');
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

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSuccessSnackBar('$label copié');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.1,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.1,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final horizontalPadding = isTablet ? 32.0 : 20.0;

    return Scaffold(
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
          child: CustomScrollView(
            slivers: [
              // Header moderne - RÉDUIT
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: false,
                floating: false,
                expandedHeight: 100, // RÉDUIT de 120 à 100
                leading: Container(
                  margin: const EdgeInsets.all(6), // RÉDUIT de 8 à 6
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10), // RÉDUIT de 12 à 10
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.all(6), // RÉDUIT de 8 à 6
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10), // RÉDUIT de 12 à 10
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.star : Icons.star_border,
                        color: _isFavorite ? Colors.amber : Colors.white,
                        size: 20,
                      ),
                      tooltip: 'Marquer comme favori',
                      onPressed: () {
                        setState(() {
                          _isFavorite = !_isFavorite;
                        });
                      },
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 15, // RÉDUIT de 20 à 15
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10), // RÉDUIT de 12 à 10
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.9),
                                            Colors.white.withOpacity(0.7),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(14), // RÉDUIT de 16 à 14
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 8, // RÉDUIT de 10 à 8
                                            offset: const Offset(0, 4), // RÉDUIT de (0,5) à (0,4)
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.add_circle_outline,
                                        size: isTablet ? 28 : 24, // RÉDUIT
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12), // RÉDUIT de 16 à 12
                                    Expanded(
                                      child: Center(
                                        child: Text(
                                          'Nouveau mot de passe',
                                          style: TextStyle(
                                            fontSize: isTablet ? 24 : 20, // RÉDUIT
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.3, // RÉDUIT de 0.5 à 0.3
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Contenu principal
              SliverToBoxAdapter(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      children: [
                        const SizedBox(height: 12), // RÉDUIT de 20 à 12

                        // Détection de catégorie - NOUVEAU
                        if (_detectedCategory != 'Général') ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _categoryColor.withOpacity(0.1),
                                  _categoryColor.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _categoryColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [_categoryColor, _categoryColor.withOpacity(0.7)],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _categoryIcon,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Catégorie détectée',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        _detectedCategory,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: _categoryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.auto_awesome,
                                  color: _categoryColor,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Carte principale du formulaire - OPTIMISÉE
                        Container(
                          padding: const EdgeInsets.all(20), // RÉDUIT de 24 à 20
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.95),
                                Colors.white.withOpacity(0.9),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20), // RÉDUIT de 24 à 20
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 25, // RÉDUIT de 30 à 25
                                offset: const Offset(0, 12), // RÉDUIT de (0,15) à (0,12)
                              ),
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                blurRadius: 35, // RÉDUIT de 40 à 35
                                offset: const Offset(0, 20), // RÉDUIT de (0,25) à (0,20)
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // En-tête de la carte - OPTIMISÉE
                                Container(
                                  padding: const EdgeInsets.all(14), // RÉDUIT de 16 à 14
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.primaryColor.withOpacity(0.1),
                                        AppTheme.secondaryColor.withOpacity(0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14), // RÉDUIT de 16 à 14
                                    border: Border.all(
                                      color: AppTheme.primaryColor.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6), // RÉDUIT de 8 à 6
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppTheme.primaryColor,
                                              AppTheme.secondaryColor,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(8), // RÉDUIT de 10 à 8
                                        ),
                                        child: const Icon(
                                          Icons.info_outline,
                                          color: Colors.white,
                                          size: 16, // RÉDUIT de 18 à 16
                                        ),
                                      ),
                                      const SizedBox(width: 10), // RÉDUIT de 12 à 10
                                      const Expanded(
                                        child: Text(
                                          'Remplissez les informations pour créer un nouveau mot de passe sécurisé',
                                          style: TextStyle(
                                            fontSize: 13, // RÉDUIT de 14 à 13
                                            color: Colors.black87,
                                            height: 1.3, // RÉDUIT de 1.4 à 1.3
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 18), // RÉDUIT de 24 à 18

                                // Titre avec suggestions - AMÉLIORÉ
                                _buildInputField(
                                  controller: _titleController,
                                  label: 'Titre',
                                  hint: 'Ex: Gmail, Facebook, Banque...',
                                  icon: Icons.title_rounded,
                                  suffixIcon: IconButton(
                                    icon: Icon(Icons.apps, color: AppTheme.primaryColor, size: 18),
                                    onPressed: _showWebsiteSuggestions,
                                    tooltip: 'Sites populaires',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Veuillez entrer un titre';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 16), // RÉDUIT de 20 à 16

                                // Nom d'utilisateur avec copie rapide
                                _buildInputField(
                                  controller: _usernameController,
                                  label: 'Nom d\'utilisateur',
                                  hint: 'Email ou nom d\'utilisateur',
                                  icon: Icons.person_rounded,
                                  suffixIcon: _usernameController.text.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(Icons.copy, color: AppTheme.primaryColor, size: 18),
                                          onPressed: () => _copyToClipboard(_usernameController.text, 'Nom d\'utilisateur'),
                                          tooltip: 'Copier',
                                        )
                                      : null,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Veuillez entrer un nom d\'utilisateur';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 16), // RÉDUIT de 20 à 16

                                // Mot de passe avec générateur - AMÉLIORÉ
                                _buildPasswordField(),

                                const SizedBox(height: 16), // RÉDUIT de 20 à 16

                                // Site web
                                _buildInputField(
                                  controller: _websiteController,
                                  label: 'Site web (optionnel)',
                                  hint: 'https://example.com',
                                  icon: Icons.language_rounded,
                                  keyboardType: TextInputType.url,
                                  suffixIcon: _websiteController.text.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(Icons.open_in_new, color: AppTheme.primaryColor, size: 18),
                                          onPressed: () {
                                            // Optionnel: ouvrir le site web
                                          },
                                          tooltip: 'Ouvrir le site',
                                        )
                                      : null,
                                ),

                                const SizedBox(height: 16), // RÉDUIT de 20 à 16

                                // Notes
                                _buildInputField(
                                  controller: _notesController,
                                  label: 'Notes (optionnel)',
                                  hint: 'Informations supplémentaires...',
                                  icon: Icons.note_rounded,
                                  maxLines: 3,
                                ),

                                const SizedBox(height: 24), // RÉDUIT de 32 à 24

                                // Bouton d'enregistrement - OPTIMISÉ
                                Container(
                                  height: 52, // RÉDUIT de 56 à 52
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14), // RÉDUIT de 16 à 14
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.primaryColor,
                                        AppTheme.secondaryColor,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withOpacity(0.4),
                                        blurRadius: 12, // RÉDUIT de 15 à 12
                                        offset: const Offset(0, 6), // RÉDUIT de (0,8) à (0,6)
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _savePassword,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14), // RÉDUIT de 16 à 14
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 22, // RÉDUIT de 24 à 22
                                            height: 22, // RÉDUIT de 24 à 22
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.save_rounded,
                                                color: Colors.white,
                                                size: 20, // RÉDUIT de 22 à 20
                                              ),
                                              SizedBox(width: 10), // RÉDUIT de 12 à 10
                                              Text(
                                                'Enregistrer',
                                                style: TextStyle(
                                                  fontSize: 16, // RÉDUIT de 18 à 16
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  letterSpacing: 0.3, // RÉDUIT de 0.5 à 0.3
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 80), // RÉDUIT de 100 à 80
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15, // RÉDUIT de 16 à 15
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6), // RÉDUIT de 8 à 6
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.grey[50]!,
                Colors.grey[100]!,
              ],
            ),
            borderRadius: BorderRadius.circular(14), // RÉDUIT de 16 à 14
            border: Border.all(
              color: Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            maxLines: maxLines,
            onChanged: (value) {
              setState(() {}); // Pour actualiser les boutons de copie
            },
            style: const TextStyle(
              fontSize: 15, // RÉDUIT de 16 à 15
              fontWeight: FontWeight.w600, // PLUS GRAS
              color: Color(0xFF2196F3), // COULEUR BLEUE VISIBLE
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Color(0xFF9E9E9E), // COULEUR GRISE PLUS VISIBLE
                fontSize: 14, // RÉDUIT de 15 à 14
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(10), // RÉDUIT de 12 à 10
                padding: const EdgeInsets.all(6), // RÉDUIT de 8 à 6
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.2),
                      AppTheme.secondaryColor.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8), // RÉDUIT de 10 à 8
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: 18, // RÉDUIT de 20 à 18
                ),
              ),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18, // RÉDUIT de 20 à 18
                vertical: 14, // RÉDUIT de 16 à 14
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    final suggestions = _getPasswordSuggestions();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mot de passe',
          style: const TextStyle(
            fontSize: 15, // RÉDUIT de 16 à 15
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6), // RÉDUIT de 8 à 6
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.grey[50]!,
                Colors.grey[100]!,
              ],
            ),
            borderRadius: BorderRadius.circular(14), // RÉDUIT de 16 à 14
            border: Border.all(
              color: Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(
              fontSize: 15, // RÉDUIT de 16 à 15
              fontWeight: FontWeight.w600,
              color: _obscurePassword 
                  ? Color(0xFF2196F3) // COULEUR BLEUE VISIBLE pour texte masqué
                  : Color(0xFF2196F3), // COULEUR BLEUE VISIBLE pour mot de passe visible
              fontFamily: _obscurePassword ? null : 'monospace',
              letterSpacing: _obscurePassword ? 2.0 : 1.0,
            ),
            decoration: InputDecoration(
              hintText: 'Créez un mot de passe fort',
              hintStyle: TextStyle(
                color: Color(0xFF9E9E9E), // COULEUR GRISE PLUS VISIBLE
                fontSize: 14, // RÉDUIT de 15 à 14
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(10), // RÉDUIT de 12 à 10
                padding: const EdgeInsets.all(6), // RÉDUIT de 8 à 6
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.2),
                      AppTheme.secondaryColor.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8), // RÉDUIT de 10 à 8
                ),
                child: Icon(
                  Icons.lock_rounded,
                  color: AppTheme.primaryColor,
                  size: 18, // RÉDUIT de 20 à 18
                ),
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.all(3), // RÉDUIT de 4 à 3
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(6), // RÉDUIT de 8 à 6
                    ),
                    child: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.grey[600],
                        size: 18, // RÉDUIT de 20 à 18
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  if (_passwordController.text.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.all(3), // RÉDUIT de 4 à 3
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(6), // RÉDUIT de 8 à 6
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.copy,
                          color: AppTheme.primaryColor,
                          size: 18, // RÉDUIT de 20 à 18
                        ),
                        onPressed: () => _copyToClipboard(_passwordController.text, 'Mot de passe'),
                        tooltip: 'Copier',
                      ),
                    ),
                  ],
                  Container(
                    margin: const EdgeInsets.all(3), // RÉDUIT de 4 à 3
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.secondaryColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6), // RÉDUIT de 8 à 6
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.auto_fix_high_rounded,
                        color: Colors.white,
                        size: 18, // RÉDUIT de 20 à 18
                      ),
                      tooltip: 'Générer un mot de passe',
                      onPressed: _generatePassword,
                    ),
                  ),
                ],
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18, // RÉDUIT de 20 à 18
                vertical: 14, // RÉDUIT de 16 à 14
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer un mot de passe';
              }
              if (value.length < 8) {
                return 'Le mot de passe doit contenir au moins 8 caractères';
              }
              return null;
            },
          ),
        ),

        // Indicateur de force du mot de passe - OPTIMISÉ
        if (_passwordController.text.isNotEmpty) ...[
          const SizedBox(height: 10), // RÉDUIT de 12 à 10
          Container(
            padding: const EdgeInsets.all(12), // RÉDUIT de 16 à 12
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getPasswordStrengthColor().withOpacity(0.1),
                  _getPasswordStrengthColor().withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(10), // RÉDUIT de 12 à 10
              border: Border.all(
                color: _getPasswordStrengthColor().withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.security_rounded,
                      color: _getPasswordStrengthColor(),
                      size: 16, // RÉDUIT de 18 à 16
                    ),
                    const SizedBox(width: 6), // RÉDUIT de 8 à 6
                    Text(
                      'Force: ${_getPasswordStrengthText()}',
                      style: TextStyle(
                        fontSize: 13, // RÉDUIT de 14 à 13
                        fontWeight: FontWeight.bold,
                        color: _getPasswordStrengthColor(),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$_passwordStrength%',
                      style: TextStyle(
                        fontSize: 13, // RÉDUIT de 14 à 13
                        fontWeight: FontWeight.bold,
                        color: _getPasswordStrengthColor(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6), // RÉDUIT de 8 à 6
                ClipRRect(
                  borderRadius: BorderRadius.circular(3), // RÉDUIT de 4 à 3
                  child: LinearProgressIndicator(
                    value: _passwordStrength / 100,
                    backgroundColor: Colors.grey[200],
                    color: _getPasswordStrengthColor(),
                    minHeight: 5, // RÉDUIT de 6 à 5
                  ),
                ),
                
                // Suggestions d'amélioration - NOUVEAU
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: suggestions.map((suggestion) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        suggestion,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PasswordGeneratorSheet extends StatefulWidget {
  final Function(String) onGenerated;
  final ScrollController scrollController;

  const _PasswordGeneratorSheet({
    required this.onGenerated,
    required this.scrollController,
  });

  @override
  __PasswordGeneratorSheetState createState() =>
      __PasswordGeneratorSheetState();
}

class __PasswordGeneratorSheetState extends State<_PasswordGeneratorSheet> {
  int _passwordLength = 16;
  bool _includeUppercase = true;
  bool _includeLowercase = true;
  bool _includeNumbers = true;
  bool _includeSpecial = true;
  bool _avoidAmbiguous = true;
  bool _useWords = false;
  int _wordCount = 3;
  String _generatedPassword = '';

  @override
  void initState() {
    super.initState();
    _generatePassword();
  }

  void _generatePassword() {
    if (_useWords) {
      _generatedPassword = _generateWordBasedPassword();
    } else {
      const String uppercaseChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      const String lowercaseChars = 'abcdefghijklmnopqrstuvwxyz';
      const String numberChars = '0123456789';
      const String specialChars = '!@#\$%^&*()_-+=[]{}|;:,.<>?';
      const String ambiguousChars = '1lI0O';

      String chars = '';
      if (_includeUppercase) chars += uppercaseChars;
      if (_includeLowercase) chars += lowercaseChars;
      if (_includeNumbers) chars += numberChars;
      if (_includeSpecial) chars += specialChars;

      if (_avoidAmbiguous) {
        for (var c in ambiguousChars.split('')) {
          chars = chars.replaceAll(c, '');
        }
      }

      if (chars.isEmpty) {
        chars = lowercaseChars + numberChars;
      }

      String password = '';
      
      // Garantir qu'au moins un caractère de chaque type sélectionné est présent
      List<String> requiredChars = [];
      if (_includeUppercase) requiredChars.add(uppercaseChars[DateTime.now().microsecond % uppercaseChars.length]);
      if (_includeLowercase) requiredChars.add(lowercaseChars[DateTime.now().millisecond % lowercaseChars.length]);
      if (_includeNumbers) requiredChars.add(numberChars[DateTime.now().second % numberChars.length]);
      if (_includeSpecial) requiredChars.add(specialChars[DateTime.now().minute % specialChars.length]);
      
      // Ajouter les caractères obligatoires
      for (String char in requiredChars) {
        password += char;
      }
      
      // Compléter avec des caractères aléatoires
      final random = DateTime.now().microsecondsSinceEpoch;
      for (int i = password.length; i < _passwordLength; i++) {
        final index = (random * (i + 1) + DateTime.now().microsecond) % chars.length;
        password += chars[index];
      }
      
      // Mélanger les caractères pour éviter les patterns prévisibles
      List<String> passwordChars = password.split('');
      for (int i = passwordChars.length - 1; i > 0; i--) {
        int j = (random + i * 7) % (i + 1);
        String temp = passwordChars[i];
        passwordChars[i] = passwordChars[j];
        passwordChars[j] = temp;
      }
      
      _generatedPassword = passwordChars.join('');
    }

    setState(() {});
  }

  String _generateWordBasedPassword() {
    final List<String> words = [
      'apple', 'banana', 'orange', 'grape', 'lemon', 'cherry', 'peach',
      'water', 'ocean', 'river', 'mountain', 'forest', 'desert', 'island',
      'castle', 'palace', 'temple', 'pyramid', 'bridge', 'tunnel', 'tower',
      'dragon', 'phoenix', 'unicorn', 'griffin', 'pegasus', 'mermaid', 'wizard',
      'guitar', 'piano', 'violin', 'drums', 'flute', 'trumpet', 'saxophone',
      'moon', 'star', 'planet', 'galaxy', 'nebula', 'comet', 'meteor',
    ];

    String password = '';
    final random = DateTime.now().microsecondsSinceEpoch;
    
    for (int i = 0; i < _wordCount; i++) {
      // Utiliser une meilleure méthode de sélection aléatoire
      String word = words[(random * (i + 1)) % words.length];
      
      // Capitaliser le premier mot si les majuscules sont activées
      if (_includeUppercase && i == 0) {
        word = word[0].toUpperCase() + word.substring(1);
      }
      
      password += word;
      
      // Ajouter des séparateurs entre les mots
      if (i < _wordCount - 1) {
        if (_includeNumbers) {
          password += ((random + i * 13) % 10).toString();
        } else if (_includeSpecial) {
          final separators = ['-', '_', '.', '+'];
          password += separators[(random + i) % separators.length];
        }
      }
    }

    // Ajouter des chiffres à la fin si demandé et pas encore présents
    if (_includeNumbers && !password.contains(RegExp(r'\d'))) {
      password += ((random % 89) + 10).toString(); // Nombre à 2 chiffres
    }

    // Ajouter un caractère spécial à la fin si demandé
    if (_includeSpecial && !RegExp(r'[!@#$%^&*()_\-+=\[\]{}|;:,.<>?]').hasMatch(password)) {
      final specials = ['!', '@', '#', '\$', '%', '^', '&', '*'];
      password += specials[random % specials.length];
    }

    return password;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey[50]!,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), // RÉDUIT de 24 à 20
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15, // RÉDUIT de 20 à 15
            offset: const Offset(0, -4), // RÉDUIT de (0,-5) à (0,-4)
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10), // RÉDUIT de 12 à 10
            width: 35, // RÉDUIT de 40 à 35
            height: 3, // RÉDUIT de 4 à 3
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(20), // RÉDUIT de 24 à 20
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header - OPTIMISÉ
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10), // RÉDUIT de 12 à 10
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                          ),
                          borderRadius: BorderRadius.circular(10), // RÉDUIT de 12 à 10
                        ),
                        child: const Icon(
                          Icons.auto_fix_high_rounded,
                          color: Colors.white,
                          size: 22, // RÉDUIT de 24 à 22
                        ),
                      ),
                      const SizedBox(width: 12), // RÉDUIT de 16 à 12
                      const Expanded(
                        child: Text(
                          'Générateur de mot de passe',
                          style: TextStyle(
                            fontSize: 20, // RÉDUIT de 22 à 20
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20), // RÉDUIT de 24 à 20

                  // Mot de passe généré - AMÉLIORÉ
                  Container(
                    padding: const EdgeInsets.all(16), // RÉDUIT de 20 à 16
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.1),
                          AppTheme.secondaryColor.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14), // RÉDUIT de 16 à 14
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mot de passe généré',
                          style: TextStyle(
                            fontSize: 13, // RÉDUIT de 14 à 13
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10), // RÉDUIT de 12 à 10
                        Container(
                          padding: const EdgeInsets.all(14), // RÉDUIT de 16 à 14
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10), // RÉDUIT de 12 à 10
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  _generatedPassword,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    letterSpacing: 1.2,
                                    color: Color(0xFF1565C0), // COULEUR BLEUE TRÈS VISIBLE
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10), // RÉDUIT de 12 à 10
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                                  ),
                                  borderRadius: BorderRadius.circular(6), // RÉDUIT de 8 à 6
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: _generatedPassword));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Mot de passe copié')),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18), // RÉDUIT de 24 à 18

                  // Type de génération - NOUVEAU
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Type de mot de passe',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        _buildRadioTile(
                          'Caractères aléatoires',
                          'Plus sécurisé mais difficile à mémoriser',
                          false,
                          !_useWords,
                          (value) {
                            setState(() {
                              _useWords = !value!;
                              _generatePassword();
                            });
                          },
                        ),
                        
                        _buildRadioTile(
                          'Mots aléatoires',
                          'Plus facile à mémoriser',
                          true,
                          _useWords,
                          (value) {
                            setState(() {
                              _useWords = value!;
                              _generatePassword();
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Longueur du mot de passe ou nombre de mots - OPTIMISÉ
                  Container(
                    padding: const EdgeInsets.all(16), // RÉDUIT de 20 à 16
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14), // RÉDUIT de 16 à 14
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _useWords 
                              ? 'Nombre de mots: $_wordCount'
                              : 'Longueur: $_passwordLength caractères',
                          style: const TextStyle(
                            fontSize: 15, // RÉDUIT de 16 à 15
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12), // RÉDUIT de 16 à 12
                        Slider(
                          value: _useWords ? _wordCount.toDouble() : _passwordLength.toDouble(),
                          min: _useWords ? 2 : 8,
                          max: _useWords ? 6 : 32,
                          divisions: _useWords ? 4 : 24,
                          activeColor: AppTheme.primaryColor,
                          label: _useWords ? _wordCount.toString() : _passwordLength.toString(),
                          onChanged: (value) {
                            setState(() {
                              if (_useWords) {
                                _wordCount = value.round();
                              } else {
                                _passwordLength = value.round();
                              }
                              _generatePassword();
                            });
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_useWords ? '2' : '8', style: TextStyle(color: Colors.grey[600])),
                            Text(_useWords ? '6' : '32', style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14), // RÉDUIT de 16 à 14

                  // Options - OPTIMISÉ pour les deux types
                  Container(
                    padding: const EdgeInsets.all(16), // RÉDUIT de 20 à 16
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14), // RÉDUIT de 16 à 14
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _useWords ? 'Options pour les mots' : 'Caractères à inclure',
                          style: const TextStyle(
                            fontSize: 15, // RÉDUIT de 16 à 15
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12), // RÉDUIT de 16 à 12

                        _buildSwitchTile(
                          _useWords ? 'Première lettre en majuscule' : 'Lettres majuscules (A-Z)',
                          Icons.text_fields,
                          _includeUppercase,
                          (value) {
                            if (value || _includeLowercase || _includeNumbers || _includeSpecial) {
                              setState(() {
                                _includeUppercase = value;
                                _generatePassword();
                              });
                            }
                          },
                        ),

                        if (!_useWords) ...[
                          _buildSwitchTile(
                            'Lettres minuscules (a-z)',
                            Icons.text_fields,
                            _includeLowercase,
                            (value) {
                              if (value || _includeUppercase || _includeNumbers || _includeSpecial) {
                                setState(() {
                                  _includeLowercase = value;
                                  _generatePassword();
                                });
                              }
                            },
                          ),
                        ],

                        _buildSwitchTile(
                          _useWords ? 'Ajouter des chiffres' : 'Chiffres (0-9)',
                          Icons.numbers,
                          _includeNumbers,
                          (value) {
                            if (value || _includeUppercase || _includeLowercase || _includeSpecial) {
                              setState(() {
                                _includeNumbers = value;
                                _generatePassword();
                              });
                            }
                          },
                        ),

                        _buildSwitchTile(
                          _useWords ? 'Ajouter des caractères spéciaux' : 'Caractères spéciaux (!@#\$%^&*)',
                          Icons.star,
                          _includeSpecial,
                          (value) {
                            if (value || _includeUppercase || _includeLowercase || _includeNumbers) {
                              setState(() {
                                _includeSpecial = value;
                                _generatePassword();
                              });
                            }
                          },
                        ),

                        if (!_useWords) ...[
                          _buildSwitchTile(
                            'Éviter les caractères ambigus (1, l, I, 0, O)',
                            Icons.remove_red_eye,
                            _avoidAmbiguous,
                            (value) {
                              setState(() {
                                _avoidAmbiguous = value;
                                _generatePassword();
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20), // RÉDUIT de 24 à 20

                  // Boutons - OPTIMISÉS
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _generatePassword,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Régénérer'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 14), // RÉDUIT de 16 à 14
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10), // RÉDUIT de 12 à 10
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12), // RÉDUIT de 16 à 12
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                            ),
                            borderRadius: BorderRadius.circular(10), // RÉDUIT de 12 à 10
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              widget.onGenerated(_generatedPassword);
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                            label: const Text(
                              'Utiliser',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14), // RÉDUIT de 16 à 14
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10), // RÉDUIT de 12 à 10
                              ),
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
        ],
      ),
    );
  }

  Widget _buildRadioTile(
    String title,
    String subtitle,
    bool value,
    bool groupValue,
    Function(bool?) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: groupValue == value
              ? [
                  AppTheme.primaryColor.withOpacity(0.1),
                  AppTheme.secondaryColor.withOpacity(0.1),
                ]
              : [
                  Colors.grey[50]!,
                  Colors.grey[100]!,
                ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: groupValue == value
              ? AppTheme.primaryColor.withOpacity(0.3)
              : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Radio<bool>(
            value: value,
            groupValue: groupValue,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: groupValue == value ? Colors.black87 : Colors.grey[700],
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6), // RÉDUIT de 8 à 6
      padding: const EdgeInsets.all(10), // RÉDUIT de 12 à 10
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: value
              ? [
                  AppTheme.primaryColor.withOpacity(0.1),
                  AppTheme.secondaryColor.withOpacity(0.1),
                ]
              : [
                  Colors.grey[50]!,
                  Colors.grey[100]!,
                ],
        ),
        borderRadius: BorderRadius.circular(10), // RÉDUIT de 12 à 10
        border: Border.all(
          color: value
              ? AppTheme.primaryColor.withOpacity(0.3)
              : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6), // RÉDUIT de 8 à 6
            decoration: BoxDecoration(
              color: value
                  ? AppTheme.primaryColor.withOpacity(0.2)
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(6), // RÉDUIT de 8 à 6
            ),
            child: Icon(
              icon,
              color: value ? AppTheme.primaryColor : Colors.grey[600],
              size: 16, // RÉDUIT de 18 à 16
            ),
          ),
          const SizedBox(width: 10), // RÉDUIT de 12 à 10
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13, // RÉDUIT de 14 à 13
                fontWeight: FontWeight.w500,
                color: value ? Colors.black87 : Colors.grey[700],
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}