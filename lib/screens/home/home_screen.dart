import 'package:flutter/material.dart';
import 'package:monpass/services/auth_service.dart';
import 'package:monpass/services/user_service.dart';
import 'package:monpass/screens/profile/profile_screen.dart';
import 'package:monpass/screens/settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  
  int _currentIndex = 0;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  
  final List<Widget> _pages = [];
  
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
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
          
          // Initialiser les pages une fois que nous avons le profil utilisateur
          _initPages();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _initPages() {
    _pages.clear();
    _pages.addAll([
      _buildDashboardPage(),
      ProfileScreen(),
      SettingsScreen(),
    ]);
  }
  
  Widget _buildDashboardPage() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec salutation
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                    child: Icon(
                      Icons.person,
                      size: 30,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bonjour,',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          _userProfile?['displayName'] ?? 'Utilisateur',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.notifications_outlined),
                    onPressed: () {
                      // TODO: Naviguer vers les notifications
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Informations principales
              Text(
                'Mon compte',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Carte de sécurité
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _userProfile?['is2FAEnabled'] == true
                                ? Icons.verified_user
                                : Icons.security,
                            color: _userProfile?['is2FAEnabled'] == true
                                ? Colors.green
                                : Colors.orange,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Statut de sécurité',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: _userProfile?['is2FAEnabled'] == true ? 1.0 : 0.5,
                              backgroundColor: Colors.grey[200],
                              color: _userProfile?['is2FAEnabled'] == true
                                  ? Colors.green
                                  : Colors.orange,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _userProfile?['is2FAEnabled'] == true ? '100%' : '50%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _userProfile?['is2FAEnabled'] == true
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _userProfile?['is2FAEnabled'] == true
                            ? 'Votre compte est entièrement protégé'
                            : 'Activez l\'authentification à deux facteurs pour renforcer la sécurité',
                        style: TextStyle(
                          color: Colors.grey[700],
                        ),
                      ),
                      if (_userProfile?['is2FAEnabled'] != true) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/settings/security');
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text('Activer maintenant'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Fonctionnalités rapides
              Text(
                'Fonctionnalités rapides',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickAccessButton(
                    icon: Icons.person,
                    label: 'Profil',
                    onTap: () {
                      setState(() {
                        _currentIndex = 1;
                      });
                    },
                  ),
                  _buildQuickAccessButton(
                    icon: Icons.security,
                    label: 'Sécurité',
                    onTap: () {
                      Navigator.pushNamed(context, '/settings/security');
                    },
                  ),
                  _buildQuickAccessButton(
                    icon: Icons.settings,
                    label: 'Paramètres',
                    onTap: () {
                      setState(() {
                        _currentIndex = 2;
                      });
                    },
                  ),
                  _buildQuickAccessButton(
                    icon: Icons.help_outline,
                    label: 'Aide',
                    onTap: () {
                      // TODO: Naviguer vers l'aide
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildQuickAccessButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 30,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? Scaffold(
            body: Center(child: CircularProgressIndicator()),
          )
        : Scaffold(
            body: _pages.isEmpty ? Container() : _pages[_currentIndex],
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: 'Accueil',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profil',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Paramètres',
                ),
              ],
            ),
          );
  }
}