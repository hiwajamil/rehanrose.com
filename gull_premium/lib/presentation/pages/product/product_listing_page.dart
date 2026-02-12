import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/breakpoints.dart';
import '../../../core/constants/emotion_category.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_format_utils.dart';
import '../../../controllers/controllers.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/cards/flower_card.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/emotion_filter_cards.dart';
import '../../widgets/common/product_grid_shimmer.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';

/// Product listing page filtered by emotion category.
/// Reads [filterByCategory] from route query params (e.g. ?category=love).
/// Uses paginated fetch (10 per page) with infinite scroll.
class ProductListingPage extends ConsumerStatefulWidget {
  final String? filterByCategory;

  const ProductListingPage({super.key, this.filterByCategory});

  static String _resolveCategory(String? param) {
    if (param == null || param.isEmpty) return 'All';
    if (isValidEmotionCategoryId(param)) return param;
    return 'All';
  }

  @override
  ConsumerState<ProductListingPage> createState() => _ProductListingPageState();
}

class _ProductListingPageState extends ConsumerState<ProductListingPage> {
  late final ScrollController _scrollController;
  static const double _scrollLoadMoreThreshold = 200;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  @override
  void didUpdateWidget(ProductListingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (ProductListingPage._resolveCategory(oldWidget.filterByCategory) !=
        ProductListingPage._resolveCategory(widget.filterByCategory)) {
      _loadInitial();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _loadInitial() {
    final category = ProductListingPage._resolveCategory(widget.filterByCategory);
    final occasion = category == 'All' ? null : category;
    ref.read(paginatedProductsProvider.notifier).loadInitial(occasion);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _scrollLoadMoreThreshold) {
      ref.read(paginatedProductsProvider.notifier).fetchMoreProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = ProductListingPage._resolveCategory(widget.filterByCategory);
    final paginated = ref.watch(paginatedProductsProvider);
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    final l10n = AppLocalizations.of(context)!;

    return AppScaffold(
      scrollController: _scrollController,
      child: SectionContainer(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 48, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EmotionFilterCards(
              selectedOccasion: category,
              onSelected: (occasion) {
                ref.read(analyticsServiceProvider).logSelectContent(
                      contentType: 'category',
                      itemId: occasion,
                      itemName: occasion,
                    );
                final newPath = occasion == 'All'
                    ? '/products'
                    : '/products?category=$occasion';
                context.go(newPath);
              },
            ),
            SizedBox(height: isMobile ? 24 : 40),
            if (paginated.isLoading && paginated.products.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: ProductGridShimmerGrid(itemCount: 6),
              )
            else if (paginated.error != null && paginated.products.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.couldNotLoadBouquets,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _loadInitial,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(l10n.retry),
                  ),
                ],
              )
            else if (paginated.products.isEmpty)
              SizedBox(
                height: 280,
                child: EmptyStateWidget(
                  message: category == 'All'
                      ? l10n.noBouquetsYet
                      : l10n.noBouquetsForFeeling,
                  icon: Icons.local_florist_outlined,
                  buttonText: category == 'All' ? null : l10n.browseAllBouquets,
                  onPressed: category == 'All'
                      ? null
                      : () => context.go('/products'),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = MediaQuery.sizeOf(context).width;
                      final crossAxisCount = width < kMobileBreakpoint
                          ? 2
                          : width < kTabletBreakpoint
                              ? 3
                              : 4;
                      final gap = width < kMobileBreakpoint
                          ? (width < 380 ? 8.0 : 10.0)
                          : 16.0;
                      final gapTotal = (crossAxisCount - 1) * gap;
                      final childWidth =
                          (constraints.maxWidth - gapTotal) / crossAxisCount;
                      final isOnline = ref.watch(connectivityStatusProvider).value ?? true;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: paginated.products.map((b) {
                          final imageUrl = b.listingImageUrl.isNotEmpty
                              ? b.listingImageUrl
                              : 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80';
                          return SizedBox(
                            width: childWidth,
                            child: FlowerCard(
                              id: b.id,
                              name: b.name,
                              note: b.description,
                              price: formatPriceWithCurrency(b.priceIqd, l10n.currencyIqd),
                              imageUrl: imageUrl,
                              bouquetCode: b.bouquetCode.isNotEmpty ? b.bouquetCode : null,
                              isCompact: isMobile,
                              orderButtonEnabled: isOnline,
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  if (paginated.isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (!paginated.hasMore)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          l10n.reachedEndOfList,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.inkMuted,
                              ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
