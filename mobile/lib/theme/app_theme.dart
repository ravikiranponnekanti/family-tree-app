import 'package:flutter/material.dart';

/// Classic heritage light theme — warm beige + deep green + gold.
class AppTheme {
  static const Color bg = Color(0xFFF4EFE4); // warm beige
  static const Color surface = Color(0xFFFBF8F1); // cream card
  static const Color surfaceHi = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF2E5D4B); // deep heritage green
  static const Color primaryDim = Color(0xFF20402F);
  static const Color gold = Color(0xFFB08D3E); // antique gold
  static const Color textLight = Color(0xFF2A2620); // dark text (named 'light' for compat)
  static const Color textDark = Color(0xFF2A2620);
  static const Color textMuted = Color(0xFF8A8275);

  static const Color maleAccent = Color(0xFF4A7AA8);
  static const Color femaleAccent = Color(0xFFB55A77);
  static const Color neutralAccent = Color(0xFF7A8C6B);

  static Color genderColor(String? gender) {
    switch (gender) {
      case 'MALE':
        return maleAccent;
      case 'FEMALE':
        return femaleAccent;
      default:
        return neutralAccent;
    }
  }

  static ThemeData theme() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: gold,
        surface: surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHi,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: textMuted),
        labelStyle: const TextStyle(color: textMuted),
        prefixIconColor: textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.brown.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.brown.withValues(alpha: 0.2)),
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
      dialogTheme: const DialogThemeData(backgroundColor: surface),
      popupMenuTheme: const PopupMenuThemeData(color: surface),
    );
  }

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDim],
  );

  static const LinearGradient tealGold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, gold],
  );

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.brown.withValues(alpha: 0.12),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  // Aliases used by various screens
  static const Color card = surface;
  static const Color accent = gold;
  static const Color primaryDark = primaryDim;
  static const Color maleTint = maleAccent;
  static const Color femaleTint = femaleAccent;
  static const Color neutralTint = neutralAccent;
}
