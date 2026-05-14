import 'package:flutter/material.dart';

class AppTheme {
  // ── BASE COLORS ────────────────────────────────────────────────────────────
  static const Color primaryBlue = Color.fromRGBO(7, 29, 66, 1);
  static const Color accentBlue = Color(0xFF3D6FFF);
  static const Color success = Color(0xFF28A745);
  static const Color warning = Color(0xFFFFC107);
  static const Color danger = Color(0xFFDC3545);

  // ── LIGHT COLORS ───────────────────────────────────────────────────────────
  static const Color lightBg = Colors.white;
  static const Color lightCard = Color(0xFFF5F6FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Colors.black;
  static const Color lightTextSecondary = Color(0xFF6C757D);
  static const Color lightDivider = Color(0xFFE0E0E0);
  static const Color lightInput = Color(0xFFF8F9FA);

  // ── DARK COLORS ────────────────────────────────────────────────────────────
  static const Color darkBg = Color(0xFF0D0D0D);
  static const Color darkCard = Color(0xFF1A1A2E);
  static const Color darkSurface = Color(0xFF16213E);
  static const Color darkInput = Color(0xFF1E1E2E);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFFADB5BD);
  static const Color darkDivider = Color(0xFF2A2A3E);

  // ── TYPOGRAPHY ─────────────────────────────────────────────────────────────
  static const String fontFamily = 'Roboto'; // Assuming Roboto is used, adjust if different

  static TextTheme _textTheme(Color primaryColor, Color secondaryColor) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        color: primaryColor,
        fontFamily: fontFamily,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: primaryColor,
        fontFamily: fontFamily,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: primaryColor,
        fontFamily: fontFamily,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: primaryColor,
        fontFamily: fontFamily,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: primaryColor,
        fontFamily: fontFamily,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: primaryColor,
        fontFamily: fontFamily,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: primaryColor,
        fontFamily: fontFamily,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        color: primaryColor,
        fontFamily: fontFamily,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: primaryColor,
        fontFamily: fontFamily,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: primaryColor,
        fontFamily: fontFamily,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: secondaryColor,
        fontFamily: fontFamily,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: secondaryColor,
        fontFamily: fontFamily,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: primaryColor,
        fontFamily: fontFamily,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: secondaryColor,
        fontFamily: fontFamily,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: secondaryColor,
        fontFamily: fontFamily,
      ),
    );
  }

  // ── LIGHT THEME ────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,

      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        onPrimary: Colors.white,
        primaryContainer: accentBlue,
        onPrimaryContainer: Colors.white,
        secondary: accentBlue,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFE3F2FD),
        onSecondaryContainer: primaryBlue,
        tertiary: success,
        onTertiary: Colors.white,
        tertiaryContainer: Color(0xFFE8F5E8),
        onTertiaryContainer: success,
        error: danger,
        onError: Colors.white,
        errorContainer: Color(0xFFFCE4E4),
        onErrorContainer: danger,
        background: lightBg,
        onBackground: lightTextPrimary,
        surface: lightSurface,
        onSurface: lightTextPrimary,
        surfaceVariant: lightCard,
        onSurfaceVariant: lightTextSecondary,
        outline: lightDivider,
        outlineVariant: Color(0xFFBDBDBD),
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        inverseSurface: darkBg,
        onInverseSurface: darkTextPrimary,
        inversePrimary: accentBlue,
        surfaceTint: primaryBlue,
      ),

      scaffoldBackgroundColor: lightBg,

      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontFamily: fontFamily,
        ),
      ),

      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: primaryBlue.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: danger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: const TextStyle(
          color: lightTextSecondary,
          fontFamily: fontFamily,
        ),
        hintStyle: const TextStyle(
          color: lightTextSecondary,
          fontFamily: fontFamily,
        ),
      ),

      textTheme: _textTheme(lightTextPrimary, lightTextSecondary),

      dividerColor: lightDivider,

      popupMenuTheme: const PopupMenuThemeData(
        color: lightSurface,
        textStyle: TextStyle(
          color: lightTextPrimary,
          fontFamily: fontFamily,
        ),
      ),

      iconTheme: const IconThemeData(
        color: lightTextPrimary,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
      ),
    );
  }

  // ── DARK THEME ─────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,

      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        onPrimary: Colors.white,
        primaryContainer: accentBlue,
        onPrimaryContainer: Colors.white,
        secondary: accentBlue,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFF1E1E2E),
        onSecondaryContainer: accentBlue,
        tertiary: success,
        onTertiary: Colors.white,
        tertiaryContainer: Color(0xFF1B5E20),
        onTertiaryContainer: success,
        error: danger,
        onError: Colors.white,
        errorContainer: Color(0xFF5D1A1A),
        onErrorContainer: danger,
        background: darkBg,
        onBackground: darkTextPrimary,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        surfaceVariant: darkCard,
        onSurfaceVariant: darkTextSecondary,
        outline: darkDivider,
        outlineVariant: Color(0xFF494949),
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        inverseSurface: lightBg,
        onInverseSurface: lightTextPrimary,
        inversePrimary: accentBlue,
        surfaceTint: primaryBlue,
      ),

      scaffoldBackgroundColor: darkBg,

      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontFamily: fontFamily,
        ),
      ),

      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentBlue,
          side: const BorderSide(color: accentBlue),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentBlue,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accentBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: danger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: const TextStyle(
          color: darkTextSecondary,
          fontFamily: fontFamily,
        ),
        hintStyle: const TextStyle(
          color: darkTextSecondary,
          fontFamily: fontFamily,
        ),
      ),

      textTheme: _textTheme(darkTextPrimary, darkTextSecondary),

      dividerColor: darkDivider,

      popupMenuTheme: const PopupMenuThemeData(
        color: darkSurface,
        textStyle: TextStyle(
          color: darkTextPrimary,
          fontFamily: fontFamily,
        ),
      ),

      iconTheme: const IconThemeData(
        color: darkTextPrimary,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
      ),
    );
  }
}

extension ThemeExtras on BuildContext {
  Color get textMuted => Theme.of(this).colorScheme.onSurface.withOpacity(0.6);
}

