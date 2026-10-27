import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const navy = Color(0xFF0B1F33);
  static const teal = Color(0xFF0E6E64);
  static const tealDark = Color(0xFF0B6158);
  static const tealSoft = Color(0xFFE9F6F4);
  static const orange = Color(0xFF9A3412);
  static const orangeSoft = Color(0xFFFFF1E6);
  static const amber = Color(0xFFF59E0B);
  static const bg = Color(0xFFF5F6F8);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF5B6474);
  static const border = Color(0xFFE7EAF0);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        primary: AppColors.teal,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.bg,
    );

    final textTheme = GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink)
        .copyWith(
          headlineMedium: GoogleFonts.cairo(
              fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.ink),
          titleLarge: GoogleFonts.cairo(
              fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
        );

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.teal, 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          textStyle: GoogleFonts.ibmPlexSansArabic(
              fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
