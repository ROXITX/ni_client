import 'package:flutter/material.dart';

/// Central design tokens: colors, spacing, radii, typography.
/// Keep purely declarative. No business logic here.
class AppColors {
  AppColors._();
  static const primary = Color(0xFFF59E0B); // Amber 500
  static const primarySoft = Color(0xFFFEF3C7); // Amber 100
  static const primaryStrong = Color(0xFF92400E); // Amber 800
  static const accentBlue = Color(0xFF3B82F6);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const neutral900 = Color(0xFF111827);
  static const neutral700 = Color(0xFF374151);
  static const neutral600 = Color(0xFF4B5563);
  static const neutral500 = Color(0xFF6B7280);
  static const neutral400 = Color(0xFF9CA3AF);
  static const neutral300 = Color(0xFFD1D5DB);
  static const neutral200 = Color(0xFFE5E7EB);
  static const neutral100 = Color(0xFFF3F4F6);
  static const neutral50 = Color(0xFFF9FAFB);
}

class AppSpacing {
  AppSpacing._();
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 40.0;
}

class AppRadii {
  AppRadii._();
  static const sm = 6.0;
  static const md = 10.0;
  static const lg = 16.0;
  static const pill = 999.0;
}

class AppShadows {
  AppShadows._();
  static List<BoxShadow> card = [
    BoxShadow(
      blurRadius: 8,
      offset: const Offset(0, 2),
      color: Colors.black.withOpacity(0.05),
    ),
  ];
}

class AppText {
  AppText._();
  static const heading1 = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.neutral900);
  static const heading2 = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.neutral900);
  static const heading3 = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.neutral900);
  static const bodyStrong = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral700);
  static const body = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.neutral600);
  static const bodyMuted = TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.neutral500);
  static const micro = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.2, color: AppColors.neutral500);
}

extension ContextText on BuildContext {
  TextTheme get _base => Theme.of(this).textTheme;
  TextStyle get h1 => AppText.heading1;
  TextStyle get h2 => AppText.heading2;
  TextStyle get h3 => AppText.heading3;
  TextStyle get bodyStrong => AppText.bodyStrong;
  TextStyle get body => AppText.body;
  TextStyle get bodyMuted => AppText.bodyMuted;
  TextStyle get micro => AppText.micro;
}
