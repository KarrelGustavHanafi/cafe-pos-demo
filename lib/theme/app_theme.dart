import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Breakpoints {
  static const double mobileMax = 599.9;
  static const double tabletMin = 600.0;
  static const double desktopMin = 1024.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < tabletMin;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= tabletMin && width < desktopMin;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopMin;
}

class AppColors {
  // Primary Fresh Mint / Teal Family
  static const Color primary = Color(0xFF0D9488); // Teal 600
  static const Color primaryDark = Color(0xFF0F766E); // Teal 700
  static const Color primaryLight = Color(0xFF14B8A6); // Teal 500
  static const Color primarySoft = Color(0xFFF0FDFA); // Teal 50
  static const Color primaryBorder = Color(0xFFCCFBF1); // Teal 100

  // Neutrals & Backgrounds (Bright, Fresh, Warm)
  static const Color background = Color(0xFFF8FAF9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF1F5F3);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFEDF2F7);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  static const Color textOnPrimary = Colors.white;

  // Accents for Cafe Special highlights
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentAmberSoft = Color(0xFFFEF3C7);
  static const Color accentCaramel = Color(0xFFD97706);
  static const Color secondary = Color(0xFFD97706);
  static const Color secondarySoft = Color(0xFFFEF3C7);

  // Status & Operational Colors
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color successSoft = Color(0xFFECFDF5);
  static const Color danger = Color(0xFFEF4444); // Red 500
  static const Color dangerSoft = Color(0xFFFEF2F2);
  static const Color error = Color(0xFFEF4444); // Red 500
  static const Color errorSoft = Color(0xFFFEF2F2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFFFBEB);
  static const Color info = Color(0xFF0284C7); // Sky 600
  static const Color infoSoft = Color(0xFFF0F9FF);
}

class AppCurrency {
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  static String format(num amount) {
    return _formatter.format(amount).replaceAll(' ', '');
  }
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.textOnPrimary,
        secondary: AppColors.primaryDark,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Segoe UI',
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          side: const BorderSide(color: AppColors.border, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
        ),
      ),
    );
  }
}
