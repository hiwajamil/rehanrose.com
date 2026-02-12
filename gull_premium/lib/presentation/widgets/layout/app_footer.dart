import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../common/track_order_modal.dart';

/// Contact / business constants for footer (could be moved to config later).
const String _kContactEmail = 'info@rehanrose.com';
const String _kContactPhoneDisplay = '+964 770 981 8181';
/// E.164 without '+' for tel: and wa.me.
const String _kContactPhoneE164 = '9647709818181';
const String _kWhatsAppNumber = '9647709818181';

/// Professional responsive footer: 4-column grid on desktop, vertical stack on mobile.
/// Dark background, white text, brand, help, company, contact, and payment badges.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDesktop = MediaQuery.sizeOf(context).width > kMobileBreakpoint;
    const maxWidth = 1280.0;
    const horizontalPadding = 32.0;
    const verticalPadding = 56.0;
    const columnSpacing = 40.0;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.footerBackground,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: horizontalPadding,
              end: horizontalPadding,
              top: verticalPadding,
              bottom: 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _BrandColumn(tagline: l10n.footerTagline),
                      ),
                      const SizedBox(width: columnSpacing),
                      Expanded(
                        child: _HelpColumn(l10n: l10n),
                      ),
                      const SizedBox(width: columnSpacing),
                      Expanded(
                        child: _CompanyColumn(l10n: l10n),
                      ),
                      const SizedBox(width: columnSpacing),
                      Expanded(
                        child: _ContactColumn(
                          l10n: l10n,
                          address: l10n.footerAddress,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BrandColumn(tagline: l10n.footerTagline),
                      const SizedBox(height: 32),
                      _HelpColumn(l10n: l10n),
                      const SizedBox(height: 32),
                      _CompanyColumn(l10n: l10n),
                      const SizedBox(height: 32),
                      _ContactColumn(
                        l10n: l10n,
                        address: l10n.footerAddress,
                      ),
                    ],
                  ),
                const SizedBox(height: 40),
                const Divider(height: 1, color: AppColors.footerDivider),
                const SizedBox(height: 24),
                _BottomBar(l10n: l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Brand colors for social icons on hover.
const Color _kInstagramColor = Color(0xFFE4405F);
const Color _kFacebookColor = Color(0xFF1877F2);
const Color _kTikTokColor = Color(0xFF25F4EE);
const Color _kWhatsAppColor = Color(0xFF25D366);

class _BrandColumn extends StatelessWidget {
  final String tagline;

  const _BrandColumn({required this.tagline});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => context.go('/'),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: _LogoDisplay(appTitle: l10n.appTitle),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          tagline,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.footerTextMuted,
                height: 1.5,
                fontSize: 15,
              ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            _SocialIconButton(
              icon: FontAwesomeIcons.instagram,
              url: 'https://instagram.com/rehanrose',
              hoverColor: _kInstagramColor,
            ),
            const SizedBox(width: 4),
            _SocialIconButton(
              icon: FontAwesomeIcons.facebookF,
              url: 'https://facebook.com/rehanrose',
              hoverColor: _kFacebookColor,
            ),
            const SizedBox(width: 4),
            _SocialIconButton(
              icon: FontAwesomeIcons.tiktok,
              url: 'https://tiktok.com/@rehanrose',
              hoverColor: _kTikTokColor,
            ),
            const SizedBox(width: 4),
            _SocialIconButton(
              icon: FontAwesomeIcons.whatsapp,
              url: 'https://wa.me/$_kWhatsAppNumber',
              hoverColor: _kWhatsAppColor,
            ),
          ],
        ),
      ],
    );
  }
}

/// Logo: Rehan Rose — visible on dark footer. Styled text by default.
/// To use an image instead, add `rehan_rose_logo_light.png` under assets/images/,
/// add `- assets/images/rehan_rose_logo_light.png` to pubspec assets, and switch to Image.asset with errorBuilder → _LogoText.
class _LogoDisplay extends StatelessWidget {
  final String appTitle;

  const _LogoDisplay({required this.appTitle});

  @override
  Widget build(BuildContext context) {
    return _LogoText(appTitle: appTitle);
  }
}

/// Styled "Rehan Rose" text logo for dark background (fallback when image asset is missing).
class _LogoText extends StatelessWidget {
  final String appTitle;

  const _LogoText({required this.appTitle});

  @override
  Widget build(BuildContext context) {
    return Text(
      appTitle,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.footerText,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            fontSize: 26,
            height: 1.2,
          ),
    );
  }
}

/// Social icon as IconButton: white/light grey by default, brand color on hover. Opens URL via url_launcher.
class _SocialIconButton extends StatefulWidget {
  final IconData icon;
  final String url;
  final Color hoverColor;

  const _SocialIconButton({
    required this.icon,
    required this.url,
    required this.hoverColor,
  });

  @override
  State<_SocialIconButton> createState() => _SocialIconButtonState();
}

class _SocialIconButtonState extends State<_SocialIconButton> {
  bool _hovered = false;

  static const double _iconSize = 22;
  static const double _minTouchTarget = 40;

  @override
  Widget build(BuildContext context) {
    final defaultColor = AppColors.footerTextMuted; // White/light grey
    final color = _hovered ? widget.hoverColor : defaultColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: IconButton(
        onPressed: () => launchUrl(
          Uri.parse(widget.url),
          mode: LaunchMode.externalApplication,
        ),
        style: IconButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size(_minTouchTarget, _minTouchTarget),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.all(10),
        ),
        icon: FaIcon(
          widget.icon,
          size: _iconSize,
          color: color,
        ),
      ),
    );
  }
}

class _HelpColumn extends StatelessWidget {
  final AppLocalizations l10n;

  const _HelpColumn({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: l10n.footerHelpCenter),
        const SizedBox(height: 16),
        _FooterLink(
          label: l10n.navTrackOrder,
          onTap: () => showTrackOrderModal(context),
        ),
        _FooterLink(
          label: l10n.footerDeliveryZones,
          onTap: () => _showDeliveryZonesSheet(context),
        ),
        _FooterLink(
          label: l10n.footerFlowerCareGuide,
          onTap: () => _showFlowerCareGuideSheet(context),
        ),
        _FooterLink(
          label: l10n.footerFaqs,
          onTap: () => _showFaqSheet(context),
        ),
      ],
    );
  }

  void _showDeliveryZonesSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.footerBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.footerDeliveryZones,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      color: AppColors.footerText,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.footerDeliveryZonesIntro,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: AppColors.footerTextMuted,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 16),
              const _ZoneChip(label: 'Sulaymaniyah Center'),
              const _ZoneChip(label: 'Raparin'),
              const _ZoneChip(label: 'Bakrajo'),
              const _ZoneChip(label: 'Sarchnar'),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showFlowerCareGuideSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.footerBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.footerFlowerCareGuide,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      color: AppColors.footerText,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.flowerCareGuideIntro,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: AppColors.footerTextMuted,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 20),
              _CareTipRow(
                icon: Icons.water_drop_outlined,
                label: l10n.flowerCareTipWater,
              ),
              const SizedBox(height: 12),
              _CareTipRow(
                icon: Icons.wb_sunny_outlined,
                label: l10n.flowerCareTipSun,
              ),
              const SizedBox(height: 12),
              _CareTipRow(
                icon: Icons.content_cut,
                label: l10n.flowerCareTipStems,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showFaqSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.footerBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.footerFaqs,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        color: AppColors.footerText,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      children: [
                        _FaqExpansionTile(
                          question: l10n.faqPaymentQuestion,
                          answer: l10n.faqPaymentAnswer,
                        ),
                        _FaqExpansionTile(
                          question: l10n.faqDeliveryQuestion,
                          answer: l10n.faqDeliveryAnswer,
                        ),
                        _FaqExpansionTile(
                          question: l10n.faqReturnsQuestion,
                          answer: l10n.faqReturnsAnswer,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CareTipRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CareTipRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 24,
          color: AppColors.sage,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.footerText,
                  height: 1.4,
                ),
          ),
        ),
      ],
    );
  }
}

class _FaqExpansionTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqExpansionTile({
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: AppColors.footerDivider,
        highlightColor: AppColors.footerDivider,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        childrenPadding: const EdgeInsets.only(bottom: 16, left: 0, right: 0),
        collapsedIconColor: AppColors.footerTextMuted,
        iconColor: AppColors.footerText,
        title: Text(
          question,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.footerText,
                fontWeight: FontWeight.w600,
              ),
        ),
        children: [
          Text(
            answer,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.footerTextMuted,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _ZoneChip extends StatelessWidget {
  final String label;

  const _ZoneChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.footerDivider,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.footerText,
              ),
        ),
      ),
    );
  }
}

class _CompanyColumn extends StatelessWidget {
  final AppLocalizations l10n;

  const _CompanyColumn({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: l10n.footerCompanyTitle),
        const SizedBox(height: 16),
        _FooterLink(
          label: l10n.footerAboutUs,
          onTap: () => context.go('/about'),
        ),
        _FooterLink(
          label: l10n.footerBecomeFlorist,
          onTap: () => context.go('/vendor'),
          highlighted: true,
          leadingIcon: Icons.storefront_outlined,
        ),
        _FooterLink(
          label: l10n.footerPrivacyTerms,
          onTap: () => context.go('/legal'),
        ),
      ],
    );
  }
}

class _ContactColumn extends StatelessWidget {
  final AppLocalizations l10n;
  final String address;

  const _ContactColumn({required this.l10n, required this.address});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: l10n.footerContactUs),
        const SizedBox(height: 16),
        _ContactPhoneLink(phoneDisplay: _kContactPhoneDisplay),
        const SizedBox(height: 14),
        _ContactWhatsAppLink(label: l10n.footerChatOnWhatsApp),
        const SizedBox(height: 14),
        Text(
          address,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.footerTextMuted,
                height: 1.5,
              ),
        ),
        const SizedBox(height: 14),
        _ContactEmailLink(email: _kContactEmail),
      ],
    );
  }
}

/// Large, readable phone number. On tap opens the phone dialer (tel: scheme; works on mobile and desktop).
class _ContactPhoneLink extends StatefulWidget {
  final String phoneDisplay;

  const _ContactPhoneLink({required this.phoneDisplay});

  @override
  State<_ContactPhoneLink> createState() => _ContactPhoneLinkState();
}

class _ContactPhoneLinkState extends State<_ContactPhoneLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => launchUrl(
          Uri.parse('tel:+$_kContactPhoneE164'),
          mode: LaunchMode.externalApplication,
        ),
        child: Text(
          widget.phoneDisplay,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: _hovered ? AppColors.footerText : AppColors.footerTextMuted,
                fontWeight: FontWeight.w600,
                fontSize: 22,
                letterSpacing: 0.3,
                height: 1.3,
              ),
        ),
      ),
    );
  }
}

/// "Chat on WhatsApp" button; opens wa.me support link.
class _ContactWhatsAppLink extends StatefulWidget {
  final String label;

  const _ContactWhatsAppLink({required this.label});

  @override
  State<_ContactWhatsAppLink> createState() => _ContactWhatsAppLinkState();
}

class _ContactWhatsAppLinkState extends State<_ContactWhatsAppLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => launchUrl(
          Uri.parse('https://wa.me/$_kWhatsAppNumber'),
          mode: LaunchMode.externalApplication,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.whatsapp,
              size: 22,
              color: _hovered ? const Color(0xFF25D366) : AppColors.footerTextMuted,
            ),
            const SizedBox(width: 10),
            Text(
              widget.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _hovered ? AppColors.footerText : AppColors.footerTextMuted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactEmailLink extends StatefulWidget {
  final String email;

  const _ContactEmailLink({required this.email});

  @override
  State<_ContactEmailLink> createState() => _ContactEmailLinkState();
}

class _ContactEmailLinkState extends State<_ContactEmailLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => launchUrl(
          Uri.parse('mailto:${widget.email}'),
          mode: LaunchMode.externalApplication,
        ),
        child: Text(
          widget.email,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _hovered ? AppColors.footerText : AppColors.footerTextMuted,
                decoration: _hovered ? TextDecoration.underline : null,
              ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.footerText,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
    );
  }
}

class _FooterLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool highlighted;
  final IconData? leadingIcon;

  const _FooterLink({
    required this.label,
    required this.onTap,
    this.highlighted = false,
    this.leadingIcon,
  });

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.highlighted
        ? AppColors.footerText
        : AppColors.footerTextMuted;
    final hoverColor = AppColors.footerText;
    final fontWeight = widget.highlighted ? FontWeight.w600 : FontWeight.normal;
    final color = _hovered ? hoverColor : baseColor;

    final content = Text(
      widget.label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: fontWeight,
            decoration: _hovered ? TextDecoration.underline : null,
          ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: widget.leadingIcon != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.leadingIcon,
                      size: 18,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    content,
                  ],
                )
              : content,
        ),
      ),
    );
  }
}

/// Bottom bar: darker background, divider above, copyright left, payment icons right.
/// Payment icons are 24px height, grayscale by default, colored on hover.
class _BottomBar extends StatelessWidget {
  final AppLocalizations l10n;

  const _BottomBar({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > kMobileBreakpoint;

    final content = isDesktop
        ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                l10n.footerCopyright(DateTime.now().year),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.footerTextMuted,
                    ),
              ),
              const _PaymentBadges(),
            ],
          )
        : Column(
            children: [
              const _PaymentBadges(),
              const SizedBox(height: 16),
              Text(
                l10n.footerCopyright(DateTime.now().year),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.footerTextMuted,
                    ),
              ),
            ],
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
      decoration: const BoxDecoration(
        color: AppColors.footerBottomBarBackground,
      ),
      child: content,
    );
  }
}

/// Grayscale color filter matrix for payment icons (default state).
const List<double> _kGrayscaleFilter = [
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
];

/// Payment method icons: small images, grayscale by default, colored on hover.
/// When image is missing, shows a styled text badge (same hover behavior).
class _PaymentBadges extends StatelessWidget {
  const _PaymentBadges();

  static const String _assetPath = 'assets/images/payments';
  static const List<String> _assetNames = ['fastpay', 'zaincash', 'fib', 'visa'];
  static const Map<String, String> _displayNames = {
    'fastpay': 'FastPay',
    'zaincash': 'ZainCash',
    'fib': 'FIB',
    'visa': 'Visa',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _assetNames
          .map((name) => Padding(
                padding: const EdgeInsets.only(left: 6, right: 6),
                child: _PaymentIcon(
                  assetPath: '$_assetPath/$name.png',
                  label: _displayNames[name] ?? name,
                ),
              ))
          .toList(),
    );
  }
}

class _PaymentIcon extends StatefulWidget {
  final String assetPath;
  final String label;

  const _PaymentIcon({required this.assetPath, required this.label});

  @override
  State<_PaymentIcon> createState() => _PaymentIconState();
}

class _PaymentIconState extends State<_PaymentIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    const height = 24.0;
    final child = Image.asset(
      widget.assetPath,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _PaymentTextBadge(
        label: widget.label,
        height: height,
      ),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: ColorFiltered(
        colorFilter: _hovered
            ? const ColorFilter.matrix([
                1, 0, 0, 0, 0,
                0, 1, 0, 0, 0,
                0, 0, 1, 0, 0,
                0, 0, 0, 1, 0,
              ])
            : const ColorFilter.matrix(_kGrayscaleFilter),
        child: child,
      ),
    );
  }
}

/// Text badge shown when payment logo image is missing; grayscale/color on hover.
class _PaymentTextBadge extends StatefulWidget {
  final String label;
  final double height;

  const _PaymentTextBadge({required this.label, required this.height});

  @override
  State<_PaymentTextBadge> createState() => _PaymentTextBadgeState();
}

class _PaymentTextBadgeState extends State<_PaymentTextBadge> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? AppColors.footerText : AppColors.footerTextMuted;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Text(
          widget.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
        ),
      ),
    );
  }
}
