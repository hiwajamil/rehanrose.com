import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';

/// About Us page: "Why we started Rehan Rose" — local florists and fresh flowers.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context).textTheme;

    return AppScaffold(
      child: SectionContainer(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 48, vertical: 56),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.footerAboutUs,
                style: theme.headlineMedium?.copyWith(
                  color: AppColors.inkCharcoal,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.aboutStoryHeading,
                style: theme.titleLarge?.copyWith(
                  color: AppColors.rosePrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.aboutStoryParagraph1,
                style: theme.bodyLarge?.copyWith(
                  color: AppColors.ink,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.aboutStoryParagraph2,
                style: theme.bodyLarge?.copyWith(
                  color: AppColors.ink,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.aboutStoryParagraph3,
                style: theme.bodyLarge?.copyWith(
                  color: AppColors.ink,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
