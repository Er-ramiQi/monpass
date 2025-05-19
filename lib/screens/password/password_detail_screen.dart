import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/password_model.dart';
import '../../services/auth_service.dart';
import '../../services/password_service.dart';
import '../../services/secure_storage_service.dart';
import 'edit_password_screen.dart';

class PasswordDetailScreen extends StatefulWidget {
  final PasswordModel password;
  
  const PasswordDetailScreen({
    Key? key,
    required this.password,
  }) : super(key: key);

  @override
  _PasswordDetailScreenState createState() => _PasswordDetailScreenState();
}

class _PasswordDetailScreenState extends State<PasswordDetailScreen> {
  final AuthService _authService = AuthService();
  late SecureStorageService _secureStorage;
  late PasswordService _passwordService;
  
  bool _isLoading = false;
  bool _passwordVisible = false;
  late PasswordModel _password;
  
  @override
  void initState() {
    super.initState();
    _password = widget.password;
    _initServices();
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
  
  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copié dans le presse-papiers'),
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  Future<void> _toggleFavorite() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _passwordService.toggleFavorite(_password.id);
      PasswordModel? updated = await _passwordService.getPasswordById(_password.id);
      
      if (updated != null) {
        setState(() {
          _password = updated;
          _isLoading = false;
        });
      } else {
        _showErrorSnackBar('Erreur lors de la mise à jour');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors du changement de statut favori');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _deletePassword() async {
    try {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Confirmer la suppression'),
          content: Text('Voulez-vous vraiment supprimer "${_password.title}"?'),
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
        setState(() {
          _isLoading = true;
        });
        
        bool success = await _passwordService.deletePassword(_password.id);
        
        if (success) {
          Navigator.pop(context, true); // Vrai indique que des modifications ont été apportées
        } else {
          _showErrorSnackBar('Erreur lors de la suppression');
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la suppression');
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
        title: Text('Détails du mot de passe'),
        actions: [
          IconButton(
            icon: Icon(
              _password.isFavorite ? Icons.star : Icons.star_border,
              color: _password.isFavorite ? Colors.amber : null,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditPasswordScreen(password: _password),
                ),
              );
              
              if (result == true) {
                // Recharger les détails
                PasswordModel? updated = await _passwordService.getPasswordById(_password.id);
                if (updated != null) {
                  setState(() {
                    _password = updated;
                  });
                }
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline),
            onPressed: _deletePassword,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                            child: Icon(
                              Icons.lock,
                              size: 40,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            _password.title,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_password.website.isNotEmpty) ...[
                            SizedBox(height: 8),
                            Text(
                              _password.website,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: 32),
                    
                    // Nom d'utilisateur
                    _buildInfoCard(
                      title: 'Nom d\'utilisateur',
                      value: _password.username,
                      icon: Icons.person,
                      onCopy: () => _copyToClipboard(_password.username, 'Nom d\'utilisateur'),
                    ),
                    SizedBox(height: 16),
                    
                    // Mot de passe
                    _buildPasswordCard(
                      password: _password.password,
                      isVisible: _passwordVisible,
                      onToggleVisibility: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                      onCopy: () => _copyToClipboard(_password.password, 'Mot de passe'),
                    ),
                    
                    // Notes
                    if (_password.notes.isNotEmpty) ...[
                      SizedBox(height: 16),
                      _buildInfoCard(
                        title: 'Notes',
                        value: _password.notes,
                        icon: Icons.note,
                        onCopy: () => _copyToClipboard(_password.notes, 'Notes'),
                      ),
                    ],
                    
                    SizedBox(height: 24),
                    
                    // Métadonnées
                    Card(
                      elevation: 0,
                      color: Colors.grey[100],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Détails',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                SizedBox(width: 8),
                                Text(
                                  'Créé le: ${_formatDate(_password.createdAt)}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.update, size: 16, color: Colors.grey[600]),
                                SizedBox(width: 8),
                                Text(
                                  'Modifié le: ${_formatDate(_password.updatedAt)}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
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
  
  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onCopy,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy),
                  onPressed: onCopy,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPasswordCard({
    required String password,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    required VoidCallback onCopy,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock, color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Text(
                  'Mot de passe',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isVisible ? password : '••••••••••••••••',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: isVisible ? 'monospace' : null,
                      letterSpacing: isVisible ? 1.0 : 2.0,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: onToggleVisibility,
                ),
                IconButton(
                  icon: Icon(Icons.copy),
                  onPressed: onCopy,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}