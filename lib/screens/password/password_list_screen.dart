// lib/screens/password/password_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/password_model.dart';
import '../../services/auth_service.dart';
import '../../services/password_service.dart';
import '../../services/secure_storage_service.dart';
import '../../theme/app_theme.dart';
import 'add_password_screen.dart';
import 'password_detail_screen.dart';
import 'password_generator_screen.dart';

class PasswordListScreen extends StatefulWidget {
  const PasswordListScreen({super.key});

  @override
  _PasswordListScreenState createState() => _PasswordListScreenState();
}

class _PasswordListScreenState extends State<PasswordListScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late SecureStorageService _secureStorage;
  late PasswordService _passwordService;

  List<PasswordModel> _passwords = [];
  List<PasswordModel> _filteredPasswords = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';

  // Sort options
  String _sortBy = 'title';
  bool _sortAscending = true;

  // Tab controller for categories - CATÉGORIES AVEC FAVORIS
  late TabController _tabController;
  final List<String> _categories = [
    'Tous',
    'Favoris',
    'Banques',
    'Réseaux sociaux',
    'Jeux',
    'Médical',
    'Email',
  ];

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(_handleTabChange);
    _initAnimations();
    _initServices();
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
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _applyFilters();
      });
    }
  }

  Future<void> _initServices() async {
    _secureStorage = SecureStorageService();
    await _secureStorage.setMasterPassword('masterpassword');

    String? userId = await _authService.getUserId();
    if (userId == null) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    _passwordService = PasswordService(_secureStorage, userId);
    await _loadPasswords();
  }

  Future<void> _loadPasswords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<PasswordModel> passwords = await _passwordService.getAllPasswords();
      setState(() {
        _passwords = passwords;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Erreur de chargement');
    }
  }

  // Calcul de la force du mot de passe
  int _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;

    int score = 0;
    if (password.length >= 12) score += 25;
    if (password.length >= 16) score += 25;
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 15;
    if (RegExp(r'[a-z]').hasMatch(password)) score += 15;
    if (RegExp(r'[0-9]').hasMatch(password)) score += 10;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score += 10;

    return score > 100 ? 100 : score;
  }

  // DÉTECTION DE CATÉGORIE AMÉLIORÉE
  String _detectCategory(PasswordModel password) {
    final title = password.title.toLowerCase();
    final website = password.website.toLowerCase();
    final username = password.username.toLowerCase();

    // Banques et finances
    if (title.contains('bank') ||
        title.contains('banque') ||
        title.contains('credit') ||
        title.contains('carte') ||
        title.contains('paypal') ||
        title.contains('crypto') ||
        title.contains('bitcoin') ||
        title.contains('visa') ||
        title.contains('mastercard') ||
        title.contains('revolut') ||
        website.contains('paypal') ||
        website.contains('bank')) {
      return 'Banques';
    }

    // Réseaux sociaux
    if (title.contains('facebook') ||
        title.contains('instagram') ||
        title.contains('twitter') ||
        title.contains('linkedin') ||
        title.contains('snapchat') ||
        title.contains('tiktok') ||
        title.contains('whatsapp') ||
        title.contains('telegram') ||
        website.contains('facebook') ||
        website.contains('instagram') ||
        website.contains('twitter') ||
        website.contains('linkedin') ||
        website.contains('snapchat') ||
        website.contains('tiktok')) {
      return 'Réseaux sociaux';
    }

    // Jeux
    if (title.contains('steam') ||
        title.contains('xbox') ||
        title.contains('playstation') ||
        title.contains('nintendo') ||
        title.contains('epic') ||
        title.contains('origin') ||
        title.contains('battle.net') ||
        title.contains('riot') ||
        title.contains('valorant') ||
        title.contains('fortnite') ||
        title.contains('minecraft') ||
        title.contains('wow') ||
        website.contains('steam') ||
        website.contains('epicgames') ||
        website.contains('battle.net') ||
        website.contains('riotgames')) {
      return 'Jeux';
    }

    // Médical et santé
    if (title.contains('medical') ||
        title.contains('medic') ||
        title.contains('health') ||
        title.contains('doctor') ||
        title.contains('hospital') ||
        title.contains('clinic') ||
        title.contains('pharmacy') ||
        title.contains('dentist') ||
        title.contains('sante') ||
        title.contains('docteur') ||
        title.contains('hopital') ||
        title.contains('clinique') ||
        title.contains('pharmacie') ||
        title.contains('dentiste')) {
      return 'Médical';
    }

    // Email
    if (title.contains('email') ||
        title.contains('mail') ||
        title.contains('gmail') ||
        title.contains('outlook') ||
        title.contains('yahoo') ||
        title.contains('hotmail') ||
        website.contains('gmail') ||
        website.contains('outlook') ||
        website.contains('yahoo') ||
        website.contains('hotmail') ||
        username.contains('@')) {
      return 'Email';
    }

    return 'Tous';
  }

  void _applyFilters() {
    List<PasswordModel> filtered = List.from(_passwords);

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((password) {
            return password.title.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                password.username.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                password.website.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );
          }).toList();
    }

    // Filter by category - AVEC FAVORIS
    if (_tabController.index > 0) {
      final selectedCategory = _categories[_tabController.index];
      if (selectedCategory == 'Favoris') {
        filtered = filtered.where((password) => password.isFavorite).toList();
      } else {
        filtered =
            filtered.where((password) {
              return _detectCategory(password) == selectedCategory;
            }).toList();
      }
    }

    // Sort passwords
    filtered.sort((a, b) {
      if (_sortBy == 'title') {
        return _sortAscending
            ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
            : b.title.toLowerCase().compareTo(a.title.toLowerCase());
      } else if (_sortBy == 'username') {
        return _sortAscending
            ? a.username.toLowerCase().compareTo(b.username.toLowerCase())
            : b.username.toLowerCase().compareTo(a.username.toLowerCase());
      } else if (_sortBy == 'created') {
        return _sortAscending
            ? a.createdAt.compareTo(b.createdAt)
            : b.createdAt.compareTo(a.createdAt);
      } else if (_sortBy == 'updated') {
        return _sortAscending
            ? a.updatedAt.compareTo(b.updatedAt)
            : b.updatedAt.compareTo(a.updatedAt);
      }
      return 0;
    });

    setState(() {
      _filteredPasswords = filtered;
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.1,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(PasswordModel password) async {
    try {
      await _passwordService.toggleFavorite(password.id);
      _loadPasswords();
    } catch (e) {
      _showErrorSnackBar('Erreur favori');
    }
  }

  Future<void> _deletePassword(PasswordModel password) async {
    try {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => _buildDeleteDialog(password),
      );

      if (confirm == true) {
        await _passwordService.deletePassword(password.id);
        _loadPasswords();
        _showSuccessSnackBar('Mot de passe supprimé');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur suppression');
    }
  }

  Widget _buildDeleteDialog(PasswordModel password) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Supprimer ?'),
      content: Text('Supprimer "${password.title}" ?'),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Supprimer'),
        ),
      ],
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSuccessSnackBar('$label copié');
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Flexible(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.1,
          left: 16,
          right: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.3,
            builder:
                (context, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Trier par',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),

                              _buildSortOption('Titre', 'title'),
                              _buildSortOption('Utilisateur', 'username'),
                              _buildSortOption('Création', 'created'),
                              _buildSortOption('Modification', 'updated'),

                              const SizedBox(height: 20),

                              // Order toggle
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _sortAscending
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward,
                                      color: AppTheme.primaryColor,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('Ordre croissant'),
                                    const Spacer(),
                                    Switch(
                                      value: _sortAscending,
                                      onChanged: (value) {
                                        setState(() {
                                          _sortAscending = value;
                                          _applyFilters();
                                        });
                                        Navigator.pop(context);
                                      },
                                      activeColor: AppTheme.primaryColor,
                                    ),
                                  ],
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
    );
  }

  Widget _buildSortOption(String label, String value) {
    final bool isSelected = _sortBy == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = value;
          _applyFilters();
        });
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[200]!,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryColor : Colors.grey[400]!,
                ),
              ),
              child:
                  isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primaryColor : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final horizontalPadding = isTablet ? 32.0 : 16.0;

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
              // Header avec titre et actions
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: false,
                floating: false,
                expandedHeight: _isSearching ? 180 : 120, // HAUTEURS OPTIMISÉES
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 12, // PADDING RÉDUIT
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          // Titre principal
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.lock_rounded,
                                  size: isTablet ? 28 : 24,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Mes mots de passe',
                                  style: TextStyle(
                                    fontSize: isTablet ? 28 : 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              // Actions
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildActionButton(
                                    icon:
                                        _isSearching
                                            ? Icons.close
                                            : Icons.search,
                                    onPressed: () {
                                      setState(() {
                                        _isSearching = !_isSearching;
                                        if (!_isSearching) {
                                          _searchQuery = '';
                                          _applyFilters();
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _buildActionButton(
                                    icon: Icons.sort,
                                    onPressed: _showSortOptions,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildActionButton(
                                    icon: Icons.password,
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const PasswordGeneratorScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Barre de recherche améliorée avec COULEURS FIXES
                          if (_isSearching) ...[
                            const SizedBox(height: 12), // ESPACEMENT RÉDUIT
                            SlideTransition(
                              position: _slideAnimation,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.grey[50]!, // FOND GRIS TRÈS CLAIR
                                      Colors.grey[100]!,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  autofocus: true,
                                  onChanged: (value) {
                                    setState(() {
                                      _searchQuery = value;
                                      _applyFilters();
                                    });
                                  },
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black, // TEXTE NOIR COMPLET
                                    fontWeight: FontWeight.w600, // Plus épais
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Rechercher vos mots de passe...',
                                    hintStyle: TextStyle(
                                      color:
                                          Colors
                                              .grey[700], // HINT GRIS TRÈS FONCÉ
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    prefixIcon: Container(
                                      margin: const EdgeInsets.all(12),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.primaryColor,
                                            AppTheme.secondaryColor,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.search_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    suffixIcon:
                                        _searchQuery.isNotEmpty
                                            ? Container(
                                              margin: const EdgeInsets.all(12),
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _searchQuery = '';
                                                    _applyFilters();
                                                  });
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Colors
                                                            .grey[400], // FOND PLUS FONCÉ
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons.close_rounded,
                                                    color:
                                                        Colors
                                                            .white, // ICÔNE BLANCHE
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                            )
                                            : null,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Statistiques
              SliverToBoxAdapter(
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 8, // ESPACEMENT OPTIMISÉ
                  ),
                  padding: EdgeInsets.all(
                    isTablet ? 18 : 14,
                  ), // PADDING OPTIMISÉ
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95), // PLUS OPAQUE
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatistic(
                            count: _passwords.length,
                            label: 'Total',
                            icon: Icons.vpn_key_rounded,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        VerticalDivider(color: Colors.grey[300], thickness: 1),
                        Expanded(
                          child: _buildStatistic(
                            count: _passwords.where((p) => p.isFavorite).length,
                            label: 'Favoris',
                            icon: Icons.star_rounded,
                            color: Colors.amber,
                          ),
                        ),
                        VerticalDivider(color: Colors.grey[300], thickness: 1),
                        Expanded(
                          child: _buildStatistic(
                            count:
                                _passwords
                                    .where(
                                      (p) =>
                                          _calculatePasswordStrength(
                                            p.password,
                                          ) >=
                                          70,
                                    )
                                    .length,
                            label: 'Sécurisés',
                            icon: Icons.shield_rounded,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Tabs STICKY (restent visibles pendant le scroll)
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyTabBarDelegate(
                  tabBar: Container(
                    margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    height: 48, // HAUTEUR OPTIMISÉE
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            0.08,
                          ), // OMBRE SUBTILE
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicator: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.2),
                            AppTheme.secondaryColor.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ), // PADDING OPTIMISÉ
                      labelColor: AppTheme.primaryColor,
                      unselectedLabelColor: Colors.grey[600],
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 14 : 12,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: isTablet ? 14 : 12,
                      ),
                      dividerColor: Colors.transparent,
                      tabs:
                          _categories
                              .map(
                                (category) => Tab(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _getCategoryTabIcon(category),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          category,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ),
              ),

              // Liste des mots de passe
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Chargement...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_filteredPasswords.isEmpty)
                SliverFillRemaining(child: _buildEmptyState())
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: _buildPasswordCard(_filteredPasswords[index]),
                    );
                  }, childCount: _filteredPasswords.length),
                ),

              // Espace en bas pour le FAB
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddPasswordScreen(),
              ),
            );
            if (result == true) {
              _loadPasswords();
            }
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
    );
  }

  // ICÔNES POUR LES TABS DE CATÉGORIES
  IconData _getCategoryTabIcon(String category) {
    switch (category) {
      case 'Tous':
        return Icons.dashboard_rounded;
      case 'Favoris':
        return Icons.star_rounded;
      case 'Banques':
        return Icons.account_balance_rounded;
      case 'Réseaux sociaux':
        return Icons.people_rounded;
      case 'Jeux':
        return Icons.sports_esports_rounded;
      case 'Médical':
        return Icons.medical_services_rounded;
      case 'Email':
        return Icons.email_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  Widget _buildStatistic({
    required int count,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _searchQuery.isNotEmpty
                      ? Icons.search_off_rounded
                      : Icons.lock_open_rounded,
                  size: 48,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Aucun résultat'
                    : 'Aucun mot de passe',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Essayez d\'autres termes'
                    : 'Ajoutez votre premier mot de passe',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              if (_searchQuery.isEmpty) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddPasswordScreen(),
                      ),
                    );
                    if (result == true) {
                      _loadPasswords();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Ajouter'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordCard(PasswordModel password) {
    final strength = _calculatePasswordStrength(password.password);
    final strengthColor =
        strength >= 70
            ? Colors.green
            : strength >= 40
            ? Colors.orange
            : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Dismissible(
        key: Key(password.id),
        background: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green, Colors.green.shade600],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.centerLeft,
          child: const Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Ajouter aux favoris',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        secondaryBackground: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.red, Colors.red.shade600]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.centerRight,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Supprimer',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.delete_rounded, color: Colors.white, size: 24),
            ],
          ),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            await _toggleFavorite(password);
            return false;
          } else {
            return await showDialog<bool>(
                  context: context,
                  builder: (context) => _buildDeleteDialog(password),
                ) ??
                false;
          }
        },
        child: GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PasswordDetailScreen(password: password),
              ),
            );
            if (result == true) {
              _loadPasswords();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: _getCategoryColor(password).withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Icône avec design premium
                Hero(
                  tag: 'icon_${password.id}',
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _getCategoryColor(password),
                          _getCategoryColor(password).withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _getCategoryColor(password).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: _getCategoryColor(password).withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _getCategoryIcon(password),
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Informations avec meilleure hiérarchie
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              password.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (password.isFavorite)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.amber, Colors.amber.shade600],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        password.username,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (password.website.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.language_rounded,
                                size: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                password.website,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Badge de catégorie + indicateur de force
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _getCategoryColor(password).withOpacity(0.2),
                                  _getCategoryColor(password).withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getCategoryColor(
                                  password,
                                ).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getCategoryIcon(password),
                                  size: 12,
                                  color: _getCategoryColor(password),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _detectCategory(password),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _getCategoryColor(password),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  strengthColor.withOpacity(0.2),
                                  strengthColor.withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: strengthColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  strength >= 70
                                      ? Icons.shield_rounded
                                      : strength >= 40
                                      ? Icons.warning_rounded
                                      : Icons.error_rounded,
                                  size: 10,
                                  color: strengthColor,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  strength >= 70
                                      ? 'Fort'
                                      : strength >= 40
                                      ? 'Moyen'
                                      : 'Faible',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: strengthColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action button premium
                Container(
                  margin: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withOpacity(0.1),
                        AppTheme.secondaryColor.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.secondaryColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.content_copy_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    onPressed:
                        () =>
                            _copyToClipboard(password.password, 'Mot de passe'),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    padding: const EdgeInsets.all(8),
                    tooltip: 'Copier le mot de passe',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // COULEURS AMÉLIORÉES PAR CATÉGORIE
  Color _getCategoryColor(PasswordModel password) {
    final category = _detectCategory(password);

    switch (category) {
      case 'Banques':
        return Colors.green;
      case 'Réseaux sociaux':
        return Colors.purple;
      case 'Jeux':
        return Colors.red;
      case 'Médical':
        return Colors.teal;
      case 'Email':
        return Colors.orange;
      default:
        return AppTheme.primaryColor;
    }
  }

  // ICÔNES AMÉLIORÉES PAR CATÉGORIE
  IconData _getCategoryIcon(PasswordModel password) {
    final category = _detectCategory(password);

    switch (category) {
      case 'Banques':
        return Icons.account_balance_rounded;
      case 'Réseaux sociaux':
        return Icons.people_rounded;
      case 'Jeux':
        return Icons.sports_esports_rounded;
      case 'Médical':
        return Icons.medical_services_rounded;
      case 'Email':
        return Icons.email_rounded;
      default:
        return Icons.lock_rounded;
    }
  }
}

// Classe pour rendre les tabs sticky (collants) pendant le scroll
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;

  _StickyTabBarDelegate({required this.tabBar});

  @override
  double get minExtent => 60; // HAUTEUR OPTIMISÉE

  @override
  double get maxExtent => 60; // HAUTEUR OPTIMISÉE

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 6), // PADDING OPTIMISÉ
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return false;
  }
}
