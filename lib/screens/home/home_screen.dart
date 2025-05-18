// Remplacez la méthode de déconnexion par celle-ci

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/biometric_service.dart';
import '../settings/biometric_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    if (!mounted) return;
    
    bool isAvailable = await BiometricService.isBiometricAvailable();
    bool isEnabled = false;
    
    if (isAvailable) {
      isEnabled = await BiometricService.isBiometricEnabled();
    }
    
    if (mounted) {
      setState(() {
        _isBiometricAvailable = isAvailable;
        _isBiometricEnabled = isEnabled;
      });
    }
  }

  // Méthode de déconnexion qui préserve les identifiants biométriques
Future<void> _signOut() async {
  try {
    // Vérifier que les identifiants sont présents avant la déconnexion
    bool hasCredentials = await BiometricService.hasCredentials();
    bool biometricEnabled = await BiometricService.isBiometricEnabled();
    
    debugPrint('🔒 Avant déconnexion - Identifiants présents: $hasCredentials, Biométrie activée: $biometricEnabled');
    
    // IMPORTANT: Se déconnecter de Firebase SANS supprimer les données biométriques
    await FirebaseAuth.instance.signOut();
    
    // Vérifier à nouveau après la déconnexion
    hasCredentials = await BiometricService.hasCredentials();
    biometricEnabled = await BiometricService.isBiometricEnabled();
    
    debugPrint('🔓 Après déconnexion - Identifiants présents: $hasCredentials, Biométrie activée: $biometricEnabled');
    
    // Message de confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasCredentials 
                ? 'Vous êtes déconnecté. Connexion par empreinte toujours disponible.'
                : 'Vous êtes déconnecté. La connexion par empreinte n\'est pas disponible.'
          ),
          backgroundColor: hasCredentials ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  } catch (e) {
    debugPrint('⚠️ Erreur lors de la déconnexion: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la déconnexion: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MonPass'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Bouton de déconnexion
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut, // Utiliser notre méthode personnalisée
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_open,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Bienvenue sur MonPass!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'Vous êtes connecté: ${FirebaseAuth.instance.currentUser?.email}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 40),
            
            // Bouton Paramètres biométriques (si disponible)
            if (_isBiometricAvailable) ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BiometricSettingsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.fingerprint),
                label: const Text('Paramètres biométriques'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // Bouton de déconnexion
            ElevatedButton.icon(
              onPressed: _signOut, // Utiliser notre méthode personnalisée
              icon: const Icon(Icons.logout),
              label: const Text('Se déconnecter'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}