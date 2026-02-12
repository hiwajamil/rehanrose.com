import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../controllers/controllers.dart';
import '../../../data/models/flower_model.dart';
import '../../widgets/common/app_cached_image.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';

class AnalyticsOverviewPage extends ConsumerWidget {
  const AnalyticsOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    return AppScaffold(
      child: SectionContainer(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: authAsync.when(
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
        ),
      ),
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

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Analytics Overview',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Spacer(),
                  PrimaryButton(
                    label: 'Refresh',
                    onPressed: () =>
                        ref.invalidate(adminAnalyticsBouquetsProvider),
                    variant: PrimaryButtonVariant.outline,
                  ),
                  const SizedBox(width: 12),
                  PrimaryButton(
                    label: 'Back to Admin',
                    onPressed: () => context.go('/admin'),
                    variant: PrimaryButtonVariant.outline,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Product Views',
                      value: totalViews.toString(),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _SummaryCard(
                      title: 'WhatsApp Clicks',
                      value: totalClicks.toString(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'Top Performing Products',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              _ProductList(
                products: top10Orders,
                subtitleBuilder: (p) => 'Ordered: ${p.orderCount} times',
              ),
              const SizedBox(height: 32),
              Text(
                'Most Viewed Products',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
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
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
            ),
          ],
        ),
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: products.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final p = products[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
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
    );
  }
}
