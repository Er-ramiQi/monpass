// lib/app.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/auth/auth_gate.dart';

class MonPassApp extends StatelessWidget {
  const MonPassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MonPass',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          primary: const Color(0xFF2196F3),
          secondary: const Color(0xFF64B5F6),
          background: Colors.white,
        ),
        textTheme: GoogleFonts.nunitoTextTheme(),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
