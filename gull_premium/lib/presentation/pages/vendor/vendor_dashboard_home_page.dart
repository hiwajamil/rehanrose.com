import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../controllers/controllers.dart';
import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/flower_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/layout/section_container.dart';

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

/// Dashboard home: mini analytics cards + motivation text + alerts.
/// Shown when authenticated at /vendor. Uses Motivational Fishbowl strategy.
class VendorDashboardHomePage extends ConsumerWidget {
  const VendorDashboardHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    final horizontalPadding = isMobile ? 16.0 : 32.0;
    final bouquetsAsync = ref.watch(vendorBouquetsStreamProvider);
    final storeCategory = ref.watch(_vendorStoreCategoryProvider).maybeWhen(
          data: (value) => value,
          orElse: () => 'flowers',
        );
    final bool isPerfume = storeCategory == 'perfumes';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SectionContainer(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.vendorDashboardTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            bouquetsAsync.when(
              data: (bouquets) =>
                  _MiniAnalyticsSection(bouquets: bouquets, isPerfume: isPerfume),
              loading: () => _MiniAnalyticsSection(bouquets: [], isPerfume: isPerfume),
              error: (_, __) => _MiniAnalyticsSection(bouquets: [], isPerfume: isPerfume),
            ),
            const SizedBox(height: 32),
            _AlertsSection(),
          ],
        ),
      ),
    );
  }
}

class _MiniAnalyticsSection extends StatelessWidget {
  final List<FlowerModel> bouquets;
  final bool isPerfume;

  const _MiniAnalyticsSection({required this.bouquets, required this.isPerfume});

  int get _activeCount =>
      bouquets.where((b) => b.isApproved).length;

  int get _pendingCount =>
      bouquets.where((b) => b.isPendingApproval).length;

  int get _totalViewsClicks =>
      bouquets.fold<int>(0, (acc, b) => acc + b.viewCount + b.orderCount);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= kMobileBreakpoint;
        final cardWidth = isMobile
            ? (constraints.maxWidth - 16) / 3
            : (constraints.maxWidth - 32) / 3;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MiniAnalyticsCard(
                  width: cardWidth.clamp(120.0, 220.0),
                  title: isPerfume ? l10n.active_perfumes : 'Active Bouquets',
                  value: '$_activeCount',
                  icon: Icons.local_florist_outlined,
                ),
                _MiniAnalyticsCard(
                  width: cardWidth.clamp(120.0, 220.0),
                  title: l10n.vendorPendingApprovals,
                  value: '$_pendingCount',
                  icon: Icons.schedule_outlined,
                ),
                _MiniAnalyticsCard(
                  width: cardWidth.clamp(120.0, 220.0),
                  title: l10n.vendorTotalViewsClicks,
                  value: '$_totalViewsClicks',
                  icon: Icons.touch_app_outlined,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              isPerfume
                  ? 'Add more beautiful perfumes to attract more customers!'
                  : 'Add more beautiful bouquets to attract more customers!',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
            ),
          ],
        );
      },
    );
  }
}

class _MiniAnalyticsCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final IconData icon;

  const _MiniAnalyticsCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.rose.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.rosePrimary, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _AlertsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.vendorAlerts,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 20),
          _EmptyStateInline(
            icon: Icons.check_circle_outline,
            message: l10n.vendorNoOrdersNeedingConfirmation,
          ),
          const SizedBox(height: 12),
          _EmptyStateInline(
            icon: Icons.notifications_none,
            message: l10n.vendorNoNewAdminNotices,
          ),
        ],
      ),
    );
  }
}

/// Inline empty-state row for alerts (icon + gentle text).
class _EmptyStateInline extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyStateInline({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.inkMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                  height: 1.4,
                ),
          ),
        ),
      ],
    );
  }
}
