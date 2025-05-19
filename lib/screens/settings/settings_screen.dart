import 'package:flutter/material.dart';
import 'package:monpass/services/auth_service.dart';
import 'package:monpass/services/user_service.dart';
import 'package:monpass/screens/settings/security_settings_screen.dart';
import 'package:monpass/screens/auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  
  bool _isLoading = false;
  bool _is2FAEnabled = false;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      bool is2FAEnabled = await _authService.is2FAEnabled();
      setState(() {
        _is2FAEnabled = is2FAEnabled;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _signOut() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la déconnexion: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Paramètres'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Section Compte
                _buildSectionHeader('Compte'),
                ListTile(
                  leading: Icon(Icons.person, color: Theme.of(context).primaryColor),
                  title: Text('Informations personnelles'),
                  subtitle: Text('Modifier votre nom et vos coordonnées'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Naviguer vers les informations personnelles
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.security, color: Theme.of(context).primaryColor),
                  title: Text('Sécurité'),
                  subtitle: Text(
                    _is2FAEnabled
                        ? 'Authentification à deux facteurs activée'
                        : 'Authentification à deux facteurs désactivée'
                  ),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SecuritySettingsScreen(
                          is2FAEnabled: _is2FAEnabled,
                        ),
                      ),
                    );
                    
                    if (result == true) {
                      _loadSettings();
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.password, color: Theme.of(context).primaryColor),
                  title: Text('Changer le mot de passe'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Naviguer vers le changement de mot de passe
                  },
                ),
                
                // Section Notification
                _buildSectionHeader('Notifications'),
                SwitchListTile(
                  title: Text('Notifications push'),
                  subtitle: Text('Recevoir des notifications de l\'application'),
                  value: true, // À remplacer par une valeur réelle
                  onChanged: (value) {
                    // TODO: Implémenter la gestion des notifications
                  },
                  secondary: Icon(Icons.notifications, color: Theme.of(context).primaryColor),
                ),
                const Divider(),
                SwitchListTile(
                  title: Text('Alertes de sécurité'),
                  subtitle: Text('Recevoir des alertes en cas d\'activité suspecte'),
                  value: true, // À remplacer par une valeur réelle
                  onChanged: (value) {
                    // TODO: Implémenter la gestion des alertes
                  },
                  secondary: Icon(Icons.security, color: Theme.of(context).primaryColor),
                ),
                
                // Section App
                _buildSectionHeader('Application'),
                ListTile(
                  leading: Icon(Icons.language, color: Theme.of(context).primaryColor),
                  title: Text('Langue'),
                  subtitle: Text('Français'), // À remplacer par la langue réelle
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Naviguer vers le changement de langue
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.dark_mode, color: Theme.of(context).primaryColor),
                  title: Text('Thème'),
                  subtitle: Text('Clair'), // À remplacer par le thème réel
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Naviguer vers le changement de thème
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                  title: Text('À propos'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Naviguer vers l'écran à propos
                  },
                ),
                
                // Section Déconnexion
                _buildSectionHeader('Session'),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    'Déconnexion',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: _signOut,
                ),
              ],
            ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}