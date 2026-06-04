import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Dark theme is the default premium aesthetic
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6C63FF), // Indigo Accent
        brightness: Brightness.dark,
        primary: const Color(0xFF8F88FF),
        secondary: const Color(0xFF00E6FF), // Cyan Neon
        tertiary: const Color(0xFFFF5252), // Coral Red
        surface: const Color(0xFF0E0E1B), // Midnight Blue-Black
        error: const Color(0xFFFF5E5E),
      ),
      scaffoldBackgroundColor: const Color(0xFF07070F), // Very dark midnight
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 32),
        titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 20),
        bodyLarge: GoogleFonts.outfit(fontSize: 16, height: 1.5),
        bodyMedium: GoogleFonts.outfit(fontSize: 14, height: 1.4, color: Colors.white70),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF131326), // Elevated dark cards
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF22223F), width: 1.0), // Border for glassmorphic borders
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  // Neon Gradient Presets
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF8F88FF), Color(0xFF00E6FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFF5252), Color(0xFFFF7E40)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF16162F), Color(0xFF0F0F20)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF07070F), Color(0xFF0F0F25), Color(0xFF05050C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Custom Glassmorphic Card Decoration
  static BoxDecoration glassCardDecoration({
    BorderRadius? borderRadius,
    Color? borderClr,
  }) {
    return BoxDecoration(
      color: const Color(0xFF131326).withAlpha(160),
      borderRadius: borderRadius ?? BorderRadius.circular(24),
      border: Border.all(
        color: borderClr ?? const Color(0xFF22223F).withAlpha(120),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF000000).withAlpha(100),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
