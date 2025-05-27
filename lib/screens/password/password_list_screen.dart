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
import '../settings/settings_screen.dart';

class PasswordListScreen extends StatefulWidget {
  const PasswordListScreen({super.key});

  @override
  _PasswordListScreenState createState() => _PasswordListScreenState();
}

class _PasswordListScreenState extends State<PasswordListScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late SecureStorageService _secureStorage;
  late PasswordService _passwordService;
  
  List<PasswordModel> _passwords = [];
  List<PasswordModel> _filteredPasswords = [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _showOnlyFavorites = false;
  String _searchQuery = '';
  
  // Sort options
  String _sortBy = 'title'; // 'title', 'username', 'created', 'updated'
  bool _sortAscending = true;
  
  // Tab controller for categories
  late TabController _tabController;
  final List<String> _categories = ['Tous', 'Sites web', 'Applications', 'Finances', 'Favoris'];
  
  // Animation
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  bool _isInitialLoad = true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(_handleTabChange);
    _initServices();
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }
  
  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        if (_tabController.index == _categories.length - 1) {
          // "Favoris" tab
          _showOnlyFavorites = true;
        } else {
          _showOnlyFavorites = false;
        }
        _applyFilters();
      });
    }
  }
  
  Future<void> _initServices() async {
    _secureStorage = SecureStorageService();
    // Simulate master password entry (in production, prompt user)
    await _secureStorage.setMasterPassword('masterpassword');
    
    String? userId = await _authService.getUserId();
    if (userId == null) {
      // Redirect to login if no user ID
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
        _isInitialLoad = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
      });
      _showErrorSnackBar('Erreur de chargement des mots de passe');
    }
  }
  
  void _applyFilters() {
    List<PasswordModel> filtered = List.from(_passwords);
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((password) {
        return password.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               password.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               password.website.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               password.notes.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    // Filter by favorites
    if (_showOnlyFavorites) {
      filtered = filtered.where((password) => password.isFavorite).toList();
    }
    
    // Filter by category (for tabs other than "All" and "Favorites")
    if (_tabController.index > 0 && _tabController.index < _categories.length - 1) {
      String category = _categories[_tabController.index].toLowerCase();
      filtered = filtered.where((password) {
        if (category == 'sites web') {
          return password.website.isNotEmpty;
        } else if (category == 'applications') {
          return password.title.toLowerCase().contains('app') || 
                 password.notes.toLowerCase().contains('app');
        } else if (category == 'finances') {
          return password.title.toLowerCase().contains('bank') || 
                 password.title.toLowerCase().contains('banque') ||
                 password.title.toLowerCase().contains('carte') ||
                 password.title.toLowerCase().contains('crédit') ||
                 password.title.toLowerCase().contains('paiement');
        }
        return true;
      }).toList();
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
            : b.updatedAt.compareTo(a.createdAt);
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
      ),
    );
  }
  
  Future<void> _toggleFavorite(PasswordModel password) async {
    try {
      await _passwordService.toggleFavorite(password.id);
      _loadPasswords();
    } catch (e) {
      _showErrorSnackBar('Erreur lors du changement de statut favori');
    }
  }
  
  Future<void> _deletePassword(PasswordModel password) async {
    try {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Confirmer la suppression'),
          content: Text('Voulez-vous vraiment supprimer "${password.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
              ),
              child: Text('Supprimer'),
            ),
          ],
        ),
      );
      
      if (confirm == true) {
        await _passwordService.deletePassword(password.id);
        _loadPasswords();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mot de passe supprimé'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la suppression');
    }
  }
  
  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('$label copié dans le presse-papiers'),
          ],
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  // Open sort options menu
  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trier par',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              
              // Sort options
              RadioListTile<String>(
                title: Text('Titre'),
                value: 'title',
                groupValue: _sortBy,
                onChanged: (value) {
                  setState(() {
                    _sortBy = value!;
                  });
                  this.setState(() {
                    _applyFilters();
                  });
                },
              ),
              RadioListTile<String>(
                title: Text('Nom d\'utilisateur'),
                value: 'username',
                groupValue: _sortBy,
                onChanged: (value) {
                  setState(() {
                    _sortBy = value!;
                  });
                  this.setState(() {
                    _applyFilters();
                  });
                },
              ),
              RadioListTile<String>(
                title: Text('Date de création'),
                value: 'created',
                groupValue: _sortBy,
                onChanged: (value) {
                  setState(() {
                    _sortBy = value!;
                  });
                  this.setState(() {
                    _applyFilters();
                  });
                },
              ),
              RadioListTile<String>(
                title: Text('Date de modification'),
                value: 'updated',
                groupValue: _sortBy,
                onChanged: (value) {
                  setState(() {
                    _sortBy = value!;
                  });
                  this.setState(() {
                    _applyFilters();
                  });
                },
              ),
              
              Divider(),
              
              // Order options
              SwitchListTile(
                title: Text(_sortAscending ? 'Ordre croissant' : 'Ordre décroissant'),
                value: _sortAscending,
                onChanged: (value) {
                  setState(() {
                    _sortAscending = value;
                  });
                  this.setState(() {
                    _applyFilters();
                  });
                },
                secondary: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final double shortestSide = MediaQuery.of(context).size.shortestSide;
    final bool isTablet = shortestSide >= 600;
    
    // Determine the grid columns based on screen width
    int gridColumns = 1;
    if (isTablet) {
      gridColumns = 2;
      if (MediaQuery.of(context).size.width >= 1100) {
        gridColumns = 3;
      }
    }
    
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Rechercher...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: TextStyle(color: Colors.white),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _applyFilters();
                  });
                },
              )
            : Text('Mes mots de passe'),
        actions: [
          // Search button
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? 'Annuler' : 'Rechercher',
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
          
          // Sort button
          IconButton(
            icon: Icon(Icons.sort),
            tooltip: 'Trier',
            onPressed: _showSortOptions,
          ),
          
          // Generate password button
          IconButton(
            icon: Icon(Icons.password),
            tooltip: 'Générer mot de passe',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PasswordGeneratorScreen(),
                ),
              );
            },
          ),
          
          // Settings button
          IconButton(
            icon: Icon(Icons.settings),
            tooltip: 'Paramètres',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: _categories.map((category) => Tab(text: category)).toList(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Statistics banner
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: AppTheme.accentColor.withOpacity(0.2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatistic(
                        count: _passwords.length,
                        label: 'Total',
                        icon: Icons.vpn_key,
                      ),
                      _buildStatistic(
                        count: _passwords.where((p) => p.isFavorite).length,
                        label: 'Favoris',
                        icon: Icons.star,
                      ),
                      _buildStatistic(
                        count: _passwords.where((p) => p.website.isNotEmpty).length,
                        label: 'Sites web',
                        icon: Icons.language,
                      ),
                    ],
                  ),
                ),
                
                // Password list
                Expanded(
                  child: _filteredPasswords.isEmpty
                      ? _buildEmptyState()
                      : Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: isTablet
                              ? GridView.builder(
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: gridColumns,
                                    childAspectRatio: 2.5,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                                  itemCount: _filteredPasswords.length,
                                  itemBuilder: (context, index) {
                                    return _buildPasswordCard(_filteredPasswords[index]);
                                  },
                                )
                              : ListView.builder(
                                  itemCount: _filteredPasswords.length,
                                  itemBuilder: (context, index) {
                                    return _buildPasswordCard(_filteredPasswords[index]);
                                  },
                                ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ajouter un mot de passe',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddPasswordScreen(),
            ),
          );
          if (result == true) {
            _loadPasswords();
          }
        },
        child: Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildStatistic({required int count, required String label, required IconData icon}) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryColor),
            SizedBox(width: 4),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty
                ? Icons.search_off
                : _showOnlyFavorites
                    ? Icons.star_border
                    : Icons.lock_open,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Aucun résultat pour "$_searchQuery"'
                : _showOnlyFavorites
                    ? 'Aucun mot de passe favori'
                    : 'Aucun mot de passe enregistré',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Essayez d\'autres mots-clés'
                : _showOnlyFavorites
                    ? 'Marquez des mots de passe comme favoris pour les retrouver ici'
                    : 'Ajoutez votre premier mot de passe en cliquant sur le bouton +',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32),
          if (!_showOnlyFavorites && _searchQuery.isEmpty)
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddPasswordScreen(),
                  ),
                );
                if (result == true) {
                  _loadPasswords();
                }
              },
              icon: Icon(Icons.add),
              label: Text('Ajouter un mot de passe'),
            ),
        ],
      ),
    );
  }
  Widget _buildPasswordList() {
  return ListView.builder(
    itemCount: _filteredPasswords.length,
    itemBuilder: (context, index) {
      final password = _filteredPasswords[index];
      // Utiliser Dismissible pour les actions swipe
      return Dismissible(
        key: Key(password.id),
        // Swipe gauche -> supprimer
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          color: AppTheme.errorColor,
          child: Row(
            children: const [
              Icon(Icons.delete, color: Colors.white),
              SizedBox(width: 8),
              Text('Supprimer', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        // Swipe droit -> favori
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: password.isFavorite ? Colors.grey : Colors.amber,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                password.isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris', 
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(width: 8),
              Icon(
                password.isFavorite ? Icons.star_border : Icons.star, 
                color: Colors.white,
              ),
            ],
          ),
        ),
        // Confirmer suppression
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            // Demander confirmation pour suppression
            return await _confirmDeleteDialog(password);
          } else {
            // Pour les favoris, pas besoin de confirmation
            await _toggleFavorite(password);
            return false; // Ne pas supprimer l'élément de la liste
          }
        },
        // Action à effectuer après confirmation
        onDismissed: (direction) {
          if (direction == DismissDirection.startToEnd) {
            _deletePassword(password);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Mot de passe supprimé'),
                action: SnackBarAction(
                  label: 'Annuler',
                  onPressed: () {
                    // Récupérer le mot de passe
                    _loadPasswords();
                  },
                ),
              ),
            );
          }
        },
        child: _buildPasswordCard(password),
      );
    },
  );
}

// Boite de dialogue de confirmation
Future<bool> _confirmDeleteDialog(PasswordModel password) async {
  return await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Supprimer le mot de passe'),
      content: Text('Voulez-vous vraiment supprimer "${password.title}"? Cette action ne peut pas être annulée.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.errorColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  ) ?? false;
}
  Widget _buildPasswordCard(PasswordModel password) {
  // Modification: ajouter de la semantics pour l'accessibilité
  return Semantics(
    label: 'Mot de passe pour ${password.title}',
    hint: 'Balayez vers la gauche pour mettre en favori, vers la droite pour supprimer',
    button: true,
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
    child: Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Category icon
              Hero(
                tag: 'icon_${password.id}',
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(password).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getCategoryIcon(password),
                    color: _getCategoryColor(password),
                    size: 24,
                  ),
                ),
              ),
              SizedBox(width: 16),
              
              // Password info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            password.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (password.isFavorite)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      password.username,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (password.website.isNotEmpty) ...[
                      SizedBox(height: 2),
                      Text(
                        password.website,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              
              // Action button
              IconButton(
                icon: const Icon(Icons.content_copy),
                tooltip: 'Copier le mot de passe',
                iconSize: 20,
                onPressed: () => _copyToClipboard(password.password, 'Mot de passe'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
  
  Color _getCategoryColor(PasswordModel password) {
    if (password.title.toLowerCase().contains('bank') || 
        password.title.toLowerCase().contains('credit') ||
        password.title.toLowerCase().contains('banque') ||
        password.title.toLowerCase().contains('carte')) {
      return Colors.green;
    } else if (password.website.isNotEmpty) {
      return AppTheme.primaryColor;
    } else if (password.title.toLowerCase().contains('app')) {
      return Colors.purple;
    } else if (password.title.toLowerCase().contains('email') || 
               password.title.toLowerCase().contains('mail')) {
      return Colors.orange;
    }
    return Colors.grey;
  }
  
  IconData _getCategoryIcon(PasswordModel password) {
    if (password.title.toLowerCase().contains('bank') || 
        password.title.toLowerCase().contains('credit') ||
        password.title.toLowerCase().contains('banque') ||
        password.title.toLowerCase().contains('carte')) {
      return Icons.account_balance;
    } else if (password.website.isNotEmpty) {
      return Icons.language;
    } else if (password.title.toLowerCase().contains('app')) {
      return Icons.apps;
    } else if (password.title.toLowerCase().contains('email') || 
               password.title.toLowerCase().contains('mail')) {
      return Icons.email;
    }
    return Icons.lock;
  }
  
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}