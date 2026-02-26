import 'package:flutter/material.dart';
import '../services/category_service.dart';

/// Deterministic per-category colour — same category always gets the same
/// colour regardless of which screen or list it appears in.
/// Colours set in PocketBase (via CategoryService) take precedence.
class CategoryColors {
  /// Returns the colour for [category].
  static Color forCategory(String category) =>
      CategoryService.instance.colorFor(category);

  static Color bg(String category) => forCategory(category).withAlpha(30);
  static Color border(String category) => forCategory(category).withAlpha(80);
}

class AppTheme {
  static const Color primary = Color(0xFF0d6efd);
  static const Color surface = Color(0xFF1a1d23);
  static const Color surfaceVariant = Color(0xFF22262e);
  static const Color cardColor = Color(0xFF22262e);
  static const Color income = Color(0xFF22c55e);
  static const Color expense = Color(0xFFef4444);
  static const Color savings = Color(0xFF3b82f6);
  static const Color amber = Color(0xFFf59e0b);
  static const Color onSurface = Color(0xFFe2e8f0);
  static const Color onSurfaceMuted = Color(0xFF94a3b8);
  static const Color divider = Color(0xFF2d3748);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: const Color(0xFF6366f1),
        surface: surface,
        surfaceContainerHighest: surfaceVariant,
        onSurface: onSurface,
        onPrimary: Colors.white,
        error: expense,
      ),
      scaffoldBackgroundColor: surface,
      cardColor: cardColor,
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: divider, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF141720),
        selectedItemColor: primary,
        unselectedItemColor: Color(0xFF64748b),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: onSurfaceMuted),
        hintStyle: const TextStyle(color: onSurfaceMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: primary.withAlpha(51),
        labelStyle: const TextStyle(color: onSurface, fontSize: 13),
        side: const BorderSide(color: divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: onSurface, fontSize: 15),
        bodyMedium: TextStyle(color: onSurface, fontSize: 14),
        bodySmall: TextStyle(color: onSurfaceMuted, fontSize: 12),
        labelSmall: TextStyle(color: onSurfaceMuted, fontSize: 11),
      ),
    );
  }
}
