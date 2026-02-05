import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../controllers/controllers.dart';
import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../common/primary_button.dart';

/// Wraps the app with a consistent layout. Shows the public website header
/// (logo, Flowers, Occasions, Vendors, About, Become a Vendor) except when
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

    return Scaffold(
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

/// Public website header: logo + nav links + Become a Vendor.
/// Shown for unauthenticated users and for non-vendor routes.
class _PublicHeader extends StatelessWidget {
  const _PublicHeader();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    final horizontalPadding = isMobile ? 16.0 : 48.0;
    final verticalPadding = isMobile ? 16.0 : 28.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/'),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                'Rehan Rose',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          const Spacer(),
          if (!isMobile) ...[
            const _NavItem(label: 'Flowers'),
            const _NavItem(label: 'Occasions'),
            const _NavItem(label: 'Vendors'),
            const _NavItem(label: 'About'),
          ],
          PrimaryButton(
            label: 'Become a Vendor',
            onPressed: () => context.go('/vendor'),
            variant: PrimaryButtonVariant.outline,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final String label;

  const _NavItem({required this.label});

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: _hovered ? AppColors.rose : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
        child: Text(
          widget.label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
