import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:monpass/screens/auth/login_screen.dart';
import 'package:monpass/screens/home/home_screen.dart';
import 'package:monpass/screens/otp_verification_screen.dart';

Future<void> main() async {
  // Initialisation Flutter et Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MonPass',
      debugShowCheckedModeBanner: false,
      
      // Thème de l'application
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
        
        // Thème de la AppBar
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        // Thème des boutons élevés
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        
        // Thème des boutons texte
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue,
          ),
        ),
        
        // Thème des champs texte
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        
        // Thème des cartes
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        ),
      ),
      
      // Routes de l'application
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/otp-verification': (context) => const OtpVerificationScreen(),
        '/home': (context) => const HomeScreen(),
        // Vous pouvez ajouter d'autres routes ici selon votre application
      },
      
      // Route initiale - utilisera la SplashScreen pour déterminer où aller
      initialRoute: '/',
    );
  }
}

// Écran de chargement pour déterminer la route initiale
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  // Vérifier l'état d'authentification et rediriger en conséquence
  Future<void> _checkAuthState() async {
    final user = FirebaseAuth.instance.currentUser;
    
    // Attendre un court instant pour l'animation de splash (optionnel)
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (user == null) {
      // Non connecté, rediriger vers la page de connexion
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } else {
      // Vérifier si l'utilisateur a déjà complété l'authentification à deux facteurs
      final hasCompletedTwoFactor = user.phoneNumber != null;
      
      if (hasCompletedTwoFactor) {
        // 2FA complété, aller à l'accueil
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        // 2FA non complété, aller à la vérification OTP
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/otp-verification', 
            arguments: {'user': user}
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo de l'application
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Colors.blue,
              ),
              
              const SizedBox(height: 24),
              
              // Nom de l'application
              const Text(
                'MonPass',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Indicateur de chargement
              const CircularProgressIndicator(
                color: Colors.blue,
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}