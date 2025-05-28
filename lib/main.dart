// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/auth_gate.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,  // Added support for landscape on tablets
    DeviceOrientation.landscapeRight, // Added support for landscape on tablets
  ]);
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Erreur d\'initialisation Firebase: $e');
    // Continuer même si Firebase échoue pour permettre le fonctionnement hors ligne
  }
  
  // Set status bar color
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }
  
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeString = prefs.getString('theme_mode') ?? 'system';
      
      setState(() {
        _themeMode = _getThemeModeFromString(themeString);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur de chargement des préférences: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  ThemeMode _getThemeModeFromString(String themeString) {
    switch (themeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
  
  void _setThemeMode(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      String themeString;
      
      switch (mode) {
        case ThemeMode.light:
          themeString = 'light';
          break;
        case ThemeMode.dark:
          themeString = 'dark';
          break;
        default:
          themeString = 'system';
      }
      
      await prefs.setString('theme_mode', themeString);
    } catch (e) {
      debugPrint('Erreur de sauvegarde du thème: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF667eea),
                  const Color.fromARGB(255, 75, 105, 162),
                ],
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'MonPass',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Initialisation...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
      );
    }
    
    return MaterialApp(
      title: 'MonPass',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: const AuthGate(),
      // Gestionnaire d'erreurs global
      builder: (context, child) {
        ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF667eea),
                    const Color.fromARGB(255, 75, 105, 162),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 64,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Oops! Une erreur s\'est produite',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Veuillez redémarrer l\'application',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        SystemNavigator.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF667eea),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Fermer l\'application',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        };
        return child!;
      },
      // Routes nommées pour une meilleure navigation
      routes: {
        '/login': (context) => const AuthGate(),
      },
      // Gestionnaire de navigation globale
      navigatorObservers: [
        _ThemeObserver((ThemeMode mode) {
          _setThemeMode(mode);
        }),
      ],
    );
  }
}

// Observer pour passer la fonction de changement de thème aux écrans qui en ont besoin
class _ThemeObserver extends NavigatorObserver {
  final Function(ThemeMode) onThemeChanged;
  
  _ThemeObserver(this.onThemeChanged);
  
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    
    if (route.settings.name == '/settings') {
      // Injecter le callback de changement de thème
      (route.settings.arguments as Map<String, dynamic>?)?['onThemeChanged'] = onThemeChanged;
    }
  }
}