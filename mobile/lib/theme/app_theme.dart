import 'package:flutter/material.dart';

/// Central design system for the app. Warm, modern, rounded.
class AppTheme {
  // Core palette
  static const Color primary = Color(0xFF1B6B5C); // deep teal-green
  static const Color primaryDark = Color(0xFF0F4A3E);
  static const Color accent = Color(0xFFE8A87C); // warm sand/peach
  static const Color bg = Color(0xFFF7F4EF); // warm off-white
  static const Color card = Colors.white;
  static const Color textDark = Color(0xFF2B2B2B);
  static const Color textMuted = Color(0xFF7A7A7A);

  // Soft gender tints for cards/nodes
  static const Color maleTint = Color(0xFFDCE9F5);
  static const Color femaleTint = Color(0xFFF8E0E6);
  static const Color neutralTint = Color(0xFFEDEAE3);

  static Color genderColor(String? gender) {
    switch (gender) {
      case 'MALE':
        return maleTint;
      case 'FEMALE':
        return femaleTint;
      default:
        return neutralTint;
    }
  }

  static ThemeData theme() {
    final base = ThemeData(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accent,
        surface: card,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  // Reusable gradient for headers/hero areas
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );
}
