import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

const String _kRudawFontFamily = 'Rudaw';

String _fontFamilyForLocale(Locale locale) {
  // Keep Rudaw for Kurdish/Arabic. Use Montserrat for English (premium/clean look).
  switch (locale.languageCode) {
    case 'ar':
    case 'ku':
      return _kRudawFontFamily;
    default:
      return GoogleFonts.montserrat().fontFamily ?? 'Montserrat';
  }
}

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

  static TextStyle _textStyle({
    required String fontFamily,
    required double fontSize,
    required FontWeight fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    );
  }

  static ThemeData _buildLightTheme(Locale locale) {
    final fontFamily = _fontFamilyForLocale(locale);
    final baseTextTheme = TextTheme(
      headlineLarge: _textStyle(
        fontFamily: fontFamily,
        fontSize: 56,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        color: AppColors.ink,
      ),
      headlineMedium: _textStyle(
        fontFamily: fontFamily,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: AppColors.ink,
      ),
      titleLarge: _textStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: AppColors.ink,
      ),
      bodyLarge: _textStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: AppColors.inkMuted,
      ),
      bodyMedium: _textStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: AppColors.inkMuted,
      ),
    );
    final textTheme = locale.languageCode == 'en'
        ? GoogleFonts.montserratTextTheme(baseTextTheme)
        : baseTextTheme;

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
      fontFamily: fontFamily,
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
          textStyle: _textStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  static ThemeData _buildLightMobileTheme(Locale locale) {
    final fontFamily = _fontFamilyForLocale(locale);
    final baseTextTheme = TextTheme(
      headlineLarge: _textStyle(
        fontFamily: fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: AppColors.ink,
      ),
      headlineMedium: _textStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: AppColors.ink,
      ),
      headlineSmall: _textStyle(
        fontFamily: fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      titleLarge: _textStyle(
        fontFamily: fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: AppColors.ink,
      ),
      bodyLarge: _textStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: AppColors.inkMuted,
      ),
      bodyMedium: _textStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: AppColors.inkMuted,
      ),
    );
    final textTheme = locale.languageCode == 'en'
        ? GoogleFonts.montserratTextTheme(baseTextTheme)
        : baseTextTheme;

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
      fontFamily: fontFamily,
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
          textStyle: _textStyle(
            fontFamily: fontFamily,
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

