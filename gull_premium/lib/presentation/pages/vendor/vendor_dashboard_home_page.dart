import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../controllers/vendor_controller.dart';
import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/flower_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/layout/section_container.dart';

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
              data: (bouquets) => _MiniAnalyticsSection(bouquets: bouquets),
              loading: () => _MiniAnalyticsSection(bouquets: []),
              error: (_, __) => _MiniAnalyticsSection(bouquets: []),
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

  const _MiniAnalyticsSection({required this.bouquets});

  int get _activeCount =>
      bouquets.where((b) => b.isApproved).length;

  int get _pendingCount =>
      bouquets.where((b) => b.isPendingApproval).length;

  int get _totalViewsClicks =>
      bouquets.fold<int>(0, (sum, b) => sum + b.viewCount + b.orderCount);

  String _motivationText(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _activeCount > 5
        ? l10n.vendorMotivationGreatJob
        : l10n.vendorMotivationMoreBouquets;
  }

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
                  title: l10n.vendorActiveBouquets,
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
              _motivationText(context),
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
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.rose, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.vendorAlerts,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.vendorNoOrdersNeedingConfirmation,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.vendorNoNewAdminNotices,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
        ],
      ),
    );
  }
}
