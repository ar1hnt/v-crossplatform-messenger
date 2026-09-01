import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const background = Color(0xFF070B14);
  static const backgroundSoft = Color(0xFF0D1324);
  static const panel = Color(0xFF10182D);
  static const panelStrong = Color(0xFF162341);
  static const grid = Color(0xFF1E2A49);
  static const neonCyan = Color(0xFF18F0FF);
  static const neonPink = Color(0xFFFF3CAC);
  static const neonLime = Color(0xFFA6FF00);
  static const textPrimary = Color(0xFFE8F6FF);
  static const textSecondary = Color(0xFF8AA6C8);
  static const danger = Color(0xFFFF5A72);

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.spaceGroteskTextTheme().apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: neonCyan,
        secondary: neonPink,
        surface: panel,
        onPrimary: background,
        onSecondary: textPrimary,
        onSurface: textPrimary,
        error: danger,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.orbitron(
          color: textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
        displayMedium: GoogleFonts.orbitron(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
        headlineMedium: GoogleFonts.orbitron(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
        titleLarge: GoogleFonts.spaceGrotesk(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: GoogleFonts.spaceGrotesk(
          color: textPrimary,
          fontSize: 16,
          height: 1.45,
        ),
        bodyMedium: GoogleFonts.spaceGrotesk(
          color: textSecondary,
          fontSize: 14,
          height: 1.4,
        ),
        labelLarge: GoogleFonts.orbitron(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textPrimary,
        centerTitle: false,
        titleTextStyle: GoogleFonts.orbitron(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel.withValues(alpha: 0.88),
        hintStyle: const TextStyle(color: textSecondary),
        labelStyle: const TextStyle(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: grid),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: grid),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: neonCyan, width: 1.6),
        ),
      ),
      cardTheme: CardThemeData(
        color: panel.withValues(alpha: 0.9),
        margin: EdgeInsets.zero,
        shadowColor: neonCyan.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: neonCyan.withValues(alpha: 0.18)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: panel.withValues(alpha: 0.95),
        indicatorColor: neonCyan.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? neonCyan
              : textSecondary;
          return IconThemeData(color: color);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return GoogleFonts.spaceGrotesk(
            color: states.contains(WidgetState.selected)
                ? neonCyan
                : textSecondary,
            fontWeight: FontWeight.w600,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: neonCyan,
          foregroundColor: background,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: neonPink.withValues(alpha: 0.45)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      dividerColor: grid,
    );
  }
}
