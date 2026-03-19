import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Premium "About Us" screen for the Rehan Rose brand.
///
class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  static const String _kAppVersion = 'Version 0.1.0';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final appBarTitle = l10n.footerAboutUs;
    final bodyText = l10n.about_rehan_rose_body;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        _LogoMark(),
                        const SizedBox(height: 18),
                        Text(
                          l10n.about_rehan_rose_title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.inkCharcoal,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: 50,
                          child: Divider(
                            color: Colors.grey.shade400,
                            thickness: 1,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          bodyText,
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            height: 1.6,
                            fontWeight: FontWeight.w500,
                            color: AppColors.inkMuted,
                          ),
                          textAlign: TextAlign.start,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
              child: Text(
                _kAppVersion,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: AppColors.inkMuted.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 98,
      height: 98,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentGold.withValues(alpha: 0.25),
            AppColors.rosePrimary.withValues(alpha: 0.14),
            Colors.white,
          ],
        ),
        border: Border.all(
          color: AppColors.accentGold.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.local_florist_outlined,
            size: 52,
            color: AppColors.accentGold,
          ),
          Positioned(
            right: 14,
            bottom: 14,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.rosePrimary.withValues(alpha: 0.18),
                border: Border.all(
                  color: AppColors.rosePrimary.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.local_florist,
                size: 16,
                color: AppColors.rosePrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

