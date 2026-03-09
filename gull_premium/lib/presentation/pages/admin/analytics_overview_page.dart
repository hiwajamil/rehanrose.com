import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../controllers/controllers.dart';
import '../../../data/models/flower_model.dart';
import '../../widgets/common/app_cached_image.dart';
import '../../widgets/common/primary_button.dart';

class AnalyticsOverviewPage extends ConsumerWidget {
  const AnalyticsOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    return authAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildAccessDenied(context),
      data: (user) {
        if (user == null) return _buildAccessDenied(context);
        return FutureBuilder<bool>(
          future: ref.read(authRepositoryProvider).isAdmin(user.uid),
          builder: (context, adminSnapshot) {
            if (adminSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (adminSnapshot.data != true) return _buildAccessDenied(context);
            return _buildContent(context, ref);
          },
        );
      },
    );
  }

  Widget _buildAccessDenied(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Access restricted',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Back to Admin',
            onPressed: () => context.go('/admin'),
            variant: PrimaryButtonVariant.outline,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(adminAnalyticsBouquetsProvider);

    return analyticsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Unable to load analytics.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Retry',
              onPressed: () => ref.invalidate(adminAnalyticsBouquetsProvider),
              variant: PrimaryButtonVariant.outline,
            ),
          ],
        ),
      ),
      data: (bouquets) {
        final totalViews = bouquets.fold<int>(0, (s, b) => s + b.viewCount);
        final totalClicks = bouquets.fold<int>(0, (s, b) => s + b.orderCount);
        final topByOrders = List<FlowerModel>.from(bouquets)
          ..sort((a, b) => b.orderCount.compareTo(a.orderCount));
        final topByViews = List<FlowerModel>.from(bouquets)
          ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
        final top10Orders = topByOrders.take(10).toList();
        final top10Views = topByViews.take(10).toList();

        final isMobile = MediaQuery.sizeOf(context).width < kAdminShellDrawerBreakpoint;
        final spacing = isMobile ? 16.0 : 24.0;
        final sectionSpacing = isMobile ? 24.0 : 32.0;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Analytics Overview',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                        ),
                        SizedBox(height: spacing),
                        PrimaryButton(
                          label: 'Refresh',
                          onPressed: () =>
                              ref.invalidate(adminAnalyticsBouquetsProvider),
                          variant: PrimaryButtonVariant.outline,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Text(
                          'Analytics Overview',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                        ),
                        const Spacer(),
                        PrimaryButton(
                          label: 'Refresh',
                          onPressed: () =>
                              ref.invalidate(adminAnalyticsBouquetsProvider),
                          variant: PrimaryButtonVariant.outline,
                        ),
                      ],
                    ),
              SizedBox(height: spacing),
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SummaryCard(
                          icon: Icons.visibility_outlined,
                          iconTint: const Color(0xFF2E7D32),
                          title: 'Product Views',
                          value: totalViews.toString(),
                        ),
                        SizedBox(height: spacing),
                        _SummaryCard(
                          icon: Icons.chat_outlined,
                          iconTint: AppColors.rosePrimary,
                          title: 'WhatsApp Clicks',
                          value: totalClicks.toString(),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            icon: Icons.visibility_outlined,
                            iconTint: const Color(0xFF2E7D32),
                            title: 'Product Views',
                            value: totalViews.toString(),
                          ),
                        ),
                        SizedBox(width: spacing),
                        Expanded(
                          child: _SummaryCard(
                            icon: Icons.chat_outlined,
                            iconTint: AppColors.rosePrimary,
                            title: 'WhatsApp Clicks',
                            value: totalClicks.toString(),
                          ),
                        ),
                      ],
                    ),
              SizedBox(height: sectionSpacing),
              Text(
                'Top Performing Products',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: spacing / 2),
              _ProductList(
                products: top10Orders,
                subtitleBuilder: (p) => 'Ordered: ${p.orderCount} times',
              ),
              SizedBox(height: sectionSpacing),
              Text(
                'Most Viewed Products',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: spacing / 2),
              _ProductList(
                products: top10Views,
                subtitleBuilder: (p) => 'Viewed: ${p.viewCount} times',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.iconTint,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color iconTint;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < kAdminShellDrawerBreakpoint;
    final padding = isMobile ? 16.0 : 24.0;
    return Container(
      padding: EdgeInsets.all(padding),
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: iconTint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 28, color: iconTint),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductList extends StatelessWidget {
  const _ProductList({
    required this.products,
    required this.subtitleBuilder,
  });

  final List<FlowerModel> products;
  final String Function(FlowerModel) subtitleBuilder;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No products yet.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.inkMuted),
        ),
      );
    }
    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: products.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final p = products[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: p.listingImageUrl.isEmpty
                    ? Icon(Icons.local_florist, color: AppColors.inkMuted)
                    : AppCachedImage(
                        imageUrl: p.listingImageUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            title: Text(
              p.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(subtitleBuilder(p)),
          );
        },
      ),
      ),
    );
  }
}
