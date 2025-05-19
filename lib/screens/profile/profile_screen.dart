import 'package:flutter/material.dart';
import 'package:monpass/services/auth_service.dart';
import 'package:monpass/services/user_service.dart';
import 'package:monpass/screens/profile/edit_profile_screen.dart';
import 'package:monpass/screens/settings/security_settings_screen.dart';
import 'package:monpass/screens/auth/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';



class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      Map<String, dynamic>? profile = await _userService.getUserProfile();
      setState(() {
        _userProfile = profile;
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
        title: Text('Mon Profil'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Déconnexion',
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
                    // Photo de profil et informations de base
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 45,
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                          child: Icon(
                            Icons.person,
                            size: 45,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userProfile?['displayName'] ?? 'Utilisateur',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _userProfile?['email'] ?? 'Pas d\'email',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    _userProfile?['is2FAEnabled'] == true
                                        ? Icons.verified_user
                                        : Icons.security,
                                    size: 16,
                                    color: _userProfile?['is2FAEnabled'] == true
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _userProfile?['is2FAEnabled'] == true
                                        ? '2FA activée'
                                        : '2FA non activée',
                                    style: TextStyle(
                                      color: _userProfile?['is2FAEnabled'] == true
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Bouton Modifier le profil
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditProfileScreen(
                              userProfile: _userProfile,
                            ),
                          ),
                        );
                        
                        if (result == true) {
                          _loadUserProfile();
                        }
                      },
                      icon: Icon(Icons.edit),
                      label: Text('Modifier le profil'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Theme.of(context).primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Section Informations
                    Text(
                      'Informations',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              icon: Icons.phone,
                              title: 'Téléphone',
                              value: _userProfile?['phoneNumber'] ?? 'Non défini',
                            ),
                            const Divider(),
                            _buildInfoRow(
                              icon: Icons.email,
                              title: 'Email',
                              value: _userProfile?['email'] ?? 'Non défini',
                            ),
                            if (_userProfile?['createdAt'] != null) ...[
                              const Divider(),
                              _buildInfoRow(
                                icon: Icons.calendar_today,
                                title: 'Membre depuis',
                                value: _formatTimestamp(_userProfile?['createdAt']),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Section Sécurité
                    Text(
                      'Sécurité',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.security,
                              color: Theme.of(context).primaryColor,
                            ),
                            title: Text('Authentification à deux facteurs'),
                            subtitle: Text(
                              _userProfile?['is2FAEnabled'] == true
                                  ? 'Activée - ${_userProfile?['phoneNumber'] ?? ''}'
                                  : 'Non activée',
                            ),
                            trailing: Icon(Icons.chevron_right),
                            onTap: () async {
                              final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SecuritySettingsScreen(
                                  is2FAEnabled: _userProfile?['is2FAEnabled'] == true,
                                ),
                              ),
                            );
                              
                              if (result == true) {
                                _loadUserProfile();
                              }
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              Icons.password,
                              color: Theme.of(context).primaryColor,
                            ),
                            title: Text('Changer le mot de passe'),
                            trailing: Icon(Icons.chevron_right),
                            onTap: () {
                              // TODO: Naviguer vers l'écran de changement de mot de passe
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Bouton de déconnexion
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _signOut,
                        icon: Icon(Icons.logout),
                        label: Text('Déconnexion'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

String _formatTimestamp(dynamic timestamp) {
  if (timestamp == null) return 'Non défini';
  
  try {
    DateTime date = (timestamp as Timestamp).toDate();
    return '${date.day}/${date.month}/${date.year}';
  } catch (e) {
    return 'Date inconnue';
  }
}
}