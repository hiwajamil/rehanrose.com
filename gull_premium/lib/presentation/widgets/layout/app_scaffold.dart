import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../controllers/controllers.dart';
import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../common/primary_button.dart';

/// Wraps the app with a consistent layout. Shows the public website header
/// (logo, Flowers, Occasions, Vendors, About, Become a Vendor, Sign In) except when
/// the user is on the vendor dashboard (route /vendor and authenticated).
/// Vendor dashboard pages render their own [VendorDashboardHeader].
class AppScaffold extends ConsumerWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  /// True when we are on a vendor route and the user is authenticated,
  /// so the vendor page will show [VendorDashboardHeader] and we must not
  /// show the public nav (Flowers, Occasions, etc.).
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
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (showPublicHeader) const _PublicHeader(),
              child,
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

/// Public website header: brand, nav, actions. Clean, minimal, premium.
class _PublicHeader extends StatelessWidget {
  const _PublicHeader();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    const maxWidth = 1280.0; // max-w-7xl
    const horizontalPadding = 16.0; // px-4
    const verticalPadding = 16.0; // py-4

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
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Row(
              children: [
                // —— Brand (left) ——
                GestureDetector(
                  onTap: () => context.go('/'),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      'Rehan Rose',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.inkCharcoal,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                    ),
                  ),
                ),
                const Spacer(),
                // —— Center nav (desktop only) ——
                if (!isMobile) ...[
                  _NavLink(label: 'Flowers', onTap: () => context.go('/')),
                  const SizedBox(width: 32),
                  _NavLink(label: 'Occasions', onTap: () => context.go('/')),
                  const SizedBox(width: 32),
                  _NavLink(label: 'Vendors', onTap: () => context.go('/')),
                  const SizedBox(width: 32),
                  _NavLink(label: 'About', onTap: () => context.go('/')),
                ],
                if (!isMobile) const Spacer(),
                // —— Actions (right) ——
                if (!isMobile) ...[
                  _HeaderOutlinedButton(
                    label: 'Become a Vendor',
                    onPressed: () => context.go('/vendor'),
                  ),
                  const SizedBox(width: 16),
                  _SignInButton(),
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

/// Single nav link: hover changes color only, no movement.
class _NavLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _NavLink({required this.label, required this.onTap});

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? AppColors.inkCharcoal : AppColors.navMuted;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

/// Sign In text button; navigates to vendor (login). Hover: color only.
class _SignInButton extends StatefulWidget {
  @override
  State<_SignInButton> createState() => _SignInButtonState();
}

class _SignInButtonState extends State<_SignInButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? AppColors.inkCharcoal : AppColors.navMuted;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go('/vendor'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Text(
            'Sign In',
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

/// Mobile drawer: nav links + primary actions. No sliding emphasis; calm list.
class _MobileNavDrawer extends StatelessWidget {
  final VoidCallback onNavigate;

  const _MobileNavDrawer({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final navItems = [
      ('Flowers', () => context.go('/')),
      ('Occasions', () => context.go('/')),
      ('Vendors', () => context.go('/')),
      ('About', () => context.go('/')),
    ];

    return Drawer(
      backgroundColor: AppColors.headerBackground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Rehan Rose',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.inkCharcoal,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 32),
              ...navItems.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      e.$2();
                      onNavigate();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      child: Text(
                        e.$1,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.inkCharcoal,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
              const Divider(color: AppColors.headerBorder, height: 1),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Become a Vendor',
                  onPressed: () {
                    context.go('/vendor');
                    onNavigate();
                  },
                  variant: PrimaryButtonVariant.outline,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    context.go('/vendor');
                    onNavigate();
                  },
                  child: Text(
                    'Sign In',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.navMuted,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
