import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Editorial/Magazine-Inspired Financial Interface Theme
class AppTheme {
  // Color Palette
  static const Color primaryNavy = Color(0xFF0A1828);
  static const Color accentGold = Color(0xFFC9A86A);
  static const Color backgroundCream = Color(0xFFFAF8F5);
  static const Color tertiarySage = Color(0xFF8B9D83);

  // Additional utility colors
  static const Color errorRed = Color(0xFFD32F2F);
  static const Color successGreen = Color(0xFF2E7D32);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textMedium = Color(0xFF4A4A4A);
  static const Color textLight = Color(0xFF757575);
  static const Color borderLight = Color(0xFFE0E0E0);

  // Typography
  static TextTheme get textTheme {
    return TextTheme(
      // Display text for hero sections (48-56px)
      displayLarge: GoogleFonts.playfairDisplay(
        fontSize: 56,
        fontWeight: FontWeight.bold,
        color: textDark,
        height: 0.9,
        letterSpacing: -1.5,
      ),
      displayMedium: GoogleFonts.playfairDisplay(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: textDark,
        height: 1.0,
        letterSpacing: -1.0,
      ),
      displaySmall: GoogleFonts.playfairDisplay(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: textDark,
        height: 1.0,
        letterSpacing: -0.5,
      ),
      // Headlines
      headlineLarge: GoogleFonts.playfairDisplay(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textDark,
        height: 1.1,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textDark,
        height: 1.1,
      ),
      headlineSmall: GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textDark,
        height: 1.2,
      ),
      // Titles
      titleLarge: GoogleFonts.dmSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textDark,
        height: 1.3,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textDark,
        height: 1.4,
      ),
      titleSmall: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textDark,
        height: 1.4,
      ),
      // Body text
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: textMedium,
        height: 1.6,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: textMedium,
        height: 1.6,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: textLight,
        height: 1.5,
      ),
      // Labels
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textDark,
        height: 1.4,
        letterSpacing: 0.5,
      ),
      labelMedium: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textMedium,
        height: 1.4,
        letterSpacing: 0.5,
      ),
      labelSmall: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: textLight,
        height: 1.4,
        letterSpacing: 0.5,
      ),
    );
  }

  // Theme Data
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primaryNavy,
        secondary: accentGold,
        tertiary: tertiarySage,
        surface: backgroundCream,
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: primaryNavy,
        onSurface: textDark,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundCream,
      textTheme: textTheme,

      // Input decoration theme - Sharp geometry, minimal borders
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: borderLight, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: borderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: primaryNavy, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: errorRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
        labelStyle: GoogleFonts.dmSans(
          fontSize: 14,
          color: textMedium,
        ),
        hintStyle: GoogleFonts.dmSans(
          fontSize: 14,
          color: textLight,
        ),
      ),

      // Elevated button theme - Sharp, minimal
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Card theme - Flat with borders
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: borderLight.withValues(alpha: 0.3), width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),

      // AppBar theme - Navy with clean styling
      appBarTheme: AppBarTheme(
        backgroundColor: primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),

      // Drawer theme
      drawerTheme: const DrawerThemeData(
        backgroundColor: backgroundCream,
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: primaryNavy,
        size: 24,
      ),
    );
  }

  // Gold accent bar widget builder
  static Widget goldAccentBar({double width = 80, double height = 3}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: accentGold,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  // Numbered card decoration
  static BoxDecoration numberedCardDecoration(int number) {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: borderLight.withValues(alpha: 0.3), width: 1),
      borderRadius: BorderRadius.circular(2),
    );
  }

  // Split text widget (first word normal, second word gold)
  static Widget splitText(String text, TextStyle baseStyle) {
    final words = text.split(' ');
    if (words.length < 2) {
      return Text(text, style: baseStyle);
    }

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${words[0]} ',
            style: baseStyle,
          ),
          TextSpan(
            text: words.sublist(1).join(' '),
            style: baseStyle.copyWith(color: accentGold),
          ),
        ],
      ),
    );
  }
}
