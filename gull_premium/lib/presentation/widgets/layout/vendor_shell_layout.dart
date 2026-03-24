import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../controllers/controllers.dart';
import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../vendor/vendor_new_order_sound_listener.dart';
import 'vendor_dashboard_header.dart';
import 'vendor_presence_controller.dart';

final _vendorStoreCategoryProvider = StreamProvider.autoDispose<String>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value('flowers');
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
    final raw = doc.data()?['storeCategory']?.toString().trim().toLowerCase();
    return raw == 'perfumes' ? 'perfumes' : 'flowers';
  });
});

/// Vendor dashboard shell: fixed header + left sidebar (desktop) or drawer (mobile) + content.
class VendorShellLayout extends ConsumerWidget {
  final Widget child;

  const VendorShellLayout({super.key, required this.child});

  static const int _sidebarWidth = 240;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    final user = ref.watch(authStateProvider).value;
    final storeCategory = ref.watch(_vendorStoreCategoryProvider).maybeWhen(
          data: (value) => value,
          orElse: () => 'flowers',
        );
    final bool isPerfume = storeCategory == 'perfumes';

    // Premium B2B SaaS: soft off-white content area
    const Color vendorContentBg = Color(0xFFF4F5F7);

    Widget scaffold;
    if (isMobile) {
      scaffold = VendorNewOrderSoundListener(
        child: Scaffold(
          drawer: _VendorDrawer(isPerfume: isPerfume),
          body: Column(
            children: [
              Builder(
                builder: (ctx) => _HeaderInAppBar(
                  onMenuTap: () => Scaffold.maybeOf(ctx)?.openDrawer(),
                  ref: ref,
                  isPerfume: isPerfume,
                ),
              ),
              Expanded(
                child: Material(
                  color: vendorContentBg,
                  child: ClipRect(
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      scaffold = VendorNewOrderSoundListener(
        child: Scaffold(
          backgroundColor: vendorContentBg,
          body: Column(
            children: [
              _buildHeader(context, ref, isPerfume),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _VendorSidebar(
                      width: _sidebarWidth.toDouble(),
                      isPerfume: isPerfume,
                    ),
                    Expanded(
                      child: Material(
                        color: vendorContentBg,
                        child: ClipRect(
                          child: child,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (user == null) return scaffold;
    return VendorPresenceController(
      vendorUid: user.uid,
      child: scaffold,
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, bool isPerfume) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authStateProvider).value;
    final email = user?.email ?? '';
    final name = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : (user?.email ?? l10n.vendorDefaultName);
    final badgeCount = ref.watch(vendorUnreadNotificationBadgeCountProvider);
    return VendorDashboardHeader(
      isPerfume: isPerfume,
      userEmail: email,
      vendorName: name,
      unreadNotificationCount: badgeCount,
      onProfile: () => context.go('/vendor/profile'),
      onLogout: () async {
        try {
          await ref.read(authRepositoryProvider).signOut();
        } finally {
          // Ensure Firebase session is cleared even if repo signOut had partial failure.
          await fa.FirebaseAuth.instance.signOut();
          if (context.mounted) context.go('/');
        }
      },
      onNotificationsViewed: () {
        ref.read(vendorLastSeenPendingCountProvider.notifier).setLastSeen(
              ref.read(vendorPendingOmsCountProvider),
            );
      },
    );
  }
}

/// Wraps VendorDashboardHeader for mobile with drawer menu icon.
class _HeaderInAppBar extends StatelessWidget {
  final VoidCallback onMenuTap;
  final WidgetRef ref;
  final bool isPerfume;

  const _HeaderInAppBar({
    required this.onMenuTap,
    required this.ref,
    required this.isPerfume,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authStateProvider).value;
    final email = user?.email ?? '';
    final name = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : (user?.email ?? l10n.vendorDefaultName);
    final badgeCount = ref.watch(vendorUnreadNotificationBadgeCountProvider);
    return SafeArea(
      child: VendorDashboardHeader(
        isPerfume: isPerfume,
        leading: IconButton(
          onPressed: onMenuTap,
          icon: const Icon(Icons.menu, color: AppColors.ink),
          tooltip: l10n.menu,
        ),
        userEmail: email,
        vendorName: name,
        unreadNotificationCount: badgeCount,
        onProfile: () => context.go('/vendor/profile'),
        onLogout: () async {
          try {
            await ref.read(authRepositoryProvider).signOut();
          } finally {
            // Ensure Firebase session is cleared even if repo signOut had partial failure.
            await fa.FirebaseAuth.instance.signOut();
            if (context.mounted) context.go('/');
          }
        },
        onNotificationsViewed: () {
          ref.read(vendorLastSeenPendingCountProvider.notifier).setLastSeen(
                ref.read(vendorPendingOmsCountProvider),
              );
        },
      ),
    );
  }
}

class _VendorSidebar extends StatelessWidget {
  final double width;
  final bool isPerfume;

  const _VendorSidebar({required this.width, required this.isPerfume});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final path = GoRouterState.of(context).uri.path;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200, width: 1)),
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
              path: '/dashboard',
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
              label: isPerfume ? 'Perfumes' : 'Bouquets',
              icon: Icons.local_florist_outlined,
              activeIcon: Icons.local_florist,
              path: '/vendor/bouquets',
              currentPath: path,
            ),
            _NavTile(
              label: isPerfume ? 'Add Perfume' : 'Add Bouquet',
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
    if (path == '/dashboard') {
      return currentPath == '/dashboard' ||
          currentPath == '/dashboard/' ||
          currentPath == '/vendor' ||
          currentPath == '/vendor/';
    }
    return currentPath == path || currentPath.startsWith('$path/');
  }

  @override
  Widget build(BuildContext context) {
    final active = _isActive;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active ? AppColors.rose.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          leading: Icon(
            active ? activeIcon : icon,
            size: 22,
            color: active ? AppColors.rosePrimary : AppColors.inkMuted,
          ),
          title: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: active ? AppColors.ink : AppColors.inkMuted,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
          selected: active,
          selectedTileColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          onTap: () => context.go(path),
        ),
      ),
    );
  }
}

/// Same nav content as sidebar, for use in drawer on mobile.
class _VendorDrawer extends StatelessWidget {
  final bool isPerfume;

  const _VendorDrawer({required this.isPerfume});

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;

    return Drawer(
      backgroundColor: Colors.white,
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
            Divider(height: 1, color: Colors.grey.shade200),
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
                        path: '/dashboard',
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
                        label: isPerfume ? 'Perfumes' : 'Bouquets',
                        icon: Icons.local_florist_outlined,
                        activeIcon: Icons.local_florist,
                        path: '/vendor/bouquets',
                        currentPath: path,
                      ),
                      _NavTile(
                        label: isPerfume ? 'Add Perfume' : 'Add Bouquet',
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
