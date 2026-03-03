import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../controllers/controllers.dart';
import '../../../l10n/app_localizations.dart';

/// Dedicated admin shell: no customer nav. Sidebar + main content with metrics.
/// When user is not admin, shows only [child] (e.g. sign-in or not-authorized).
class AdminShellLayout extends ConsumerWidget {
  const AdminShellLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    return authAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(body: child),
      data: (user) {
        if (user == null) return Scaffold(body: child);
        final isAdminAsync = ref.watch(isAdminForUidProvider(user.uid));
        return isAdminAsync.when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => Scaffold(body: child),
          data: (isAdmin) {
            if (!isAdmin) return Scaffold(body: child);
            return Scaffold(
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AdminSidebar(
                    currentPath: GoRouterState.of(context).uri.path,
                    onSignOut: () =>
                        ref.read(authRepositoryProvider).signOut(),
                  ),
                  Expanded(
                    child: Container(
                      color: const Color(0xFFF4F5F7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _AdminMetricsRow(),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 20,
                              ),
                              child: child,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.currentPath,
    required this.onSignOut,
  });

  final String currentPath;
  final VoidCallback onSignOut;

  static const double _width = 250;

  bool _isSelected(String path) {
    if (path == '/admin') return currentPath == '/admin' || currentPath == '/admin/';
    return currentPath.startsWith(path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: _width,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          const SizedBox(height: 32),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              children: [
                _NavTile(
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard_rounded,
                  label: l10n.adminAnalytics,
                  selected: _isSelected('/admin/analytics'),
                  onTap: () => context.go('/admin/analytics'),
                ),
                _NavTile(
                  icon: Icons.pending_actions_outlined,
                  selectedIcon: Icons.pending_actions_rounded,
                  label: l10n.adminPendingApplications,
                  selected: currentPath == '/admin' || currentPath == '/admin/',
                  onTap: () => context.go('/admin'),
                ),
                _NavTile(
                  icon: Icons.eco_outlined,
                  selectedIcon: Icons.eco_rounded,
                  label: l10n.adminBouquetApproval,
                  selected: _isSelected('/admin/approvals'),
                  onTap: () => context.go('/admin/approvals'),
                ),
                _NavTile(
                  icon: Icons.add_circle_outline,
                  selectedIcon: Icons.add_circle_rounded,
                  label: l10n.adminManageAddOns,
                  selected: _isSelected('/admin/add-ons'),
                  onTap: () => context.push('/admin/add-ons'),
                ),
                _NavTile(
                  icon: Icons.shopping_bag_outlined,
                  selectedIcon: Icons.shopping_bag_rounded,
                  label: l10n.adminOrders,
                  selected: _isSelected('/admin/orders'),
                  onTap: () => context.go('/admin/orders'),
                ),
                _NavTile(
                  icon: Icons.people_outline,
                  selectedIcon: Icons.people_rounded,
                  label: l10n.adminMembersCrm,
                  selected: _isSelected('/admin/members'),
                  onTap: () => context.push('/admin/members'),
                ),
              ],
            ),
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
              onTap: onSignOut,
            ),
          ),
        ],
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        selected: selected,
        selectedTileColor: AppColors.rosePrimary.withValues(alpha: 0.12),
        onTap: onTap,
      ),
    );
  }
}

class _AdminMetricsRow extends StatefulWidget {
  const _AdminMetricsRow();

  @override
  State<_AdminMetricsRow> createState() => _AdminMetricsRowState();
}

class _AdminMetricsRowState extends State<_AdminMetricsRow> {
  late final Stream<int> _membersStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _vendorsStream;

  @override
  void initState() {
    super.initState();
    _membersStream = ProviderScope.containerOf(context)
        .read(membersRepositoryProvider)
        .watchCustomerCount();
    _vendorsStream = ProviderScope.containerOf(context)
        .read(authRepositoryProvider)
        .watchVendorApplications();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: StreamBuilder<int>(
              stream: _membersStream,
              builder: (context, snapshot) {
                final isLoading = snapshot.connectionState == ConnectionState.waiting;
                final value = snapshot.hasData ? '${snapshot.data}' : '—';
                return _MetricCard(
                  icon: Icons.people_outline,
                  title: l10n.adminTotalMembers,
                  value: value,
                  isLoading: isLoading,
                  onTap: () => context.push('/admin/members'),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _vendorsStream,
              builder: (context, snapshot) {
                final isLoading = snapshot.connectionState == ConnectionState.waiting;
                final value = snapshot.hasData
                    ? '${snapshot.data!.docs.length}'
                    : '—';
                return _MetricCard(
                  icon: Icons.pending_actions_outlined,
                  title: l10n.adminPendingApplications,
                  value: value,
                  isLoading: isLoading,
                  onTap: () => context.go('/admin'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.isLoading,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.rosePrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: AppColors.rosePrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkMuted,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    // Fixed-height placeholder to prevent card height jump during loading
                    SizedBox(
                      height: 28,
                      child: isLoading
                          ? Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.rose,
                                ),
                              ),
                            )
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                value,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.rosePrimary,
                                    ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: AppColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
