import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seo/seo.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/breakpoints.dart';
import '../../../core/constants/emotion_category.dart';
import '../../../core/utils/emotion_category_l10n.dart';
import '../../../core/utils/price_format_utils.dart';
import '../../../core/utils/seo_meta_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../controllers/controllers.dart';
import '../../../data/models/flower_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/cards/flower_card.dart';
import '../../widgets/common/emotion_dropdown.dart';
import '../../widgets/common/product_grid_shimmer.dart';
import '../../widgets/common/emotion_filter_cards.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';

class LandingPage extends ConsumerStatefulWidget {
  const LandingPage({super.key, this.saleOnly = false});

  /// When true, only products on sale (isOnSale or discountPrice set) are shown.
  final bool saleOnly;

  @override
  ConsumerState<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends ConsumerState<LandingPage> {
  final _productsSectionKey = GlobalKey();
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    updatePageMeta(
      title: kAppName,
      description: 'Handcrafted flower bouquets for every feeling. Same-day delivery, trusted local florists.',
      keywords: 'flowers, bouquets, Rehan Rose, florist, flower delivery',
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToProducts() {
    final ctx = _productsSectionKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final saleOnly = widget.saleOnly;
    return AppScaffold(
      scrollController: _scrollController,
      child: Column(
        children: [
          if (!saleOnly) const _HeroSection(),
          if (!saleOnly) _CategoryCardsSection(onCategorySelected: _scrollToProducts),
          if (!saleOnly) const SizedBox(height: 32),
          if (!saleOnly) _EmotionDropdownBlock(onSelection: _scrollToProducts),
          if (!saleOnly) const SizedBox(height: 24),
          if (!saleOnly) _TransitionSection(onExplore: _scrollToProducts),
          if (saleOnly) const SizedBox(height: 32),
          _ProductsSection(
            key: _productsSectionKey,
            scrollController: _scrollController,
            onScrollToProducts: _scrollToProducts,
            saleOnly: saleOnly,
          ),
          const _TrustSection(),
        ],
      ),
    );
  }
}

/// Full-width hero with video background, emotion-driven copy — Blue Ocean strategy.
class _HeroSection extends StatefulWidget {
  const _HeroSection();

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection> {
  late VideoPlayerController _videoController;

  static const _videoAsset = 'assets/main_page_01.mp4';

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset(_videoAsset)
      ..initialize().then((_) {
        if (mounted) {
          _videoController
            ..setLooping(true)
            ..setVolume(0)
            ..play();
          setState(() {});
        }
      }).catchError((_) {
        // Fallback if asset path differs or video fails
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    final headlineSize = isMobile ? 40.0 : 80.0;
    final locale = Localizations.localeOf(context);
    final isRTL = locale.languageCode == 'ar' || locale.languageCode == 'ku';
    final headlineFont = isRTL ? GoogleFonts.notoNaskhArabic : GoogleFonts.cormorantGaramond;
    final bodyFont = isRTL ? GoogleFonts.notoNaskhArabic : GoogleFonts.manrope;

    return SizedBox(
      width: double.infinity,
      height: isMobile ? 520 : 620,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_videoController.value.isInitialized)
            ClipRRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            )
          else
            Container(color: AppColors.background),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.ink.withValues(alpha: 0.4),
                  AppColors.ink.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: isMobile ? 20 : 48,
              end: isMobile ? 20 : 48,
              top: isMobile ? 48 : 72,
              bottom: isMobile ? 48 : 72,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Seo.text(
                  text: '${l10n.heroTitlePart1} ${l10n.heroTitlePart2}',
                  style: TextTagStyle.h1,
                  child: RichText(
                    textAlign: TextAlign.center,
                    textDirection: Directionality.of(context),
                    text: TextSpan(
                      style: headlineFont(
                        fontSize: headlineSize,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                        color: Colors.white,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            color: AppColors.ink.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 2),
                          ),
                          Shadow(
                            color: AppColors.ink.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      children: [
                        TextSpan(text: l10n.heroTitlePart1),
                        TextSpan(
                          text: l10n.heroTitlePart2,
                          style: headlineFont(
                            fontSize: headlineSize,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                            color: AppColors.rosePrimary,
                            height: 1.2,
                            shadows: [
                              Shadow(
                                color: AppColors.ink.withValues(alpha: 0.5),
                                blurRadius: 20,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: isMobile ? 20 : 28),
                Seo.text(
                  text: l10n.heroSubtitle,
                  child: Text(
                    l10n.heroSubtitle,
                    textAlign: TextAlign.center,
                    textDirection: Directionality.of(context),
                    style: bodyFont(
                      fontSize: isMobile ? 16 : 20,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.94),
                      height: 1.5,
                      shadows: [
                        Shadow(
                          color: AppColors.ink.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Seo.text(
                  text: l10n.heroTagline,
                  child: Text(
                    l10n.heroTagline,
                    textDirection: Directionality.of(context),
                    style: bodyFont(
                      fontSize: isMobile ? 13 : 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.82),
                      fontStyle: FontStyle.italic,
                      shadows: [
                        Shadow(
                          color: AppColors.ink.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
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

/// Category cards section: "What do you want to say today?" with emotion category grid.
/// RTL-aware. Clicking a card filters products by emotionCategoryId and scrolls to products.
class _CategoryCardsSection extends ConsumerWidget {
  final VoidCallback? onCategorySelected;

  const _CategoryCardsSection({this.onCategorySelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    // More columns = smaller cells (~half area); text/icon sizes unchanged
    final crossAxisCount = isMobile ? 3 : 6;
    final locale = Localizations.localeOf(context);
    final isRTL = locale.languageCode == 'ar' || locale.languageCode == 'ku';

    return SectionContainer(
      padding: EdgeInsetsDirectional.only(
        start: isMobile ? 20 : 48,
        end: isMobile ? 20 : 48,
        top: 32,
        bottom: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Seo.text(
            text: l10n.home_question,
            style: TextTagStyle.h2,
            child: Text(
              l10n.home_question,
              textAlign: TextAlign.center,
              textDirection: Directionality.of(context),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
            ),
          ),
          const SizedBox(height: 24),
          Directionality(
            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.0,
              children: kEmotionCategories.map((category) {
                return _CategoryCard(
                  category: category,
                  title: localizedEmotionCategoryTitle(l10n, category.titleKey),
                  onTap: () {
                    ref.read(selectedOccasionProvider.notifier).setOccasion(category.id);
                    onCategorySelected?.call();
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final EmotionCategory category;
  final String title;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.title,
    required this.onTap,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = _hovered
        ? widget.category.color.withValues(alpha: 0.9)
        : widget.category.color;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsetsDirectional.all(10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.5),
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: AppColors.shadow.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.category.icon,
                size: 40,
                color: AppColors.rose,
              ),
              const SizedBox(height: 6),
              Seo.text(
                text: widget.title,
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  textDirection: Directionality.of(context),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Emotion dropdown block below hero.
class _EmotionDropdownBlock extends ConsumerWidget {
  final VoidCallback? onSelection;

  const _EmotionDropdownBlock({this.onSelection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedOccasion = ref.watch(selectedOccasionProvider);
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;

    return Container(
      margin: EdgeInsetsDirectional.symmetric(horizontal: isMobile ? 16 : 48),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: EmotionDropdown(
        selectedEmotionValue: selectedOccasion == 'All' ? null : selectedOccasion,
        onChanged: (value) {
          if (value != null) {
            ref.read(analyticsServiceProvider).logSearch(value);
            ref.read(selectedOccasionProvider.notifier).setOccasion(value);
            onSelection?.call();
          }
        },
      ),
    );
  }
}

/// Transition section: bridges hero into products.
class _TransitionSection extends StatelessWidget {
  final VoidCallback onExplore;

  const _TransitionSection({required this.onExplore});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SectionContainer(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 48, vertical: 48),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Seo.text(
            text: l10n.flowersForEveryFeeling,
            style: TextTagStyle.h2,
            child: Text(
              l10n.flowersForEveryFeeling,
              textAlign: TextAlign.center,
              textDirection: Directionality.of(context),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 12),
          Seo.text(
            text: l10n.eachBouquetCopy,
            child: Text(
              l10n.eachBouquetCopy,
              textAlign: TextAlign.center,
              textDirection: Directionality.of(context),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

/// Products section: emotion filter + bouquet grid. Uses paginated fetch when !saleOnly.
class _ProductsSection extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  final VoidCallback? onScrollToProducts;
  final bool saleOnly;

  const _ProductsSection({
    super.key,
    this.scrollController,
    this.onScrollToProducts,
    this.saleOnly = false,
  });

  @override
  ConsumerState<_ProductsSection> createState() => _ProductsSectionState();
}

class _ProductsSectionState extends ConsumerState<_ProductsSection> {
  static const double _scrollLoadMoreThreshold = 200;

  @override
  void initState() {
    super.initState();
    if (!widget.saleOnly && widget.scrollController != null) {
      widget.scrollController!.addListener(_onScroll);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.saleOnly) {
        final occasion = ref.read(selectedOccasionProvider);
        ref.read(paginatedProductsProvider.notifier).loadInitial(occasion == 'All' ? null : occasion);
      }
    });
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) return;
    final position = controller.position;
    if (position.pixels >= position.maxScrollExtent - _scrollLoadMoreThreshold) {
      ref.read(paginatedProductsProvider.notifier).fetchMoreProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedOccasion = ref.watch(selectedOccasionProvider);
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    final l10n = AppLocalizations.of(context)!;

    if (widget.saleOnly) {
      final bouquetsAsync = ref.watch(landingBouquetsProvider);
      return SectionContainer(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 48, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Seo.text(
              text: l10n.specialOffersTitle,
              style: TextTagStyle.h2,
              child: Text(
                l10n.specialOffersTitle,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.inkCharcoal,
                    ),
              ),
            ),
            SizedBox(height: isMobile ? 16 : 24),
            bouquetsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: ProductGridShimmerGrid(itemCount: 6),
              ),
              error: (err, _) => Column(
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
                    onPressed: () => ref.invalidate(landingBouquetsProvider),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(l10n.retry),
                  ),
                ],
              ),
              data: (bouquets) {
                final list = bouquets.where((b) => b.isOnSaleEffective).toList();
                if (list.isEmpty) {
                  if (bouquets.isNotEmpty) {
                    final fallbackList = bouquets.take(isMobile ? 4 : 8).toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            l10n.noOffersBrowseAll,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: FilledButton.icon(
                            onPressed: () => context.go('/'),
                            icon: const Icon(Icons.local_florist_outlined, size: 20),
                            label: Text(l10n.browseAllBouquets),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.rosePrimary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        _BouquetGrid(
                          list: fallbackList,
                          isMobile: isMobile,
                          orderButtonEnabled: ref.watch(connectivityStatusProvider).value ?? true,
                        ),
                      ],
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      l10n.noOffersYet,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.inkMuted),
                    ),
                  );
                }
                return _BouquetGrid(
                  list: list,
                  isMobile: isMobile,
                  orderButtonEnabled: ref.watch(connectivityStatusProvider).value ?? true,
                );
              },
            ),
          ],
        ),
      );
    }

    ref.listen(selectedOccasionProvider, (prev, next) {
      if (prev != next) {
        ref.read(paginatedProductsProvider.notifier).loadInitial(next == 'All' ? null : next);
      }
    });

    final paginated = ref.watch(paginatedProductsProvider);
    return SectionContainer(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 48, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmotionFilterCards(
            selectedOccasion: selectedOccasion,
            onSelected: (occasion) {
              ref.read(analyticsServiceProvider).logSelectContent(
                    contentType: 'category',
                    itemId: occasion,
                    itemName: occasion,
                  );
              ref.read(selectedOccasionProvider.notifier).setOccasion(occasion);
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
                  onPressed: () => ref.read(paginatedProductsProvider.notifier).loadInitial(
                        selectedOccasion == 'All' ? null : selectedOccasion,
                      ),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(l10n.retry),
                ),
              ],
            )
          else if (paginated.products.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                selectedOccasion == 'All'
                    ? l10n.noBouquetsYet
                    : l10n.noBouquetsForFeeling,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.inkMuted),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BouquetGrid(
                  list: paginated.products,
                  isMobile: isMobile,
                  orderButtonEnabled: ref.watch(connectivityStatusProvider).value ?? true,
                ),
                if (paginated.isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )),
                  )
                else if (!paginated.hasMore && paginated.products.isNotEmpty)
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
    );
  }
}

/// Reusable bouquet grid for landing and offers fallback.
class _BouquetGrid extends StatelessWidget {
  final List<FlowerModel> list;
  final bool isMobile;
  final bool orderButtonEnabled;

  const _BouquetGrid({
    required this.list,
    required this.isMobile,
    this.orderButtonEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
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
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final childWidth = (constraints.maxWidth - gapTotal) / crossAxisCount;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: list.map((b) {
            final imageUrl = b.listingImageUrl.isNotEmpty
                ? b.listingImageUrl
                : 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80';
            final displayPrice = b.isOnSaleEffective && b.discountPrice != null && b.discountPrice! > 0
                ? formatPriceWithCurrency(b.discountPrice!, l10n.currencyIqd)
                : formatPriceWithCurrency(b.priceIqd, l10n.currencyIqd);
            final originalPrice = b.isOnSaleEffective && b.discountPrice != null && b.discountPrice! > 0
                ? formatPriceWithCurrency(b.priceIqd, l10n.currencyIqd)
                : null;
            return SizedBox(
              width: childWidth,
              child: FlowerCard(
                id: b.id,
                name: b.name,
                note: b.description,
                price: displayPrice,
                originalPrice: originalPrice,
                imageUrl: imageUrl,
                bouquetCode: b.bouquetCode.isNotEmpty ? b.bouquetCode : null,
                isCompact: isMobile,
                orderButtonEnabled: orderButtonEnabled,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Trust & reassurance section.
class _TrustSection extends StatelessWidget {
  const _TrustSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    return SectionContainer(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 48, vertical: 48),
      child: Column(
        children: [
          Seo.text(
            text: l10n.carefullyCurated,
            child: Text(
              l10n.carefullyCurated,
              textAlign: TextAlign.center,
              textDirection: Directionality.of(context),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: isMobile ? 12 : 24,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _TrustBadge(
                icon: Icons.local_shipping_outlined,
                label: l10n.sameDayDelivery,
              ),
              _TrustBadge(
                icon: Icons.store_outlined,
                label: l10n.trustedLocalFlorists,
              ),
              _TrustBadge(
                icon: Icons.eco_outlined,
                label: l10n.handcraftedBouquets,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TrustBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: Directionality.of(context),
        children: [
          Icon(icon, size: 18, color: AppColors.inkMuted),
          const SizedBox(width: 10),
          Seo.text(
            text: label,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
