import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';

/// Legal page: Privacy Policy and Terms of Service in one scrollable view.
class LegalPage extends StatelessWidget {
  const LegalPage({super.key});

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
                l10n.footerPrivacyTerms,
                style: theme.headlineMedium?.copyWith(
                  color: AppColors.inkCharcoal,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 32),
              _SectionHeading(
                title: l10n.legalPrivacyPolicyTitle,
                style: theme.titleLarge,
              ),
              const SizedBox(height: 12),
              _LegalParagraph(l10n.legalPrivacyIntro),
              _LegalParagraph(l10n.legalPrivacyData),
              _LegalParagraph(l10n.legalPrivacyUse),
              _LegalParagraph(l10n.legalPrivacySharing),
              _LegalParagraph(l10n.legalPrivacyContact),
              const SizedBox(height: 32),
              _SectionHeading(
                title: l10n.legalTermsOfServiceTitle,
                style: theme.titleLarge,
              ),
              const SizedBox(height: 12),
              _LegalParagraph(l10n.legalTermsIntro),
              _LegalParagraph(l10n.legalTermsUse),
              _LegalParagraph(l10n.legalTermsOrders),
              _LegalParagraph(l10n.legalTermsContact),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final TextStyle? style;

  const _SectionHeading({required this.title, this.style});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: (style ?? Theme.of(context).textTheme.titleLarge)?.copyWith(
        color: AppColors.inkCharcoal,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _LegalParagraph extends StatelessWidget {
  final String text;

  const _LegalParagraph(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.ink,
              height: 1.5,
            ),
      ),
    );
  }
}

