import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

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

/// CAFFE POS Design System Colors
/// Fresh mint/teal brand with warm cream background, deep neutral text, and clear semantic status.
class AppColors {
  // Primary Fresh Mint / Teal Family
  static const Color primary = Color(0xFF0D9488); // Teal 600 (Fresh Mint / Teal)
  static const Color primaryDark = Color(0xFF0F766E); // Teal 700
  static const Color primaryLight = Color(0xFF14B8A6); // Teal 500
  static const Color primarySoft = Color(0xFFF0FDFA); // Teal 50
  static const Color primaryBorder = Color(0xFFCCFBF1); // Teal 100

  // Neutrals & Backgrounds (Bright, Fresh, Warm)
  static const Color background = Color(0xFFFAFAF7); // Warm white / very light cream
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF4F6F4); // Soft warm neutral
  static const Color border = Color(0xFFE2E8F0); // Crisp subtle border
  static const Color borderLight = Color(0xFFEEF2F6);

  // Text Hierarchy (Deep neutral & readable gray)
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900 (Deep Neutral)
  static const Color textSecondary = Color(0xFF475569); // Slate 600 (Readable medium-neutral gray)
  static const Color textMuted = Color(0xFF64748B); // Slate 500 (Accessible secondary gray)
  static const Color textOnPrimary = Colors.white;

  // Accents for Cafe Special highlights (Soft warm yellow / amber)
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentAmberSoft = Color(0xFFFEF3C7);
  static const Color accentCaramel = Color(0xFFD97706);
  static const Color secondary = Color(0xFFD97706);
  static const Color secondarySoft = Color(0xFFFEF3C7);

  // Status & Operational Colors (Fresh green, amber, soft coral)
  static const Color success = Color(0xFF10B981); // Emerald 500 (Fresh Green)
  static const Color successSoft = Color(0xFFECFDF5);
  static const Color danger = Color(0xFFF43F5E); // Rose 500 (Soft Coral / Red)
  static const Color dangerSoft = Color(0xFFFFF1F2);
  static const Color error = Color(0xFFF43F5E); // Rose 500
  static const Color errorSoft = Color(0xFFFFF1F2);
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color warningSoft = Color(0xFFFFFBEB);
  static const Color info = Color(0xFF0284C7); // Sky 600
  static const Color infoSoft = Color(0xFFF0F9FF);
}

/// Centralized Spacing Tokens (Hierarchy-driven)
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

/// Intentional Border Radius Scale (Anti-AI-Slop: Reduced Over-Rounding)
class AppRadius {
  static const double sm = 8.0; // Small controls: 8px
  static const double md = 10.0; // Buttons / inputs: 8-10px
  static const double card = 12.0; // Cards: 12px
  static const double lg = 14.0; // Large containers: 14px
  static const double dialog = 16.0; // Dialogs: 14-16px
  static const double xl = 16.0;
  static const double full = 999.0; // Status pills only when appropriate

  static BorderRadius get roundedSm => BorderRadius.circular(sm);
  static BorderRadius get roundedMd => BorderRadius.circular(md);
  static BorderRadius get roundedCard => BorderRadius.circular(card);
  static BorderRadius get roundedLg => BorderRadius.circular(lg);
  static BorderRadius get roundedDialog => BorderRadius.circular(dialog);
  static BorderRadius get roundedXl => BorderRadius.circular(xl);
  static BorderRadius get roundedFull => BorderRadius.circular(full);
}

/// Centralized Elevation / Shadow Tokens
class AppShadows {
  /// Subtle card resting state
  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  /// Interactive card hover / focus
  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Elevated panels, dialogs
  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// Floating elements (FABs, floating cart bar)
  static const List<BoxShadow> xl = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// Sidebar subtle inner glow
  static const List<BoxShadow> sidebar = [
    BoxShadow(
      color: Color(0x06000000),
      blurRadius: 12,
      offset: Offset(2, 0),
    ),
  ];
}

/// Centralized Animation Tokens
class AppAnimations {
  // Durations
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration smooth = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration entrance = Duration(milliseconds: 500);

  // Curves
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve emphasis = Curves.easeOutBack;
  static const Curve spring = Curves.elasticOut;
  static const Curve decelerate = Curves.decelerate;
}

/// Centralized Gradient Presets
class AppGradients {
  /// Login / brand background — soft teal-to-cream
  static const LinearGradient brandBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF0FDFA), // Teal 50
      Color(0xFFFAFAF7), // Warm white
      Color(0xFFFEF3C7), // Amber 100 — warm cafe hint
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Sidebar subtle tint
  static const LinearGradient sidebarTint = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFCFDFC),
      Color(0xFFF8FAF8),
    ],
  );

  /// Primary button gradient for emphasis CTAs
  static const LinearGradient primaryButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF14B8A6), // Teal 500
      Color(0xFF0D9488), // Teal 600
    ],
  );

  /// Success confirmation gradient
  static const LinearGradient success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFECFDF5),
      Color(0xFFF0FDF9),
    ],
  );
}

/// Centralized Typography Hierarchy with Nunito Sans
class AppTypography {
  static const String fontFamily = 'Nunito Sans';

  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.4,
    height: 1.25,
  );

  static const TextStyle pageTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.25,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.45,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.45,
  );

  static const TextStyle bodyBold = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.45,
  );

  static const TextStyle supporting = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.45,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const TextStyle currency = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static const TextStyle currencyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.2,
  );

  static const TextStyle status = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.2,
  );

  static const TextStyle navigation = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );
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
  /// Shadcn Flutter Theme configuration tailored for CAFFE POS
  static shad.ThemeData get shadcnTheme {
    return const shad.ThemeData(
      colorScheme: shad.ColorScheme(
        brightness: Brightness.light,
        background: AppColors.background,
        foreground: AppColors.textPrimary,
        card: AppColors.surface,
        cardForeground: AppColors.textPrimary,
        popover: AppColors.surface,
        popoverForeground: AppColors.textPrimary,
        primary: AppColors.primary,
        primaryForeground: Colors.white,
        secondary: AppColors.surfaceSubtle,
        secondaryForeground: AppColors.textPrimary,
        muted: AppColors.surfaceSubtle,
        mutedForeground: AppColors.textSecondary,
        accent: AppColors.accentAmberSoft,
        accentForeground: AppColors.textPrimary,
        destructive: AppColors.danger,
        destructiveForeground: Colors.white,
        border: AppColors.border,
        input: AppColors.border,
        ring: AppColors.primary,
        chart1: AppColors.primary,
        chart2: AppColors.accentAmber,
        chart3: AppColors.info,
        chart4: AppColors.success,
        chart5: AppColors.secondary,
      ),
      radius: 0.5,
    );
  }

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
      fontFamily: 'Nunito Sans',
      fontFamilyFallback: const ['Nunito Sans', 'Segoe UI', 'Roboto', 'sans-serif'],
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Nunito Sans',
          color: AppColors.textPrimary,
          fontSize: 18,
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
            fontFamily: 'Nunito Sans',
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
            fontFamily: 'Nunito Sans',
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
          fontFamily: 'Nunito Sans',
          color: AppColors.textMuted,
          fontSize: 13,
        ),
      ),
    );
  }
}
