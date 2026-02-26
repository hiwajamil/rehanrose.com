import 'dart:async';

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
import '../../widgets/common/product_grid_shimmer.dart';
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
          if (!saleOnly) _OccasionsHeroSection(onCategorySelected: _scrollToProducts),
          if (!saleOnly) const SizedBox(height: 48),
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

/// Ultra-premium occasions hero: single elegant bar, animated hint, modal picker, poetic subtitle.
class _OccasionsHeroSection extends ConsumerStatefulWidget {
  final VoidCallback? onCategorySelected;

  const _OccasionsHeroSection({this.onCategorySelected});

  @override
  ConsumerState<_OccasionsHeroSection> createState() => _OccasionsHeroSectionState();
}

class _OccasionsHeroSectionState extends ConsumerState<_OccasionsHeroSection> {
  static const _hintCount = 4;
  static const _hintDuration = Duration(milliseconds: 2500);

  int _hintIndex = 0;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _startHintTimer();
  }

  void _startHintTimer() {
    _hintTimer?.cancel();
    _hintTimer = Timer.periodic(_hintDuration, (_) {
      if (mounted) setState(() => _hintIndex = (_hintIndex + 1) % _hintCount);
    });
  }

  void _stopHintTimer() {
    _hintTimer?.cancel();
    _hintTimer = null;
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  void _openOccasionPicker(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final isRTL = locale.languageCode == 'ar' || locale.languageCode == 'ku';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.08),
              blurRadius: 32,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(ctx).bottom + 24,
          top: 24,
          left: isRTL ? 0 : 24,
          right: isRTL ? 24 : 0,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: EdgeInsetsDirectional.only(start: isRTL ? 24 : 0, end: isRTL ? 0 : 24),
                child: Text(
                  l10n.what_do_you_want_to_say,
                  textAlign: TextAlign.center,
                  textDirection: Directionality.of(context),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              ...['All', ...kEmotionCategoryIds].map((id) {
                final isAll = id == 'All';
                final label = isAll ? l10n.filterAll : localizedEmotionCategoryTitle(l10n, kEmotionCategories.firstWhere((c) => c.id == id).titleKey);
                final category = isAll ? null : getEmotionCategoryById(id);
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      ref.read(selectedOccasionProvider.notifier).setOccasion(id);
                      if (!isAll) {
                        ref.read(analyticsServiceProvider).logSearch(id);
                      }
                      widget.onCategorySelected?.call();
                      Navigator.of(ctx).pop();
                    },
                    child: Padding(
                      padding: EdgeInsetsDirectional.symmetric(horizontal: isRTL ? 24 : 20, vertical: 16),
                      child: Row(
                        textDirection: Directionality.of(context),
                        children: [
                          if (category != null) ...[
                            Icon(category.icon, size: 22, color: AppColors.rose),
                            const SizedBox(width: 16),
                          ] else
                            const SizedBox(width: 38),
                          Expanded(
                            child: Text(
                              label,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedOccasion = ref.watch(selectedOccasionProvider);
    if (selectedOccasion != 'All') {
      _stopHintTimer();
    } else {
      if (_hintTimer == null) _startHintTimer();
    }
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    final serifFont = GoogleFonts.cormorantGaramond;
    final selectedCategory = getEmotionCategoryById(selectedOccasion);
    final selectedLabel = selectedCategory != null
        ? localizedEmotionCategoryTitle(l10n, selectedCategory.titleKey)
        : null;
    final hasSelection = selectedOccasion != 'All' && selectedLabel != null;
    final hintPhrases = [
      l10n.say_love,
      l10n.say_sorry,
      l10n.say_congrats,
      l10n.say_thanks,
    ];
    final currentHint = hintPhrases[_hintIndex % hintPhrases.length];

    return SectionContainer(
      padding: EdgeInsetsDirectional.only(
        start: isMobile ? 24 : 56,
        end: isMobile ? 24 : 56,
        top: 40,
        bottom: 32,
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Seo.text(
            text: l10n.what_do_you_want_to_say,
            style: TextTagStyle.h2,
            child: Text(
              l10n.what_do_you_want_to_say,
              textAlign: TextAlign.center,
              textDirection: Directionality.of(context),
              style: serifFont(
                fontSize: isMobile ? 28 : 36,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                letterSpacing: 0.2,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openOccasionPicker(context),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 24 : 32,
                  vertical: isMobile ? 20 : 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: hasSelection
                            ? Text(
                                selectedLabel,
                                textAlign: TextAlign.center,
                                textDirection: Directionality.of(context),
                                style: serifFont(
                                  fontSize: isMobile ? 20 : 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.inkCharcoal,
                                ),
                              )
                            : AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                                child: Text(
                                  currentHint,
                                  key: ValueKey<int>(_hintIndex),
                                  textAlign: TextAlign.center,
                                  textDirection: Directionality.of(context),
                                  style: serifFont(
                                    fontSize: isMobile ? 18 : 20,
                                    fontWeight: FontWeight.w400,
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.inkMuted.withValues(alpha: 0.9),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 28,
                      color: AppColors.inkMuted.withValues(alpha: 0.75),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasSelection) ...[
            const SizedBox(height: 20),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - value)),
                  child: child,
                ),
              ),
              child: Seo.text(
                text: l10n.collection_crafted_for + selectedLabel,
                child: Text(
                  l10n.collection_crafted_for + selectedLabel,
                  textAlign: TextAlign.center,
                  textDirection: Directionality.of(context),
                  style: serifFont(
                    fontSize: isMobile ? 15 : 17,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: AppColors.inkMuted,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
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
          SizedBox(height: isMobile ? 8 : 16),
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
