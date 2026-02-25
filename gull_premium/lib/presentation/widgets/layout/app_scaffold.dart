import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../controllers/controllers.dart';
import '../../../core/constants/breakpoints.dart';
import '../../../core/constants/emotion_category.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/emotion_category_l10n.dart';
import '../../../core/utils/locale_provider.dart';
import '../../../core/utils/rtl_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../pages/auth/login_screen.dart';
import '../common/primary_button.dart';
import '../common/track_order_modal.dart';
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
  final l10n = AppLocalizations.of(context)!;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.helpFaq),
      content: SingleChildScrollView(
        child: Text(
          'Frequently asked questions will be listed here. Check back soon.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
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
class AppScaffold extends ConsumerWidget {
  final Widget child;
  final ScrollController? scrollController;

  const AppScaffold({super.key, required this.child, this.scrollController});

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
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;

    return Scaffold(
      drawer: showPublicHeader && isMobile
          ? _MobileNavDrawer(
              onNavigate: () {
                Navigator.of(context).pop();
              },
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            if (showPublicHeader) const _PublicHeader(),
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

/// Public website header: brand, nav (Occasions, Florists, Track Order, Help), actions.
class _PublicHeader extends ConsumerStatefulWidget {
  const _PublicHeader();

  @override
  ConsumerState<_PublicHeader> createState() => _PublicHeaderState();
}

class _PublicHeaderState extends ConsumerState<_PublicHeader> {
  OverlayEntry? _occasionsOverlay;
  Timer? _occasionsCloseTimer;
  final GlobalKey _occasionsKey = GlobalKey();

  void _showOccasionsMenu(RenderBox navBox) {
    _occasionsCloseTimer?.cancel();
    // If menu is already open, don't remove/reinsert (causes flashing on hover)
    if (_occasionsOverlay != null) return;
    _occasionsOverlay = OverlayEntry(
      builder: (context) => _OccasionsMegaMenu(
        anchor: navBox,
        onClose: _hideOccasionsMenu,
        onEnterMenu: () => _occasionsCloseTimer?.cancel(),
        onLeaveMenu: _scheduleCloseOccasions,
        onSelectOccasion: (occasionId) {
          context.go('/products?category=$occasionId');
          _hideOccasionsMenu();
        },
        onSelectRecipient: (recipient) {
          context.go('/');
          _hideOccasionsMenu();
        },
      ),
    );
    Overlay.of(context).insert(_occasionsOverlay!);
  }

  void _hideOccasionsMenu() {
    _occasionsCloseTimer?.cancel();
    _occasionsOverlay?.remove();
    _occasionsOverlay = null;
    if (mounted) setState(() {});
  }

  void _scheduleCloseOccasions() {
    _occasionsCloseTimer?.cancel();
    _occasionsCloseTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _hideOccasionsMenu();
    });
  }

  @override
  void dispose() {
    _occasionsCloseTimer?.cancel();
    _occasionsOverlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
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
                GestureDetector(
                  onTap: () => context.go('/'),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      l10n.appTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.inkCharcoal,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                    ),
                  ),
                ),
                const Spacer(),
                if (!isMobile) ...[
                  _OccasionsNavItem(
                    key: _occasionsKey,
                    label: l10n.navOccasions,
                    isOpen: _occasionsOverlay != null,
                    onHoverOrTap: () {
                      final navBox = _occasionsKey.currentContext?.findRenderObject() as RenderBox?;
                      if (navBox != null && navBox.hasSize) _showOccasionsMenu(navBox);
                    },
                    onEnterMenu: () => _occasionsCloseTimer?.cancel(),
                    onLeaveMenu: _scheduleCloseOccasions,
                  ),
                  const SizedBox(width: 32),
                  _NavLink(
                    label: l10n.navOffers,
                    onTap: () => context.go('/offers'),
                    accentColor: AppColors.navOffersAccent,
                  ),
                  const SizedBox(width: 32),
                  _NavLink(
                    label: l10n.navFlorists,
                    onTap: () => context.go('/florists'),
                  ),
                  const SizedBox(width: 32),
                  _NavLink(
                    label: l10n.navTrackOrder,
                    onTap: () => showTrackOrderModal(context),
                  ),
                  const SizedBox(width: 32),
                  _HelpDropdown(),
                ],
                if (!isMobile) const Spacer(),
                if (!isMobile) ...[
                  _LanguageSwitcher(),
                  const SizedBox(width: 16),
                  _HeaderOutlinedButton(
                    label: l10n.ctaBecomeVendor,
                    onPressed: () => context.go('/vendor'),
                  ),
                  const SizedBox(width: 16),
                  const _AuthHeaderAction(),
                ],
                if (isMobile)
                  IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.inkCharcoal,
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

/// Nav item that opens Occasions mega menu on hover (desktop) or tap (mobile).
class _OccasionsNavItem extends StatefulWidget {
  final String label;
  final bool isOpen;
  final VoidCallback onHoverOrTap;
  final VoidCallback onEnterMenu;
  final VoidCallback onLeaveMenu;

  const _OccasionsNavItem({
    super.key,
    required this.label,
    required this.isOpen,
    required this.onHoverOrTap,
    required this.onEnterMenu,
    required this.onLeaveMenu,
  });

  @override
  State<_OccasionsNavItem> createState() => _OccasionsNavItemState();
}

class _OccasionsNavItemState extends State<_OccasionsNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = (_hovered || widget.isOpen) ? AppColors.inkCharcoal : AppColors.navMuted;
    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        widget.onHoverOrTap();
      },
      onExit: (_) {
        setState(() => _hovered = false);
        // Only schedule close when menu is not open. When the menu is open, the overlay
        // covers the nav item so we get a spurious onExit; the menu's own MouseRegion
        // handles scheduling close when the user actually leaves the menu panel.
        if (!widget.isOpen) widget.onLeaveMenu();
      },
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onHoverOrTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              directionalIcon(context, Icons.keyboard_arrow_down_rounded,
                  size: 20, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mega menu overlay: emotion categories + Shop by Recipient.
class _OccasionsMegaMenu extends StatelessWidget {
  final RenderBox anchor;
  final VoidCallback onClose;
  final VoidCallback onEnterMenu;
  final VoidCallback onLeaveMenu;
  final ValueChanged<String> onSelectOccasion;
  final ValueChanged<String> onSelectRecipient;

  const _OccasionsMegaMenu({
    required this.anchor,
    required this.onClose,
    required this.onEnterMenu,
    required this.onLeaveMenu,
    required this.onSelectOccasion,
    required this.onSelectRecipient,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final pos = anchor.localToGlobal(Offset.zero);
    final size = anchor.size;
    final screenWidth = MediaQuery.sizeOf(context).width;
    const menuWidth = 320.0;
    const menuPadding = 16.0;

    return Stack(
      children: [
        GestureDetector(
          onTap: onClose,
          behavior: HitTestBehavior.opaque,
          child: const SizedBox.expand(),
        ),
        Positioned(
          top: size.height + 4,
          left: isRTL ? null : pos.dx,
          right: isRTL ? (screenWidth - pos.dx - size.width) : null,
          child: MouseRegion(
            onEnter: (_) => onEnterMenu(),
            onExit: (_) => onLeaveMenu(),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: AppColors.surface,
              child: Container(
                width: menuWidth,
                padding: const EdgeInsets.all(menuPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...kEmotionCategories.map((cat) {
                      return _MegaMenuItem(
                        label: localizedEmotionCategoryTitle(l10n, cat.titleKey),
                        onTap: () => onSelectOccasion(cat.id),
                      );
                    }),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: AppColors.headerBorder),
                    ),
                    Text(
                      l10n.occasionsShopByRecipient,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.inkMuted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    _MegaMenuItem(
                      label: l10n.occasionsForMom,
                      onTap: () => onSelectRecipient('mom'),
                    ),
                    _MegaMenuItem(
                      label: l10n.occasionsForHer,
                      onTap: () => onSelectRecipient('her'),
                    ),
                    _MegaMenuItem(
                      label: l10n.occasionsForHim,
                      onTap: () => onSelectRecipient('him'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MegaMenuItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MegaMenuItem({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.inkCharcoal,
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

/// Help dropdown: Delivery Areas, Contact Us, FAQ.
class _HelpDropdown extends StatelessWidget {
  const _HelpDropdown();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 40),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.navHelp,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.navMuted,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            directionalIcon(context, Icons.keyboard_arrow_down_rounded,
                size: 20, color: AppColors.inkCharcoal),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'delivery',
          child: Text(l10n.helpDeliveryAreas),
        ),
        PopupMenuItem(
          value: 'contact',
          child: Text(l10n.helpContactUs),
        ),
        PopupMenuItem(
          value: 'faq',
          child: Text(l10n.helpFaq),
        ),
      ],
      onSelected: (value) {
        if (value == 'delivery') showDeliveryAreasDialog(context);
        if (value == 'contact') showContactUsDialog(context);
        if (value == 'faq') showFaqDialog(context);
      },
    );
  }
}

/// Language dropdown: English, کوردی, العربية. Persists to SharedPreferences + Firestore.
class _LanguageSwitcher extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context)!;

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
                    color: AppColors.inkCharcoal,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            directionalIcon(context, Icons.keyboard_arrow_down_rounded,
                size: 20, color: AppColors.inkCharcoal),
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

/// Single nav link: hover changes color only, no movement.
class _NavLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  /// When set, use this as the default (non-hover) color for emphasis (e.g. Offers).
  final Color? accentColor;

  const _NavLink({
    required this.label,
    required this.onTap,
    this.accentColor,
  });

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.accentColor ?? AppColors.navMuted;
    final color = _hovered ? AppColors.inkCharcoal : baseColor;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 4, vertical: 8),
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

/// Outlined pill button: rounded-full, subtle border, hover bg only.
class _HeaderOutlinedButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _HeaderOutlinedButton({
    required this.label,
    required this.onPressed,
  });

  @override
  State<_HeaderOutlinedButton> createState() => _HeaderOutlinedButtonState();
}

class _HeaderOutlinedButtonState extends State<_HeaderOutlinedButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.border.withValues(alpha: 0.6)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.headerBorder),
          ),
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkCharcoal,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}

/// Header auth action: if logged in shows avatar (→ /account), else "Sign In / Register" (opens login).
class _AuthHeaderAction extends ConsumerWidget {
  const _AuthHeaderAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final l10n = AppLocalizations.of(context)!;

    if (user != null) {
      return _HeaderAccountAvatar(
        photoUrl: user.photoURL,
        displayName: user.displayName,
        email: user.email,
      );
    }

    return _SignInRegisterButton(label: l10n.signInRegister);
  }
}

class _HeaderAccountAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? displayName;
  final String? email;

  const _HeaderAccountAvatar({
    this.photoUrl,
    this.displayName,
    this.email,
  });

  String get _initial {
    if (displayName != null && displayName!.isNotEmpty) return displayName![0];
    if (email != null && email!.isNotEmpty) return email![0];
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return GestureDetector(
      onTap: () => context.go('/account'),
      child: hasPhoto
          ? CachedNetworkImage(
              imageUrl: photoUrl!,
              imageBuilder: (_, imageProvider) => CircleAvatar(
                radius: 18,
                backgroundImage: imageProvider,
              ),
              placeholder: (_, __) => _buildInitialAvatar(),
              errorWidget: (_, __, ___) => _buildInitialAvatar(),
            )
          : _buildInitialAvatar(),
    );
  }

  Widget _buildInitialAvatar() {
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.border,
      child: Text(
        _initial.toUpperCase(),
        style: const TextStyle(
          color: AppColors.inkMuted,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
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

/// Drawer nav item: tappable row. [accentColor] optionally styles the text (e.g. Offers).
class _DrawerNavItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? accentColor;

  const _DrawerNavItem({
    required this.label,
    required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.inkCharcoal;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

/// Occasions accordion in mobile drawer: expands to show emotion categories.
class _OccasionsAccordion extends StatefulWidget {
  final VoidCallback onNavigate;

  const _OccasionsAccordion({required this.onNavigate});

  @override
  State<_OccasionsAccordion> createState() => _OccasionsAccordionState();
}

class _OccasionsAccordionState extends State<_OccasionsAccordion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.inkCharcoal,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: directionalIcon(
                      context,
                      Icons.keyboard_arrow_down_rounded,
                      size: 24,
                      color: AppColors.inkCharcoal,
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
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.inkMuted,
                                fontWeight: FontWeight.w500,
                              ),
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

/// Mobile drawer: nav links with Occasions accordion, language switcher, primary actions.
class _MobileNavDrawer extends ConsumerWidget {
  final VoidCallback onNavigate;

  const _MobileNavDrawer({required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Drawer(
      backgroundColor: AppColors.headerBackground,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.appTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.inkCharcoal,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 24),
              _LanguageSwitcher(),
              const SizedBox(height: 24),
              // Auth and Become a Vendor at top so they are visible on mobile without scrolling
              ref.watch(authStateProvider).when(
                data: (user) {
                  if (user != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PrimaryButton(
                          label: l10n.account,
                          onPressed: () {
                            context.go('/account');
                            onNavigate();
                          },
                          variant: PrimaryButtonVariant.outline,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: PrimaryButton(
                            label: l10n.ctaBecomeVendor,
                            onPressed: () {
                              context.go('/vendor');
                              onNavigate();
                            },
                            variant: PrimaryButtonVariant.outline,
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          label: l10n.signInRegister,
                          onPressed: () {
                            onNavigate();
                            showLoginModalOrPush(context);
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          label: l10n.ctaBecomeVendor,
                          onPressed: () {
                            context.go('/vendor');
                            onNavigate();
                          },
                          variant: PrimaryButtonVariant.outline,
                        ),
                      ),
                    ],
                  );
                },
                loading: () => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        label: l10n.signInRegister,
                        onPressed: () {
                          onNavigate();
                          showLoginModalOrPush(context);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        label: l10n.ctaBecomeVendor,
                        onPressed: () {
                          context.go('/vendor');
                          onNavigate();
                        },
                        variant: PrimaryButtonVariant.outline,
                      ),
                    ),
                  ],
                ),
                error: (_, __) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        label: l10n.signInRegister,
                        onPressed: () {
                          onNavigate();
                          showLoginModalOrPush(context);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        label: l10n.ctaBecomeVendor,
                        onPressed: () {
                          context.go('/vendor');
                          onNavigate();
                        },
                        variant: PrimaryButtonVariant.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _OccasionsAccordion(
                onNavigate: onNavigate,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DrawerNavItem(
                  label: l10n.navOffers,
                  onTap: () {
                    context.go('/offers');
                    onNavigate();
                  },
                  accentColor: AppColors.navOffersAccent,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DrawerNavItem(
                  label: l10n.navFlorists,
                  onTap: () {
                    context.go('/florists');
                    onNavigate();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DrawerNavItem(
                  label: l10n.navTrackOrder,
                  onTap: () {
                    showTrackOrderModal(context);
                    onNavigate();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DrawerNavItem(
                  label: l10n.helpDeliveryAreas,
                  onTap: () {
                    showDeliveryAreasDialog(context);
                    onNavigate();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DrawerNavItem(
                  label: l10n.helpContactUs,
                  onTap: () {
                    showContactUsDialog(context);
                    onNavigate();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DrawerNavItem(
                  label: l10n.helpFaq,
                  onTap: () {
                    showFaqDialog(context);
                    onNavigate();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DrawerNavItem(
                  label: l10n.navAbout,
                  onTap: () {
                    context.go('/');
                    onNavigate();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
