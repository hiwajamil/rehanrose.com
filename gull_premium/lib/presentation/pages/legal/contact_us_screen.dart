import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';

/// Basic placeholder "Contact Us" screen for Rehan Rose support.
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  // Rehan Rose support details.
  static const String _kSupportEmail = 'info@rehanrose.com';
  static const String _kSupportPhoneDisplay = '+964 770 981 8181';
  // E.164 without '+' for tel:/wa.me.
  static const String _kSupportPhoneE164 = '9647709818181';

  @override
  Widget build(BuildContext context) {
    const appBarTitle = 'Contact Us';

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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'We would love to help',
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.inkCharcoal,
                      letterSpacing: -0.4,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Reach out to our support team. For the fastest response, use email or call us.',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 22),
                  // i18n: Replace hardcoded copy with localized strings.
                  _InfoCard(
                    title: 'Email',
                    value: _kSupportEmail,
                    icon: Icons.email_outlined,
                    onTap: () => _launchMailto(_kSupportEmail),
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    title: 'Phone',
                    value: _kSupportPhoneDisplay,
                    icon: Icons.phone_outlined,
                    onTap: () => _launchTel(_kSupportPhoneE164),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchMailto(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  }

  Future<void> _launchTel(String phoneE164) async {
    final uri = Uri.parse('tel:$phoneE164');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.forestGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 22, color: AppColors.forestGreen),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.inkMuted,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.inkMuted.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

