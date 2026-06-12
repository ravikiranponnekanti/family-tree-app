import 'package:flutter/material.dart';

/// Premium dark design system.
class AppTheme {
  // Core dark palette
  static const Color bg = Color(0xFF0E1417); // near-black charcoal
  static const Color surface = Color(0xFF182026); // card surface
  static const Color surfaceHi = Color(0xFF202A31); // elevated surface
  static const Color primary = Color(0xFF2DD4BF); // bright teal
  static const Color primaryDim = Color(0xFF14756B);
  static const Color gold = Color(0xFFE8B765); // warm gold accent
  static const Color textLight = Color(0xFFF1F5F4);
  static const Color textMuted = Color(0xFF8A9AA0);

  // Gender accent tints (used for rings/borders)
  static const Color maleAccent = Color(0xFF5AA9E6);
  static const Color femaleAccent = Color(0xFFE6789B);
  static const Color neutralAccent = Color(0xFF9C8FE0);

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
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        primary: primary,
        secondary: gold,
        surface: surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: textLight),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: const Color(0xFF06201D),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Color(0xFF06201D),
      ),
      dialogTheme: const DialogThemeData(backgroundColor: surfaceHi),
      popupMenuTheme: const PopupMenuThemeData(color: surfaceHi),
    );
  }

  // Premium gradients
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF14756B), Color(0xFF0E1417)],
  );

  static const LinearGradient tealGold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, gold],
  );

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  // Backward-compatible aliases (older screens reference these names)
  static const Color card = surface;
  static const Color textDark = textLight;
  static const Color accent = gold;
  static const Color primaryDark = primaryDim;
  static const Color maleTint = maleAccent;
  static const Color femaleTint = femaleAccent;
  static const Color neutralTint = neutralAccent;
}
