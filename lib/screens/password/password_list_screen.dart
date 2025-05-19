import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/password_model.dart';
import '../../services/auth_service.dart';
import '../../services/password_service.dart';
import '../../services/secure_storage_service.dart';
import 'add_password_screen.dart';
import 'edit_password_screen.dart';
import 'password_detail_screen.dart';
import '../auth/login_screen.dart';

class PasswordListScreen extends StatefulWidget {
  const PasswordListScreen({Key? key}) : super(key: key);

  @override
  _PasswordListScreenState createState() => _PasswordListScreenState();
}

class _PasswordListScreenState extends State<PasswordListScreen> {
  final AuthService _authService = AuthService();
  late SecureStorageService _secureStorage;
  late PasswordService _passwordService;
  
  List<PasswordModel> _passwords = [];
  List<PasswordModel> _filteredPasswords = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _onlyFavorites = false;
  
  @override
  void initState() {
    super.initState();
    _initServices();
  }
  
  Future<void> _initServices() async {
    _secureStorage = SecureStorageService();
    // Simuler la saisie d'un mot de passe maître
    await _secureStorage.setMasterPassword('masterpassword');
    
    String? userId = await _authService.getUserId();
    if (userId == null) {
      // Rediriger vers login si pas d'ID utilisateur
      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => LoginScreen())
        );
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
      _showErrorSnackBar('Erreur de chargement des mots de passe');
    }
  }
  
  void _applyFilters() {
    List<PasswordModel> filtered = List.from(_passwords);
    
    // Filtrer par recherche
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((password) {
        return password.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               password.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               password.website.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    // Filtrer par favoris
    if (_onlyFavorites) {
      filtered = filtered.where((password) => password.isFavorite).toList();
    }
    
    setState(() {
      _filteredPasswords = filtered;
    });
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
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
                backgroundColor: Colors.red,
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
            SnackBar(content: Text('Mot de passe supprimé')),
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
        content: Text('$label copié dans le presse-papiers'),
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la déconnexion');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mes mots de passe'),
        actions: [
          IconButton(
            icon: Icon(_onlyFavorites ? Icons.star : Icons.star_border),
            tooltip: 'Afficher les favoris',
            onPressed: () {
              setState(() {
                _onlyFavorites = !_onlyFavorites;
                _applyFilters();
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: _signOut,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Barre de recherche
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _applyFilters();
                      });
                    },
                  ),
                ),
                
                // Liste des mots de passe
                Expanded(
                  child: _filteredPasswords.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_open,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty && !_onlyFavorites
                                    ? 'Aucun mot de passe enregistré'
                                    : 'Aucun mot de passe trouvé',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 24),
                              if (_searchQuery.isEmpty && !_onlyFavorites)
                                ElevatedButton.icon(
                                  icon: Icon(Icons.add),
                                  label: Text('Ajouter un mot de passe'),
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
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredPasswords.length,
                          itemBuilder: (context, index) {
                            PasswordModel password = _filteredPasswords[index];
                            return Dismissible(
                              key: Key(password.id),
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                child: Icon(Icons.delete, color: Colors.white),
                              ),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) async {
                                return await showDialog<bool>(
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
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: Text('Supprimer'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              onDismissed: (direction) {
                                _deletePassword(password);
                              },
                              child: Card(
                                elevation: 2,
                                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                    child: Icon(
                                      Icons.lock,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  title: Text(
                                    password.title,
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(password.username),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          password.isFavorite ? Icons.star : Icons.star_border,
                                          color: password.isFavorite ? Colors.amber : null,
                                        ),
                                        onPressed: () => _toggleFavorite(password),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.copy),
                                        onPressed: () => _copyToClipboard(password.password, 'Mot de passe'),
                                      ),
                                    ],
                                  ),
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
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
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
      ),
    );
  }
}