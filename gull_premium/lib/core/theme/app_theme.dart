import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData? _cachedLightEn;
  static ThemeData? _cachedLightAr;
  static ThemeData? _cachedLightKu;
  static ThemeData? _cachedLightMobileEn;
  static ThemeData? _cachedLightMobileAr;
  static ThemeData? _cachedLightMobileKu;

  static ThemeData light(Locale locale) {
    switch (locale.languageCode) {
      case 'ar':
        _cachedLightAr ??= _buildLightTheme(locale);
        return _cachedLightAr!;
      case 'ku':
        _cachedLightKu ??= _buildLightTheme(locale);
        return _cachedLightKu!;
      default:
        _cachedLightEn ??= _buildLightTheme(locale);
        return _cachedLightEn!;
    }
  }

  static ThemeData lightMobile(Locale locale) {
    switch (locale.languageCode) {
      case 'ar':
        _cachedLightMobileAr ??= _buildLightMobileTheme(locale);
        return _cachedLightMobileAr!;
      case 'ku':
        _cachedLightMobileKu ??= _buildLightMobileTheme(locale);
        return _cachedLightMobileKu!;
      default:
        _cachedLightMobileEn ??= _buildLightMobileTheme(locale);
        return _cachedLightMobileEn!;
    }
  }

  static ThemeData _buildLightTheme(Locale locale) {
    final isRTL = locale.languageCode == 'ar' || locale.languageCode == 'ku';
    final headlineFont = isRTL ? GoogleFonts.notoNaskhArabic : GoogleFonts.inter;
    final baseTextTheme = isRTL
        ? GoogleFonts.notoNaskhArabicTextTheme(const TextTheme())
        : GoogleFonts.interTextTheme(const TextTheme());
    final textTheme = baseTextTheme.copyWith(
      headlineLarge: headlineFont(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        color: AppColors.ink,
      ),
      headlineMedium: headlineFont(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: AppColors.ink,
      ),
      titleLarge: headlineFont(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: AppColors.ink,
      ),
      bodyLarge: headlineFont(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: AppColors.inkMuted,
      ),
      bodyMedium: headlineFont(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: AppColors.inkMuted,
      ),
    );

    final colorScheme = ColorScheme.light(
      primary: AppColors.rose,
      secondary: AppColors.sage,
      surface: AppColors.surface,
      onPrimary: Colors.white,
      onSecondary: AppColors.ink,
      onSurface: AppColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      dividerColor: AppColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
          ),
          textStyle: headlineFont(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  static ThemeData _buildLightMobileTheme(Locale locale) {
    final isRTL = locale.languageCode == 'ar' || locale.languageCode == 'ku';
    final mobileFont = isRTL ? GoogleFonts.notoNaskhArabic : GoogleFonts.inter;
    final baseTextTheme = isRTL
        ? GoogleFonts.notoNaskhArabicTextTheme(const TextTheme())
        : GoogleFonts.interTextTheme(const TextTheme());
    final textTheme = baseTextTheme.copyWith(
      headlineLarge: mobileFont(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: AppColors.ink,
      ),
      headlineMedium: mobileFont(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: AppColors.ink,
      ),
      headlineSmall: mobileFont(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      titleLarge: mobileFont(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: AppColors.ink,
      ),
      bodyLarge: mobileFont(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: AppColors.inkMuted,
      ),
      bodyMedium: mobileFont(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: AppColors.inkMuted,
      ),
    );

    final colorScheme = ColorScheme.light(
      primary: AppColors.rose,
      secondary: AppColors.sage,
      surface: AppColors.surface,
      onPrimary: Colors.white,
      onSecondary: AppColors.ink,
      onSurface: AppColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      dividerColor: AppColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: mobileFont(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

