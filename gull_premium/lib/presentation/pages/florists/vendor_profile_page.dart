import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/controllers.dart';
import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_format_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/cards/flower_card.dart';
import '../../widgets/common/app_cached_image.dart';
import '../../widgets/layout/app_scaffold.dart';

/// Public vendor profile: shows only products (bouquets) from this vendor.
/// Reached from [DesignersListPage] when tapping a vendor card.
class VendorProfilePage extends ConsumerWidget {
  final String vendorId;

  const VendorProfilePage({super.key, required this.vendorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final vendorAsync = ref.watch(vendorByIdProvider(vendorId));
    final bouquetsAsync = ref.watch(vendorProfileBouquetsProvider(vendorId));

    return AppScaffold(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: vendorAsync.when(
                loading: () => _ProfileHeader(
                  shopName: l10n.loadingBouquets,
                  logoUrl: null,
                  rating: null,
                ),
                error: (_, __) => _ProfileHeader(
                  shopName: l10n.vendorDefaultName,
                  logoUrl: null,
                  rating: null,
                ),
                data: (vendor) => _ProfileHeader(
                  shopName: vendor?.shopName ?? l10n.vendorDefaultName,
                  logoUrl: vendor?.logoUrl,
                  rating: vendor?.rating,
                ),
              ),
            ),
          ),
          bouquetsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    l10n.couldNotLoadBouquets,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.inkMuted),
                  ),
                ),
              ),
            ),
            data: (bouquets) {
              if (bouquets.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        l10n.noBouquetsYet,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.inkMuted),
                      ),
                    ),
                  ),
                );
              }
              final width = MediaQuery.sizeOf(context).width;
              final isMobile = width <= kMobileBreakpoint;
              final crossAxisCount = width < kMobileBreakpoint
                  ? 2
                  : width < kTabletBreakpoint
                      ? 3
                      : 4;
              final gap = width < kMobileBreakpoint ? 10.0 : 16.0;
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final gapTotal = (crossAxisCount - 1) * gap;
                    final childWidth =
                        (constraints.crossAxisExtent - gapTotal) / crossAxisCount;
                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: gap,
                        crossAxisSpacing: gap,
                        childAspectRatio: 0.65,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final b = bouquets[index];
                          final imageUrl = b.listingImageUrl.isNotEmpty
                              ? b.listingImageUrl
                              : 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80';
                          final isOnline = ref.watch(connectivityStatusProvider).value ?? true;
                          return SizedBox(
                            width: childWidth,
                            child: FlowerCard(
                              id: b.id,
                              name: b.name,
                              note: b.description,
                              price: formatPriceWithCurrency(
                                  b.priceIqd, l10n.currencyIqd),
                              imageUrl: imageUrl,
                              bouquetCode: b.bouquetCode.isNotEmpty
                                  ? b.bouquetCode
                                  : null,
                              isCompact: isMobile,
                              orderButtonEnabled: isOnline,
                            ),
                          );
                        },
                        childCount: bouquets.length,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String shopName;
  final String? logoUrl;
  final double? rating;

  const _ProfileHeader({
    required this.shopName,
    this.logoUrl,
    this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipOval(
          child: SizedBox(
            width: 88,
            height: 88,
            child: logoUrl != null && logoUrl!.isNotEmpty
                ? AppCachedImage(
                    imageUrl: logoUrl!,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    errorIcon: Icons.store_rounded,
                    errorIconSize: 44,
                  )
                : Container(
                    color: AppColors.background,
                    child: Icon(Icons.store_rounded, size: 44, color: AppColors.inkMuted),
                  ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shopName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.inkCharcoal,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (rating != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 20, color: AppColors.rose),
                    const SizedBox(width: 4),
                    Text(
                      rating!.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkMuted,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
