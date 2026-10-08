// lib/theme/app_tokens.dart
// Single source of truth for every visual decision in the app.

import 'package:flutter/material.dart';

// Colour tokens

class AppColors {
  AppColors._();

  // Primary - indigo/blue from the Akademi reference
  static const primary = Color(0xFF4F5FEE);
  static const primaryLight = Color(0xFF7C8FF4);
  static const primaryDark = Color(0xFF3346D3);
  static const primarySurface = Color(
    0xFFEEF0FD,
  ); // lavender tint for backgrounds

  // Secondary - warm amber used in stat cards (food, events)
  static const secondary = Color(0xFFF9A825);
  static const secondarySurface = Color(0xFFFFF8E1);

  // Accent - coral/red used in the performance chart
  static const accent = Color(0xFFEF5350);
  static const accentSurface = Color(0xFFFFEBEE);

  // Success / Warning / Danger status dots
  static const success = Color(0xFF4CAF50);
  static const successSurface = Color(0xFFE8F5E9);
  static const warning = Color(0xFFFFA726);
  static const warningSurface = Color(0xFFFFF3E0);
  static const danger = Color(0xFFEF5350);
  static const dangerSurface = Color(0xFFFFEBEE);

  // Neutrals
  static const background = Color(0xFFF0F2FF); // off-white with lavender cast
  static const surface = Colors.white;
  static const surfaceVariant = Color(0xFFF5F6FF);
  static const border = Color(0xFFE8EAF6);
  static const divider = Color(0xFFF0F0F7);

  // Text
  static const textPrimary = Color(0xFF1A1D3F);
  static const textSecondary = Color(0xFF6B7280);
  static const textDisabled = Color(0xFFB0B3C6);
  static const textOnPrimary = Colors.white;

  // Sidebar
  static const sidebarBg = Color(0xFF4F5FEE);
  static const sidebarActive = Colors.white;
  static const sidebarInactive = Color(0xAAFFFFFF);

  // Role palette - matches existing AppColors.forRole usage
  static Color forRole(String role) {
    switch (role.trim().toUpperCase()) {
      case 'SUPER_USER':
        return const Color(0xFF7C3AED);
      case 'ADMINISTRATOR':
        return primary;
      case 'TEACHER':
        return const Color(0xFF0891B2);
      case 'HEAD_TEACHER':
        return const Color(0xFF059669);
      case 'ACCOUNTANT':
        return secondary;
      case 'GUARDIAN':
        return const Color(0xFFEC4899);
      default:
        return textSecondary;
    }
  }

  // Stat card icon-circle colours (matching the 4 dashboard stats in ref)
  static const statBlue = Color(0xFF4F5FEE);
  static const statOrange = Color(0xFFF9A825);
  static const statGreen = Color(0xFF4CAF50);
  static const statRed = Color(0xFFEF5350);
}

// Spacing scale

class Sp {
  Sp._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

// Radius scale

class Radii {
  Radii._();
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double full = 999;

  static BorderRadius get xsBr => BorderRadius.circular(xs);
  static BorderRadius get smBr => BorderRadius.circular(sm);
  static BorderRadius get mdBr => BorderRadius.circular(md);
  static BorderRadius get lgBr => BorderRadius.circular(lg);
  static BorderRadius get xlBr => BorderRadius.circular(xl);
  static BorderRadius get fullBr => BorderRadius.circular(full);
}

// Shadow presets

class AppShadows {
  AppShadows._();

  /// Soft elevation - used for cards, panels
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0D4F5FEE), // 5% primary tint
      blurRadius: 24,
      spreadRadius: 0,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x0A000000), // 4% black
      blurRadius: 12,
      spreadRadius: 0,
      offset: Offset(0, 2),
    ),
  ];

  /// Stronger lift - modals, dropdowns
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x1A4F5FEE),
      blurRadius: 32,
      spreadRadius: 0,
      offset: Offset(0, 8),
    ),
  ];

  /// Sidebar glow
  static const List<BoxShadow> sidebar = [
    BoxShadow(
      color: Color(0x334F5FEE),
      blurRadius: 40,
      spreadRadius: 0,
      offset: Offset(4, 0),
    ),
  ];
}

// Gradient presets

class AppGradients {
  AppGradients._();

  /// Hero card background - indigo to lighter indigo
  static const LinearGradient primaryHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4F5FEE), Color(0xFF7C8FF4)],
  );

  /// Performance chart fill - coral gradient
  static const LinearGradient chartCoral = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x33EF5350), Color(0x00EF5350)],
  );

  /// Finance chart fill - amber gradient
  static const LinearGradient chartAmber = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x33F9A825), Color(0x00F9A825)],
  );

  /// Performance chart fill - primary gradient
  static const LinearGradient chartPrimary = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x334F5FEE), Color(0x004F5FEE)],
  );

  /// Sidebar - solid indigo
  static const LinearGradient sidebar = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF4F5FEE), Color(0xFF3346D3)],
  );
}

// Typography scale
// Matching the reference: bold headings, clean sans-serif body.
// Using Nunito (rounded, friendly) for headings + Inter for body.

class AppText {
  AppText._();

  static const String fontHeading = 'Nunito';
  static const String fontBody = 'Nunito';

  static TextTheme buildTextTheme(TextTheme base) {
    return base.copyWith(
      // Display
      displayLarge: base.displayLarge?.copyWith(
        fontFamily: fontHeading,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -1,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontFamily: fontHeading,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontFamily: fontHeading,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
      // Headline
      headlineLarge: base.headlineLarge?.copyWith(
        fontFamily: fontHeading,
        fontWeight: FontWeight.w800,
        fontSize: 28,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: fontHeading,
        fontWeight: FontWeight.w700,
        fontSize: 22,
        color: AppColors.textPrimary,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontFamily: fontHeading,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: AppColors.textPrimary,
      ),
      // Title
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: fontHeading,
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: AppColors.textPrimary,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontFamily: fontBody,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontFamily: fontBody,
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: AppColors.textPrimary,
      ),
      // Body
      bodyLarge: base.bodyLarge?.copyWith(
        fontFamily: fontBody,
        fontWeight: FontWeight.w400,
        fontSize: 15,
        color: AppColors.textPrimary,
        height: 1.6,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontFamily: fontBody,
        fontWeight: FontWeight.w400,
        fontSize: 14,
        color: AppColors.textPrimary,
        height: 1.5,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontFamily: fontBody,
        fontWeight: FontWeight.w400,
        fontSize: 12,
        color: AppColors.textSecondary,
        height: 1.4,
      ),
      // Label
      labelLarge: base.labelLarge?.copyWith(
        fontFamily: fontBody,
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: AppColors.textPrimary,
        letterSpacing: 0.1,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontFamily: fontBody,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: AppColors.textSecondary,
        letterSpacing: 0.2,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontFamily: fontBody,
        fontWeight: FontWeight.w600,
        fontSize: 10,
        color: AppColors.textSecondary,
        letterSpacing: 0.4,
      ),
    );
  }
}

// Breakpoints

class Breakpoints {
  Breakpoints._();
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;

  static bool isMobile(BuildContext ctx) =>
      MediaQuery.sizeOf(ctx).width < mobile;
  static bool isTablet(BuildContext ctx) =>
      MediaQuery.sizeOf(ctx).width >= mobile;
  static bool isDesktop(BuildContext ctx) =>
      MediaQuery.sizeOf(ctx).width >= tablet;
}

// Custom shape: NotchedCornerBorder
// Angled/cut top-left corner matching the hero card style in the references.

class NotchedCornerBorder extends ShapeBorder {
  final double radius;
  final double notchSize;

  const NotchedCornerBorder({this.radius = 20, this.notchSize = 24});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final r = radius;
    final n = notchSize;
    return Path()
      // Start after top-left notch
      ..moveTo(rect.left + n, rect.top)
      // Top edge -> top-right rounded corner
      ..lineTo(rect.right - r, rect.top)
      ..quadraticBezierTo(rect.right, rect.top, rect.right, rect.top + r)
      // Right edge -> bottom-right rounded corner
      ..lineTo(rect.right, rect.bottom - r)
      ..quadraticBezierTo(rect.right, rect.bottom, rect.right - r, rect.bottom)
      // Bottom edge -> bottom-left rounded corner
      ..lineTo(rect.left + r, rect.bottom)
      ..quadraticBezierTo(rect.left, rect.bottom, rect.left, rect.bottom - r)
      // Left edge -> angled notch cut
      ..lineTo(rect.left, rect.top + n)
      ..lineTo(rect.left + n, rect.top)
      ..close();
  }

  @override
  ShapeBorder scale(double t) =>
      NotchedCornerBorder(radius: radius * t, notchSize: notchSize * t);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}
}
