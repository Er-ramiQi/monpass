// lib/screens/password/password_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/password_model.dart';
import '../../services/auth_service.dart';
import '../../services/password_service.dart';
import '../../services/secure_storage_service.dart';
import '../../theme/app_theme.dart';
import 'edit_password_screen.dart';

class PasswordDetailScreen extends StatefulWidget {
  final PasswordModel password;
  
  const PasswordDetailScreen({
    super.key,
    required this.password,
  });

  @override
  _PasswordDetailScreenState createState() => _PasswordDetailScreenState();
}

class _PasswordDetailScreenState extends State<PasswordDetailScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late SecureStorageService _secureStorage;
  late PasswordService _passwordService;
  
  bool _isLoading = false;
  bool _passwordVisible = false;
  late PasswordModel _password;
  
  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    _password = widget.password;
    _initServices();
    
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    
    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
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
  
  // Modifier la partie de navigation dans _deletePassword pour indiquer des modifications
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
              backgroundColor: AppTheme.errorColor,
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
        // Retourner true pour indiquer une modification
        Navigator.pop(context, true);
      } else {
        _showErrorSnackBar('Erreur lors de la suppression');
        setState(() {
          _isLoading = false;
        });
      }
    }
  } catch (e) {
    _showErrorSnackBar('Erreur lors de la suppression');
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
    // Get screen dimensions for responsive layout
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 600;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Détails du mot de passe'),
        actions: [
          IconButton(
            icon: Icon(
              _password.isFavorite ? Icons.star : Icons.star_border,
              color: _password.isFavorite ? Colors.amber : Colors.white,
            ),
            tooltip: _password.isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: Icon(Icons.edit),
            tooltip: 'Modifier',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditPasswordScreen(password: _password),
                ),
              );
              
              if (result == true) {
                // Reload the password details
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
            tooltip: 'Supprimer',
            onPressed: _deletePassword,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: isTablet
                      ? _buildTabletLayout()
                      : _buildPhoneLayout(),
                ),
              ),
            ),
    );
  }
  
  Widget _buildPhoneLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with icon and title
        Center(
          child: Column(
            children: [
              // Category icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _getCategoryColor().withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getCategoryIcon(),
                  size: 40,
                  color: _getCategoryColor(),
                ),
              ),
              
              SizedBox(height: 20),
              
              // Title and website
              Text(
                _password.title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              
              if (_password.website.isNotEmpty) ...[
                SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    _copyToClipboard(_password.website, 'Site web');
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.language,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 6),
                      Text(
                        _password.website,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.content_copy,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        
        SizedBox(height: 32),
        
        // Username card
        _buildInfoCard(
          title: 'Nom d\'utilisateur',
          value: _password.username,
          icon: Icons.person,
          onCopy: () => _copyToClipboard(_password.username, 'Nom d\'utilisateur'),
        ),
        
        SizedBox(height: 16),
        
        // Password card
        _buildPasswordCard(),
        
        // Notes (if any)
        if (_password.notes.isNotEmpty) ...[
          SizedBox(height: 16),
          _buildInfoCard(
            title: 'Notes',
            value: _password.notes,
            icon: Icons.note,
            onCopy: () => _copyToClipboard(_password.notes, 'Notes'),
          ),
        ],
        
        SizedBox(height: 32),
        
        // Creation and update info
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
                  'Informations',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Text(
                      'Créé le: ${_formatDate(_password.createdAt)}',
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.update, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Text(
                      'Modifié le: ${_formatDate(_password.updatedAt)}',
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        SizedBox(height: 24),
        
        // Quick actions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              icon: Icons.content_copy,
              label: 'Copier',
              onTap: () => _copyToClipboard(_password.password, 'Mot de passe'),
            ),
            _buildActionButton(
              icon: Icons.edit,
              label: 'Modifier',
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditPasswordScreen(password: _password),
                  ),
                );
                
                if (result == true) {
                  // Reload the password details
                  PasswordModel? updated = await _passwordService.getPasswordById(_password.id);
                  if (updated != null) {
                    setState(() {
                      _password = updated;
                    });
                  }
                }
              },
            ),
            _buildActionButton(
              icon: Icons.delete_outline,
              label: 'Supprimer',
              onTap: _deletePassword,
              color: Colors.red,
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildTabletLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column (icon and basic info)
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Category icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: _getCategoryColor().withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getCategoryIcon(),
                  size: 60,
                  color: _getCategoryColor(),
                ),
              ),
              
              SizedBox(height: 24),
              
              // Title
              Text(
                _password.title,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              
              // Website
              if (_password.website.isNotEmpty) ...[
                SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    _copyToClipboard(_password.website, 'Site web');
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.language,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 8),
                      Text(
                        _password.website,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.content_copy,
                        size: 16,
                        color: Colors.grey[500],
                      ),
                    ],
                  ),
                ),
              ],
              
              SizedBox(height: 32),
              
              // Creation and update info
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
                        'Informations',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                          SizedBox(width: 8),
                          Text(
                            'Créé le: ${_formatDate(_password.createdAt)}',
                            style: TextStyle(
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.update, size: 16, color: Colors.grey[600]),
                          SizedBox(width: 8),
                          Text(
                            'Modifié le: ${_formatDate(_password.updatedAt)}',
                            style: TextStyle(
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 32),
              
              // Quick actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.star,
                    label: _password.isFavorite ? 'Retiré des favoris' : 'Ajouter aux favoris',
                    onTap: _toggleFavorite,
                    color: _password.isFavorite ? Colors.amber : null,
                  ),
                  _buildActionButton(
                    icon: Icons.delete_outline,
                    label: 'Supprimer',
                    onTap: _deletePassword,
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
        
        SizedBox(width: 24),
        
        // Right column (credentials)
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Username card
              _buildInfoCard(
                title: 'Nom d\'utilisateur',
                value: _password.username,
                icon: Icons.person,
                onCopy: () => _copyToClipboard(_password.username, 'Nom d\'utilisateur'),
              ),
              
              SizedBox(height: 16),
              
              // Password card
              _buildPasswordCard(),
              
              // Notes (if any)
              if (_password.notes.isNotEmpty) ...[
                SizedBox(height: 16),
                _buildInfoCard(
                  title: 'Notes',
                  value: _password.notes,
                  icon: Icons.note,
                  onCopy: () => _copyToClipboard(_password.notes, 'Notes'),
                  maxLines: 10,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onCopy,
    int maxLines = 3,
  }) {
    return Card(
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
              children: [
                Icon(icon, color: AppTheme.primaryColor),
                SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                    maxLines: maxLines,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.content_copy, color: AppTheme.primaryColor),
                  onPressed: onCopy,
                  tooltip: 'Copier',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPasswordCard() {
    return Card(
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
              children: [
                Icon(Icons.lock, color: AppTheme.primaryColor),
                SizedBox(width: 10),
                Text(
                  'Mot de passe',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
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
                      _passwordVisible ? _password.password : '••••••••••••••••',
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: _passwordVisible ? 'monospace' : null,
                        letterSpacing: _passwordVisible ? 1.0 : 2.0,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _passwordVisible ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey[700],
                    ),
                    onPressed: () {
                      setState(() {
                        _passwordVisible = !_passwordVisible;
                      });
                    },
                    tooltip: _passwordVisible ? 'Masquer' : 'Afficher',
                  ),
                  IconButton(
                    icon: Icon(Icons.content_copy, color: AppTheme.primaryColor),
                    onPressed: () => _copyToClipboard(_password.password, 'Mot de passe'),
                    tooltip: 'Copier',
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            // Password strength indicator
            Row(
              children: [
                Text(
                  'Force: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  _getPasswordStrengthLabel(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getPasswordStrengthColor(),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _getPasswordStrengthScore() / 100,
                      backgroundColor: Colors.grey[200],
                      color: _getPasswordStrengthColor(),
                      minHeight: 8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color ?? AppTheme.primaryColor,
              size: 28,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color ?? Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getCategoryColor() {
    if (_password.title.toLowerCase().contains('bank') || 
        _password.title.toLowerCase().contains('credit') ||
        _password.title.toLowerCase().contains('banque') ||
        _password.title.toLowerCase().contains('carte')) {
      return Colors.green;
    } else if (_password.website.isNotEmpty) {
      return AppTheme.primaryColor;
    } else if (_password.title.toLowerCase().contains('app')) {
      return Colors.purple;
    } else if (_password.title.toLowerCase().contains('email') || 
               _password.title.toLowerCase().contains('mail')) {
      return Colors.orange;
    }
    return Colors.grey;
  }
  
  IconData _getCategoryIcon() {
    if (_password.title.toLowerCase().contains('bank') || 
        _password.title.toLowerCase().contains('credit') ||
        _password.title.toLowerCase().contains('banque') ||
        _password.title.toLowerCase().contains('carte')) {
      return Icons.account_balance;
    } else if (_password.website.isNotEmpty) {
      return Icons.language;
    } else if (_password.title.toLowerCase().contains('app')) {
      return Icons.apps;
    } else if (_password.title.toLowerCase().contains('email') || 
               _password.title.toLowerCase().contains('mail')) {
      return Icons.email;
    }
    return Icons.lock;
  }
  
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
  
  // Calculate password strength score (0-100)
  int _getPasswordStrengthScore() {
    if (_password.password.isEmpty) return 0;
    
    final password = _password.password;
    int score = 0;
    
    // Length (up to 40 points)
    score += password.length * 2;
    if (score > 40) score = 40;
    
    // Complexity (up to a total of 50 additional points)
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 10;
    if (RegExp(r'[a-z]').hasMatch(password)) score += 10;
    if (RegExp(r'[0-9]').hasMatch(password)) score += 10;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score += 20;
    
    // Penalize for repeating characters and patterns
    int repeats = 0;
    for (int i = 0; i < password.length - 1; i++) {
      if (password[i] == password[i + 1]) repeats++;
    }
    score -= repeats * 2;
    
    // Common patterns penalty
    if (RegExp(r'123|abc|qwerty|password|admin', caseSensitive: false).hasMatch(password)) {
      score -= 20;
    }
    
    return score < 0 ? 0 : (score > 100 ? 100 : score);
  }
  
  String _getPasswordStrengthLabel() {
    final score = _getPasswordStrengthScore();
    if (score < 40) {
      return 'Faible';
    } else if (score < 70) {
      return 'Moyen';
    } else if (score < 90) {
      return 'Fort';
    } else {
      return 'Très fort';
    }
  }
  
  Color _getPasswordStrengthColor() {
    final score = _getPasswordStrengthScore();
    if (score < 40) {
      return Colors.red;
    } else if (score < 70) {
      return Colors.orange;
    } else if (score < 90) {
      return Colors.green;
    } else {
      return Colors.green.shade700;
    }
  }
}