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
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Set status bar color
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
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
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    
    return MaterialApp(
      title: 'MonPass',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: AuthGate(),
      // Ajouter un moyen de changer le thème
      navigatorObservers: [
        // Observer pour injecter la fonction de changement de thème
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