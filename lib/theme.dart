import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const teal = Color(0xFF0D5C4F);
  static const tealDark = Color(0xFF083F37);
  static const tealLight = Color(0xFFE3F3EE);
  static const vital = Color(0xFF0FB88A);
  static const vitalLight = Color(0xFFE9FBF4);
  static const amber = Color(0xFFB45309);
  static const amberLight = Color(0xFFFFFBEB);
  static const rose = Color(0xFFBE123C);
  static const roseLight = Color(0xFFFFF1F2);
  static const gold = Color(0xFFD4AF6A);
  static const ink = Color(0xFF0D3B33);
  static const muted = Color(0xFF6B8880);
  static const surfaceLight = Color(0xFFF4F7F6);
  static const surfaceDark = Color(0xFF0A0F1E);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.surfaceLight,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.teal,
        secondary: AppColors.vital,
        error: AppColors.rose,
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        headlineMedium: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700, fontSize: 24, color: AppColors.ink),
        titleLarge: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.ink),
        titleMedium: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.ink),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: AppColors.muted),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shadowColor: AppColors.ink.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.teal, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.surfaceDark,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.vital,
        secondary: AppColors.teal,
        error: AppColors.rose,
        surface: const Color(0xFF11182B),
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        headlineMedium: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 24,
            color: Colors.white),
        titleLarge: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white),
        titleMedium: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.white),
        bodyMedium:
            GoogleFonts.inter(fontSize: 14, color: Colors.white70),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF11182B),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}