import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../controllers/controllers.dart';
import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'vendor_dashboard_header.dart';

/// Vendor dashboard shell: fixed header + left sidebar (desktop) or drawer (mobile) + content.
class VendorShellLayout extends ConsumerWidget {
  final Widget child;

  const VendorShellLayout({super.key, required this.child});

  static const int _sidebarWidth = 240;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;

    if (isMobile) {
      return Scaffold(
        drawer: _VendorDrawer(),
        body: Column(
          children: [
            Builder(
              builder: (ctx) => _HeaderInAppBar(
                onMenuTap: () => Scaffold.maybeOf(ctx)?.openDrawer(),
                ref: ref,
              ),
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context, ref),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _VendorSidebar(width: _sidebarWidth.toDouble()),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authStateProvider).value;
    final name = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : (user?.email ?? l10n.vendorDefaultName);
    return VendorDashboardHeader(
      vendorName: name,
      unreadNotificationCount: 0,
      onProfile: () => context.go('/vendor/shop-settings'),
      onLogout: () => ref.read(authRepositoryProvider).signOut(),
    );
  }
}

/// Wraps VendorDashboardHeader for mobile with drawer menu icon.
class _HeaderInAppBar extends StatelessWidget {
  final VoidCallback onMenuTap;
  final WidgetRef ref;

  const _HeaderInAppBar({required this.onMenuTap, required this.ref});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authStateProvider).value;
    final name = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : (user?.email ?? l10n.vendorDefaultName);
    return SafeArea(
      child: VendorDashboardHeader(
        leading: IconButton(
          onPressed: onMenuTap,
          icon: const Icon(Icons.menu, color: AppColors.ink),
          tooltip: l10n.menu,
        ),
        vendorName: name,
        unreadNotificationCount: 0,
        onProfile: () => context.go('/vendor/shop-settings'),
        onLogout: () => ref.read(authRepositoryProvider).signOut(),
      ),
    );
  }
}

class _VendorSidebar extends StatelessWidget {
  final double width;

  const _VendorSidebar({required this.width});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final path = GoRouterState.of(context).uri.path;

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        right: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          children: [
            _NavTile(
              label: l10n.vendorNavDashboard,
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard,
              path: '/vendor',
              currentPath: path,
            ),
            _NavTile(
              label: l10n.vendorNavOrders,
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long,
              path: '/vendor/orders',
              currentPath: path,
            ),
            _NavTile(
              label: l10n.vendorNavBouquets,
              icon: Icons.local_florist_outlined,
              activeIcon: Icons.local_florist,
              path: '/vendor/bouquets',
              currentPath: path,
            ),
            _NavTile(
              label: l10n.vendorNavAddBouquet,
              icon: Icons.add_circle_outline,
              activeIcon: Icons.add_circle,
              path: '/vendor/bouquets/add',
              currentPath: path,
            ),
            _NavTile(
              label: l10n.vendorNavEarnings,
              icon: Icons.payments_outlined,
              activeIcon: Icons.payments,
              path: '/vendor/earnings',
              currentPath: path,
            ),
            _NavTile(
              label: l10n.vendorNavNotifications,
              icon: Icons.notifications_none,
              activeIcon: Icons.notifications,
              path: '/vendor/notifications',
              currentPath: path,
            ),
            const Divider(height: 24),
            _NavTile(
              label: l10n.vendorNavShopSettings,
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings,
              path: '/vendor/shop-settings',
              currentPath: path,
            ),
            _NavTile(
              label: l10n.vendorNavSupport,
              icon: Icons.help_outline,
              activeIcon: Icons.help,
              path: '/vendor/support',
              currentPath: path,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;
  final String currentPath;

  const _NavTile({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
    required this.currentPath,
  });

  bool get _isActive {
    if (path == '/vendor') return currentPath == '/vendor' || currentPath == '/vendor/';
    return currentPath == path || currentPath.startsWith('$path/');
  }

  @override
  Widget build(BuildContext context) {
    final active = _isActive;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(
          active ? activeIcon : icon,
          size: 22,
          color: active ? AppColors.rose : AppColors.inkMuted,
        ),
        title: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: active ? AppColors.ink : AppColors.inkMuted,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
        ),
        selected: active,
        selectedTileColor: AppColors.rose.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: () => context.go(path),
      ),
    );
  }
}

/// Same nav content as sidebar, for use in drawer on mobile.
class _VendorDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Text(
                AppLocalizations.of(context)!.appTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context)!;
                  return ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    children: [
                      _NavTile(
                        label: l10n.vendorNavDashboard,
                        icon: Icons.dashboard_outlined,
                        activeIcon: Icons.dashboard,
                        path: '/vendor',
                        currentPath: path,
                      ),
                      _NavTile(
                        label: l10n.vendorNavOrders,
                        icon: Icons.receipt_long_outlined,
                        activeIcon: Icons.receipt_long,
                        path: '/vendor/orders',
                        currentPath: path,
                      ),
                      _NavTile(
                        label: l10n.vendorNavBouquets,
                        icon: Icons.local_florist_outlined,
                        activeIcon: Icons.local_florist,
                        path: '/vendor/bouquets',
                        currentPath: path,
                      ),
                      _NavTile(
                        label: l10n.vendorNavAddBouquet,
                        icon: Icons.add_circle_outline,
                        activeIcon: Icons.add_circle,
                        path: '/vendor/bouquets/add',
                        currentPath: path,
                      ),
                      _NavTile(
                        label: l10n.vendorNavEarnings,
                        icon: Icons.payments_outlined,
                        activeIcon: Icons.payments,
                        path: '/vendor/earnings',
                        currentPath: path,
                      ),
                      _NavTile(
                        label: l10n.vendorNavNotifications,
                        icon: Icons.notifications_none,
                        activeIcon: Icons.notifications,
                        path: '/vendor/notifications',
                        currentPath: path,
                      ),
                      const Divider(height: 24),
                      _NavTile(
                        label: l10n.vendorNavShopSettings,
                        icon: Icons.settings_outlined,
                        activeIcon: Icons.settings,
                        path: '/vendor/shop-settings',
                        currentPath: path,
                      ),
                      _NavTile(
                        label: l10n.vendorNavSupport,
                        icon: Icons.help_outline,
                        activeIcon: Icons.help,
                        path: '/vendor/support',
                        currentPath: path,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
