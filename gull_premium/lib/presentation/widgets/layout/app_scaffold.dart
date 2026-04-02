import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../controllers/controllers.dart';
import '../../../core/constants/breakpoints.dart';
import '../../../core/constants/emotion_category.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/emotion_category_l10n.dart';
import '../../../core/utils/locale_provider.dart';
import '../../../core/utils/rtl_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../pages/auth/login_screen.dart';
import '../../pages/track_order_screen.dart';
import '../common/floating_whatsapp_button.dart';
import 'app_footer.dart';

void showDeliveryAreasDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.helpDeliveryAreas),
      content: Text(
        'We deliver across our service areas. Check back soon for a full list of delivery zones, or contact us to confirm your address.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    ),
  );
}

void showContactUsDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.helpContactUs),
      content: Text(
        'Reach us by email or phone. Our team will get back to you as soon as possible.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    ),
  );
}

void showFaqDialog(BuildContext context) {
  context.go('/faq');
}

/// Opens customer login: modal on mobile, push /login on desktop.
void showLoginModalOrPush(BuildContext context) {
  if (MediaQuery.sizeOf(context).width <= kMobileBreakpoint) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const SafeArea(
          top: false,
          child: LoginScreen(showAsModal: true),
        ),
      ),
    );
  } else {
    context.push('/login');
  }
}

/// Wraps the app with a consistent layout. Shows the public website header
/// (logo, Occasions, Florists, Track Order, Help, Become a Vendor, Sign In).
/// Header is sticky. About is in the footer.
/// Vendor dashboard pages render their own [VendorDashboardHeader].
/// Pass [scrollController] for pages that need scroll-based logic (e.g. infinite scroll).
/// When [minimalHeader] is true, shows a transparent overlay header (hamburger, logo, profile) for cinematic landing.
/// When [title] is set, the header shows this instead of the app title (e.g. "Account" on profile page).
class AppScaffold extends ConsumerWidget {
  final Widget child;
  final ScrollController? scrollController;
  /// When true, show minimal transparent header (hamburger, app name, profile) instead of full nav.
  final bool minimalHeader;
  /// Optional page title; when set, shown in the header center instead of [AppLocalizations.appTitle].
  final String? title;

  const AppScaffold({
    super.key,
    required this.child,
    this.scrollController,
    this.minimalHeader = false,
    this.title,
  });

  /// True when we are on a vendor route and the user is authenticated,
  /// so the vendor page will show [VendorDashboardHeader] and we must not
  /// show the public nav.
  static bool _isVendorDashboard(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    if (!path.startsWith('/vendor')) return false;
    final auth = ref.watch(authStateProvider);
    return auth.hasValue && auth.value != null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showPublicHeader = !_isVendorDashboard(context, ref);

    return Scaffold(
      floatingActionButton: const Padding(
        padding: EdgeInsets.only(bottom: 22),
        child: FloatingWhatsappButton(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      drawer: showPublicHeader
          ? _MobileNavDrawer(
              onNavigate: () {
                Navigator.of(context).pop();
              },
            )
          : null,
      body: minimalHeader && showPublicHeader
          ? Stack(
              children: [
                SafeArea(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      children: [
                        child,
                        if (showPublicHeader) const AppFooter(),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _MinimalTransparentHeader(),
                ),
              ],
            )
          : SafeArea(
              child: Column(
                children: [
                  if (showPublicHeader) _PublicHeader(title: title),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        children: [
                          child,
                          if (showPublicHeader) const AppFooter(),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Public website header: hamburger (left), app title or page title (center), profile/sign-in (right).
class _PublicHeader extends ConsumerWidget {
  const _PublicHeader({this.title});

  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final centerTitle = title ?? l10n.appTitle;
    const maxWidth = 1280.0;
    const horizontalPadding = 16.0;
    const verticalPadding = 16.0;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.headerBackground,
        border: Border(
          bottom: BorderSide(color: AppColors.headerBorder, width: 1),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: horizontalPadding,
              end: horizontalPadding,
              top: verticalPadding,
              bottom: verticalPadding,
            ),
            child: Row(
              textDirection: Directionality.of(context),
              children: [
                IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.inkCharcoal,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: () => context.go('/'),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Text(
                          centerTitle,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppColors.inkCharcoal,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
                const _AuthHeaderAction(),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

/// Minimal transparent overlay header for hero/landing: hamburger, app name, profile.
class _MinimalTransparentHeader extends ConsumerWidget {
  const _MinimalTransparentHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: Colors.transparent),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            textDirection: Directionality.of(context),
            children: [
              IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(context).openDrawer(),
                style: IconButton.styleFrom(foregroundColor: Colors.white),
              ),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () => context.go('/'),
                    child: Text(
                      l10n.appTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                    ),
                  ),
                ),
              ),
              const _AuthHeaderAction(minimalStyle: true),
            ],
          ),
        ),
      ),
    );
  }
}

/// Language dropdown: English, کوردی, العربية. Persists to SharedPreferences + Firestore.
class _LanguageSwitcher extends ConsumerWidget {
  /// When true, use white/off-white for glassmorphism drawer.
  final bool lightStyle;

  const _LanguageSwitcher({this.lightStyle = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context)!;
    final textColor = lightStyle ? Colors.white.withValues(alpha: 0.9) : AppColors.inkCharcoal;
    final iconColor = lightStyle ? Colors.white.withValues(alpha: 0.9) : AppColors.inkCharcoal;

    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 40),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              languageDisplayName(locale.languageCode, context),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            directionalIcon(context, Icons.keyboard_arrow_down_rounded,
                size: 20, color: iconColor),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'en',
          child: Text(l10n.languageEnglish),
        ),
        PopupMenuItem(
          value: 'ku',
          child: Text(l10n.languageKurdish),
        ),
        PopupMenuItem(
          value: 'ar',
          child: Text(l10n.languageArabic),
        ),
      ],
      onSelected: (code) async {
        await ref.read(localeProvider.notifier).setLocale(Locale(code));
      },
    );
  }
}

/// Header auth action: if logged in shows avatar (→ /account), else "Sign In / Register" (opens login).
/// When [minimalStyle] is true, uses light colors for transparent hero header.
class _AuthHeaderAction extends ConsumerWidget {
  const _AuthHeaderAction({this.minimalStyle = false});

  final bool minimalStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final l10n = AppLocalizations.of(context)!;

    if (user != null) {
      return const SizedBox(width: 40);
    }

    if (minimalStyle) {
      return IconButton(
        icon: const Icon(Icons.person_outline_rounded),
        onPressed: () => showLoginModalOrPush(context),
        style: IconButton.styleFrom(foregroundColor: Colors.white),
      );
    }
    return _SignInRegisterButton(label: l10n.signInRegister);
  }
}

/// Sign In / Register text button; opens customer login (modal or /login). Hover: color only.
class _SignInRegisterButton extends StatefulWidget {
  final String label;

  const _SignInRegisterButton({required this.label});

  @override
  State<_SignInRegisterButton> createState() => _SignInRegisterButtonState();
}

class _SignInRegisterButtonState extends State<_SignInRegisterButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? AppColors.inkCharcoal : AppColors.navMuted;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showLoginModalOrPush(context),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 10),
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}

/// Occasions accordion in mobile drawer: expands to show emotion categories.
class _OccasionsAccordion extends StatefulWidget {
  final VoidCallback onNavigate;
  /// When true, use white/serif styling for glassmorphism drawer.
  final bool glassStyle;

  const _OccasionsAccordion({required this.onNavigate, this.glassStyle = false});

  @override
  State<_OccasionsAccordion> createState() => _OccasionsAccordionState();
}

class _OccasionsAccordionState extends State<_OccasionsAccordion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isGlass = widget.glassStyle;
    final titleColor = isGlass ? Colors.white : AppColors.inkCharcoal;
    final subtitleColor = isGlass ? Colors.white.withValues(alpha: 0.85) : AppColors.inkMuted;
    final titleStyle = isGlass
        ? GoogleFonts.playfairDisplay(
            fontSize: 23,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          )
        : Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w500,
          );
    final subtitleStyle = isGlass
        ? TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: subtitleColor,
          )
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: subtitleColor,
            fontWeight: FontWeight.w500,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.navOccasions,
                      style: titleStyle,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: directionalIcon(
                      context,
                      Icons.keyboard_arrow_down_rounded,
                      size: 24,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsetsDirectional.only(start: 20, top: 4, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: kEmotionCategories.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.go('/products?category=${cat.id}');
                        widget.onNavigate();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Text(
                          localizedEmotionCategoryTitle(l10n, cat.titleKey),
                          style: subtitleStyle,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

/// Primary nav item for glass drawer: large serif, white, generous padding.
Widget _glassDrawerPrimaryItem({
  required BuildContext context,
  required String label,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
      child: Text(
        label,
        style: GoogleFonts.playfairDisplay(
          fontSize: 23,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    ),
  );
}

/// Secondary nav item for glass drawer: smaller, lighter font.
Widget _glassDrawerSecondaryItem({
  required BuildContext context,
  required String label,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: Colors.white.withValues(alpha: 0.88),
        ),
      ),
    ),
  );
}

/// Mobile drawer: glassmorphism nav with Occasions accordion, language switcher, primary actions.
class _MobileNavDrawer extends ConsumerWidget {
  final VoidCallback onNavigate;

  const _MobileNavDrawer({required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    const horizontalPadding = 28.0;
    const verticalPadding = 28.0;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header: logo + close
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      horizontalPadding,
                      verticalPadding,
                      horizontalPadding,
                      0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.appTitle,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onNavigate,
                          icon: const Icon(Icons.close, color: Colors.white),
                          style: IconButton.styleFrom(
                            foregroundColor: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Scrollable nav
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        horizontalPadding,
                        8,
                        horizontalPadding,
                        24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Primary: Occasions
                          _OccasionsAccordion(
                            onNavigate: onNavigate,
                            glassStyle: true,
                          ),
                          _glassDrawerPrimaryItem(
                            context: context,
                            label: l10n.navOffers,
                            onTap: () {
                              context.go('/offers');
                              onNavigate();
                            },
                          ),
                          _glassDrawerPrimaryItem(
                            context: context,
                            label: l10n.navFlorists,
                            onTap: () {
                              context.go('/florists');
                              onNavigate();
                            },
                          ),
                          const SizedBox(height: 20),
                          // Subtle divider
                          Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.15),
                            thickness: 1,
                          ),
                          const SizedBox(height: 16),
                          // Secondary nav (order: Track Order, Delivery Areas, About Us, Terms & Conditions, Contact Us)
                          _glassDrawerSecondaryItem(
                            context: context,
                            label: l10n.navTrackOrder,
                            onTap: () {
                              onNavigate();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const TrackOrderScreen(),
                                ),
                              );
                            },
                          ),
                          _glassDrawerSecondaryItem(
                            context: context,
                            label: l10n.helpDeliveryAreas,
                            onTap: () {
                              showDeliveryAreasDialog(context);
                              onNavigate();
                            },
                          ),
                          const SizedBox(height: 16),
                          Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.15),
                            thickness: 1,
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            dense: true,
                            contentPadding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 0,
                            ),
                            leading: Icon(
                              Icons.info_outline,
                              size: 22,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            title: Text(
                              l10n.footerAboutUs,
                              style: GoogleFonts.montserrat(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                            onTap: () {
                              context.go('/about');
                              onNavigate();
                            },
                          ),
                          ListTile(
                            dense: true,
                            contentPadding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 0,
                            ),
                            leading: const Icon(
                              Icons.help_outline,
                              size: 22,
                              color: Colors.white,
                            ),
                            title: Text(
                              l10n.helpFaq,
                              style: GoogleFonts.montserrat(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                            onTap: () {
                              showFaqDialog(context);
                              onNavigate();
                            },
                          ),
                          ListTile(
                            dense: true,
                            contentPadding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 0,
                            ),
                            leading: Icon(
                              Icons.description_outlined,
                              size: 22,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            title: Text(
                              l10n.termsAndConditions,
                              style: GoogleFonts.montserrat(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                            onTap: () {
                              context.go('/terms-conditions');
                              onNavigate();
                            },
                          ),
                          ListTile(
                            dense: true,
                            contentPadding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 0,
                            ),
                            leading: Icon(
                              Icons.support_agent_outlined,
                              size: 22,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            title: Text(
                              l10n.contactUs,
                              style: GoogleFonts.montserrat(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                            onTap: () {
                              context.go('/contact-us');
                              onNavigate();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Footer: action buttons + language
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20,
                      horizontalPadding,
                      verticalPadding + 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ref.watch(authStateProvider).when(
                          data: (user) {
                            if (user != null) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  OutlinedButton(
                                    onPressed: () {
                                      context.go('/account');
                                      onNavigate();
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        width: 1.2,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 24,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      l10n.account,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    onPressed: () {
                                      context.go('/vendor-auth');
                                      onNavigate();
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        width: 1.2,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 24,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      l10n.ctaBecomeVendor,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildJoinDeliveryFleetTile(context),
                                ],
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                OutlinedButton(
                                  onPressed: () {
                                    onNavigate();
                                    showLoginModalOrPush(context);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                                    side: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      width: 1.2,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 24,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    l10n.signInRegister,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: () {
                                    context.go('/vendor-auth');
                                    onNavigate();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      width: 1.2,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 24,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    l10n.ctaBecomeVendor,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildJoinDeliveryFleetTile(context),
                              ],
                            );
                          },
                          loading: () => _buildGlassAuthButtons(context, l10n),
                          error: (_, __) => _buildGlassAuthButtons(context, l10n),
                        ),
                        const SizedBox(height: 16),
                        _LanguageSwitcher(lightStyle: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoinDeliveryFleetTile(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          dense: true,
          minVerticalPadding: 0,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
          leading: Icon(
            Icons.local_shipping_outlined,
            size: 22,
            color: AppColors.rosePrimary,
          ),
          title: Text(
            l10n.driveWithRehanRose,
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.1,
            ),
          ),
          onTap: () {
            context.go('/driver-auth');
            onNavigate();
          },
        ),
      ),
    );
  }

  Widget _buildGlassAuthButtons(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: () {
            onNavigate();
            showLoginModalOrPush(context);
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.2,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            l10n.signInRegister,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () {
            context.go('/vendor-auth');
            onNavigate();
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.2,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            l10n.ctaBecomeVendor,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 12),
        _buildJoinDeliveryFleetTile(context),
      ],
    );
  }
}
