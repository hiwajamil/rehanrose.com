import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Splash / loading screen with mission statement.
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final isRTL = locale.languageCode == 'ar' || locale.languageCode == 'ku';
    final font = isRTL ? GoogleFonts.notoNaskhArabic : GoogleFonts.cormorantGaramond;

    return Container(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 40),
          child: Text(
            l10n.splashMission,
            textAlign: TextAlign.center,
            textDirection: Directionality.of(context),
            style: font(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
              color: AppColors.ink,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
