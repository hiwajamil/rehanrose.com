import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../controllers/controllers.dart';

/// Dedicated admin shell: no customer nav. Sidebar + main content with metrics.
/// When user is not admin, shows only [child] (e.g. sign-in or not-authorized).
/// On width < [kAdminShellDrawerBreakpoint], sidebar becomes a drawer with hamburger AppBar.
class AdminShellLayout extends ConsumerWidget {
  const AdminShellLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    return authAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => Scaffold(body: child),
      data: (user) {
        if (user == null) return Scaffold(body: child);
        final isAdminAsync = ref.watch(isAdminForUidProvider(user.uid));
        return isAdminAsync.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, __) => Scaffold(body: child),
          data: (isAdmin) {
            if (!isAdmin) return Scaffold(body: child);
            final unread = ref
                .watch(inAppUnreadNotificationsCountProvider(user.uid))
                .maybeWhen(
                  data: (n) => n,
                  orElse: () => 0,
                );
            return _ResponsiveAdminShell(
              currentPath: GoRouterState.of(context).uri.path,
              notificationUnreadCount: unread,
              onSignOut: () async {
                try {
                  await ref.read(authRepositoryProvider).signOut();
                } finally {
                  // Ensure Firebase session is cleared even if repo signOut had partial failure.
                  await fa.FirebaseAuth.instance.signOut();
                }
                if (context.mounted) context.go('/');
              },
              child: child,
            );
          },
        );
      },
    );
  }
}

/// Responsive shell: permanent sidebar on desktop/tablet, AppBar + Drawer on mobile.
class _ResponsiveAdminShell extends StatefulWidget {
  const _ResponsiveAdminShell({
    required this.currentPath,
    required this.notificationUnreadCount,
    required this.onSignOut,
    required this.child,
  });

  final String currentPath;
  final int notificationUnreadCount;
  final Future<void> Function() onSignOut;
  final Widget child;

  @override
  State<_ResponsiveAdminShell> createState() => _ResponsiveAdminShellState();
}

class _ResponsiveAdminShellState extends State<_ResponsiveAdminShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useDrawer = width < kAdminShellDrawerBreakpoint;
    final paddingH = useDrawer ? 16.0 : 24.0;
    final paddingV = useDrawer ? 12.0 : 20.0;

    if (useDrawer) {
      final l10n = AppLocalizations.of(context)!;
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            tooltip: l10n.adminSuperAdminDashboard,
          ),
          title: Text(
            l10n.appTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.inkCharcoal,
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.inkCharcoal,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          actions: [
            _AdminNotificationBell(
              unreadCount: widget.notificationUnreadCount,
              onPressed: () {
                context.push('/admin/notifications');
              },
            ),
          ],
        ),
        drawer: Drawer(
          child: _AdminSidebarContent(
            currentPath: widget.currentPath,
            notificationUnreadCount: widget.notificationUnreadCount,
            onSignOut: widget.onSignOut,
            onNavigate: () => Navigator.of(context).pop(),
          ),
        ),
        body: Container(
          color: const Color(0xFFF4F5F7),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: paddingH,
              vertical: paddingV,
            ),
            child: widget.child,
          ),
        ),
      );
    }

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AdminSidebarContent(
            currentPath: widget.currentPath,
            notificationUnreadCount: widget.notificationUnreadCount,
            onSignOut: widget.onSignOut,
            onNavigate: null,
            width: _AdminSidebarContent.sidebarWidth,
          ),
          Expanded(
            child: Container(
              color: const Color(0xFFF4F5F7),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: paddingH,
                  vertical: paddingV,
                ),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminNotificationBell extends StatelessWidget {
  const _AdminNotificationBell({
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final icon = IconButton(
      tooltip: 'Notifications',
      onPressed: onPressed,
      icon: const Icon(Icons.notifications_none_rounded),
    );
    if (unreadCount <= 0) return icon;
    return Badge(
      label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
      child: icon,
    );
  }
}

class _AdminSidebarContent extends StatelessWidget {
  const _AdminSidebarContent({
    required this.currentPath,
    required this.notificationUnreadCount,
    required this.onSignOut,
    this.onNavigate,
    this.width,
  });

  final String currentPath;
  final int notificationUnreadCount;
  final Future<void> Function() onSignOut;

  /// Called after navigation (e.g. to close drawer). Null when used as permanent sidebar.
  final VoidCallback? onNavigate;

  /// When non-null, wrap in a fixed-width container for permanent sidebar.
  final double? width;

  static const double sidebarWidth = 250;

  bool _isSelected(String path) {
    if (path == '/admin') {
      return currentPath == '/admin' || currentPath == '/admin/';
    }
    return currentPath.startsWith(path);
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.appTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkCharcoal,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.rosePrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.rosePrimary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        l10n.adminSuperAdminDashboard,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.rosePrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _AdminNotificationBell(
                unreadCount: notificationUnreadCount,
                onPressed: () {
                  context.push('/admin/notifications');
                  onNavigate?.call();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            children: [
              const _SidebarSectionHeader(label: 'OVERVIEW'),
              _NavTile(
                icon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard_rounded,
                label: l10n.adminAnalytics,
                selected: _isSelected('/admin/analytics'),
                onTap: () {
                  context.go('/admin/analytics');
                  onNavigate?.call();
                },
              ),
              _NavTile(
                icon: Icons.attach_money_outlined,
                selectedIcon: Icons.attach_money_rounded,
                label: 'Revenue Analytics',
                selected: _isSelected('/admin/revenue-analytics'),
                onTap: () {
                  context.go('/admin/revenue-analytics');
                  onNavigate?.call();
                },
              ),
              const _SidebarSectionHeader(label: 'APPROVALS'),
              _NavTile(
                icon: Icons.pending_actions_outlined,
                selectedIcon: Icons.pending_actions_rounded,
                label: l10n.adminPendingApplications,
                selected: currentPath == '/admin' || currentPath == '/admin/',
                onTap: () {
                  context.go('/admin');
                  onNavigate?.call();
                },
              ),
              _NavTile(
                icon: Icons.eco_outlined,
                selectedIcon: Icons.eco_rounded,
                label: l10n.adminBouquetApproval,
                selected: _isSelected('/admin/approvals'),
                onTap: () {
                  context.go('/admin/approvals');
                  onNavigate?.call();
                },
              ),
              _NavTile(
                icon: Icons.auto_awesome_outlined,
                selectedIcon: Icons.auto_awesome,
                label: l10n.perfume_approval,
                selected: _isSelected('/admin/perfume-approvals'),
                onTap: () {
                  context.go('/admin/perfume-approvals');
                  onNavigate?.call();
                },
              ),
              const _SidebarSectionHeader(label: 'ORDERS'),
              _NavTile(
                icon: Icons.request_quote_outlined,
                selectedIcon: Icons.request_quote_rounded,
                label: 'Custom Requests',
                selected: _isSelected('/admin/custom-requests'),
                onTap: () {
                  context.go('/admin/custom-requests');
                  onNavigate?.call();
                },
              ),
              _NavTile(
                icon: Icons.shopping_bag_outlined,
                selectedIcon: Icons.shopping_bag_rounded,
                label: 'Bouquet Orders',
                selected: _isSelected('/admin/bouquet-orders'),
                onTap: () {
                  context.go('/admin/bouquet-orders');
                  onNavigate?.call();
                },
              ),
              _NavTile(
                icon: Icons.local_drink_outlined,
                selectedIcon: Icons.local_drink,
                label: 'Perfume Orders',
                selected: _isSelected('/admin/perfume-orders'),
                onTap: () {
                  context.go('/admin/perfume-orders');
                  onNavigate?.call();
                },
              ),
              const _SidebarSectionHeader(label: 'MANAGEMENT'),
              _NavTile(
                icon: Icons.people_outline,
                selectedIcon: Icons.people_rounded,
                label: l10n.adminMembersCrm,
                selected: _isSelected('/admin/members'),
                onTap: () {
                  context.push('/admin/members');
                  onNavigate?.call();
                },
              ),
              _NavTile(
                icon: Icons.store_outlined,
                selectedIcon: Icons.store_rounded,
                label: l10n.adminVendorsManagement,
                selected: _isSelected('/admin/vendors'),
                onTap: () {
                  context.push('/admin/vendors');
                  onNavigate?.call();
                },
              ),
              _NavTile(
                icon: Icons.local_shipping_outlined,
                selectedIcon: Icons.local_shipping_rounded,
                label: 'Delivery Fleet',
                selected: _isSelected('/admin/drivers'),
                onTap: () {
                  context.push('/admin/drivers');
                  onNavigate?.call();
                },
              ),
              const _SidebarSectionHeader(label: 'MARKETING & EXTRAS'),
              _NavTile(
                icon: Icons.add_circle_outline,
                selectedIcon: Icons.add_circle_rounded,
                label: l10n.adminManageAddOns,
                selected: _isSelected('/admin/add-ons'),
                onTap: () {
                  context.push('/admin/add-ons');
                  onNavigate?.call();
                },
              ),
              _NavTile(
                icon: Icons.campaign_outlined,
                selectedIcon: Icons.campaign,
                label: 'Advertisements',
                selected: _isSelected('/admin/advertisements'),
                onTap: () {
                  context.push('/admin/advertisements');
                  onNavigate?.call();
                },
              ),
              _NavTile(
                icon: Icons.local_offer_outlined,
                selectedIcon: Icons.local_offer,
                label: 'Promo Codes',
                selected: _isSelected('/admin/coupons'),
                onTap: () {
                  context.push('/admin/coupons');
                  onNavigate?.call();
                },
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Divider(height: 1),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          child: ListTile(
            leading: Icon(
              Icons.logout_rounded,
              size: 22,
              color: AppColors.inkMuted,
            ),
            title: Text(
              l10n.adminSignOut,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.inkMuted,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onTap: () async {
              await onSignOut();
              onNavigate?.call();
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (width != null) {
      return Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: Colors.grey[200]!, width: 1)),
        ),
        child: _buildContent(context),
      );
    }
    return Container(color: Colors.white, child: _buildContent(context));
  }
}

class _SidebarSectionHeader extends StatelessWidget {
  const _SidebarSectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.inkMuted.withValues(alpha: 0.75),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(
          selected ? selectedIcon : icon,
          size: 22,
          color: selected ? AppColors.rosePrimary : AppColors.inkMuted,
        ),
        title: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.rosePrimary : AppColors.ink,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: selected,
        selectedTileColor: AppColors.rosePrimary.withValues(alpha: 0.12),
        onTap: onTap,
      ),
    );
  }
}
