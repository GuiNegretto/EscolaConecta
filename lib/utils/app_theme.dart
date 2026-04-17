import 'package:flutter/material.dart';

class AppTheme {
  //  BASE
  static const Color primaryBlue = Color.fromRGBO(7, 29, 66, 1);
  static const Color accentBlue = Color(0xFF3D6FFF);

  //  LIGHT COLORS
  static const Color lightBg = Colors.white;
  static const Color lightCard = Color(0xFFF5F6FA);
  static const Color lightTextPrimary = Colors.black;
  static const Color lightTextSecondary = Color(0xFF6C757D);
  static const Color lightDivider = Color(0xFFE0E0E0);

  //  DARK COLORS
  static const Color darkBg = Color(0xFF0D0D0D);
  static const Color darkCard = Color(0xFF1A1A2E);
  static const Color darkSurface = Color(0xFF16213E);
  static const Color darkInput = Color(0xFF1E1E2E);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFFADB5BD);
  static const Color darkDivider = Color(0xFF2A2A3E);
  static const Color success = Color(0xFF28A745);
  static const Color warning = Color(0xFFFFC107);
  static const Color danger = Color(0xFFDC3545);

  //  LIGHT THEME
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      scaffoldBackgroundColor: lightBg,

      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: accentBlue,
        surface: lightCard,
        onPrimary: Colors.white,
        onSurface: lightTextPrimary,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
      ),

      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: lightTextPrimary),
        bodyMedium: TextStyle(color: lightTextSecondary),
      ),

      dividerColor: lightDivider,
    );
  }

  //  DARK THEME
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      scaffoldBackgroundColor: darkBg,

      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: accentBlue,
        surface: darkCard,
        onPrimary: Colors.white,
        onSurface: darkTextPrimary,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
      ),

      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkDivider),
        ),
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: darkTextPrimary),
        bodyMedium: TextStyle(color: darkTextSecondary),
      ),

      dividerColor: darkDivider,
    );
  }
}

extension ThemeExtras on BuildContext {
  Color get textMuted =>
      Theme.of(this).colorScheme.onSurface.withOpacity(0.6);
}

class AppConstants {
  static const String baseUrl = 'https://690a89a81a446bb9cc22d695.mockapi.io/';
  //static const String baseUrl = 'http://localhost:3000/api';
  
  // Endpoints
  static const String loginEndpoint = '/auth';
  //static const String loginEndpoint = '/auth/login';
  static const String messagesEndpoint = '/messages';
  static const String studentsEndpoint = '/students';
  static const String parentsEndpoint = '/parents';
  static const String sendMessageEndpoint = '/messages/send';
  static const String profileEndpoint = '/profile';
}

