import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../widgets/common/app_cached_image.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';
import '../../widgets/perfume_addon_sheet.dart';

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
      description:
          'Handcrafted flower bouquets for every feeling. Same-day delivery, trusted local florists.',
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
      minimalHeader: !saleOnly,
      child: Column(
        children: [
          if (!saleOnly) _HeroSection(onCategorySelected: _scrollToProducts),
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

/// Full-width hero with video background, dark overlay, minimal typography, and occasion pill at bottom.
class _HeroSection extends ConsumerStatefulWidget {
  const _HeroSection({this.onCategorySelected});

  final VoidCallback? onCategorySelected;

  @override
  ConsumerState<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends ConsumerState<_HeroSection> {
  late VideoPlayerController _videoController;

  static const _videoAsset = 'assets/main_page_01.mp4';

  // Occasion pill animated hints
  static const _hintCount = 4;
  static const _hintDuration = Duration(milliseconds: 2500);
  int _hintIndex = 0;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset(_videoAsset)
      ..initialize()
          .then((_) {
            if (mounted) {
              _videoController
                ..setLooping(true)
                ..setVolume(0)
                ..play();
              setState(() {});
            }
          })
          .catchError((_) {
            if (mounted) setState(() {});
          });
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
    _videoController.dispose();
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
                padding: EdgeInsetsDirectional.only(
                  start: isRTL ? 24 : 0,
                  end: isRTL ? 0 : 24,
                ),
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
                final label = isAll
                    ? l10n.filterAll
                    : localizedEmotionCategoryTitle(
                        l10n,
                        kEmotionCategories
                            .firstWhere((c) => c.id == id)
                            .titleKey,
                      );
                final category = isAll ? null : getEmotionCategoryById(id);
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref
                          .read(selectedOccasionProvider.notifier)
                          .setOccasion(id);
                      if (!isAll) {
                        ref.read(analyticsServiceProvider).logSearch(id);
                      }
                      widget.onCategorySelected?.call();
                      Navigator.of(ctx).pop();
                    },
                    child: Padding(
                      padding: EdgeInsetsDirectional.symmetric(
                        horizontal: isRTL ? 24 : 20,
                        vertical: 16,
                      ),
                      child: Row(
                        textDirection: Directionality.of(context),
                        children: [
                          if (category != null) ...[
                            Icon(
                              category.icon,
                              size: 22,
                              color: AppColors.rose,
                            ),
                            const SizedBox(width: 16),
                          ] else
                            const SizedBox(width: 38),
                          Expanded(
                            child: Text(
                              label,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
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
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final heroHeight = viewportHeight * 0.65;

    final locale = Localizations.localeOf(context);
    final isRTL = locale.languageCode == 'ar' || locale.languageCode == 'ku';
    final headlineFont = isRTL
        ? GoogleFonts.notoNaskhArabic
        : GoogleFonts.cormorantGaramond;
    final bodyFont = isRTL ? GoogleFonts.notoNaskhArabic : GoogleFonts.manrope;

    final selectedOccasion = ref.watch(selectedOccasionProvider);
    if (selectedOccasion != 'All') {
      _stopHintTimer();
    } else {
      if (_hintTimer == null) _startHintTimer();
    }
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

    return SizedBox(
      width: double.infinity,
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Video background — full cover
          if (_videoController.value.isInitialized)
            Positioned.fill(
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
            Positioned.fill(child: Container(color: AppColors.background)),
          // 2. Dark overlay — black gradient for text readability (0.2 top → 0.6 bottom)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),
          // 3. Centered headline + subtitle only
          Center(
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: isMobile ? 24 : 48,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Seo.text(
                    text: '${l10n.heroTitlePart1} ${l10n.heroTitlePart2}',
                    style: TextTagStyle.h1,
                    child: Text(
                      '${l10n.heroTitlePart1}${l10n.heroTitlePart2}',
                      textAlign: TextAlign.center,
                      textDirection: Directionality.of(context),
                      style: headlineFont(
                        fontSize: isMobile ? 32 : 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 16 : 20),
                  Seo.text(
                    text: l10n.heroSubtitle,
                    child: Text(
                      l10n.heroSubtitle,
                      textAlign: TextAlign.center,
                      textDirection: Directionality.of(context),
                      style: bodyFont(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.w300,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          // 4. Occasion pill at bottom edge of video section
          Positioned(
            left: isMobile ? 24 : 56,
            right: isMobile ? 24 : 56,
            bottom: 28,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openOccasionPicker(context),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 24 : 32,
                    vertical: isMobile ? 18 : 22,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
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
                                  style: headlineFont(
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
                                    style: headlineFont(
                                      fontSize: isMobile ? 18 : 20,
                                      fontWeight: FontWeight.w400,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.inkMuted.withValues(
                                        alpha: 0.9,
                                      ),
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
  int _bouquetLimit = 6;
  String _selectedPerfumeBrand = 'All';
  final PageController _adsPageController = PageController();
  Timer? _adsTimer;
  int _adsCurrentPage = 0;
  int _adsImageCount = 0;
  static const List<String> _premiumPerfumeBrands = [
    'All',
    'Chanel',
    'Dior',
    'Tom Ford',
    'Yves Saint Laurent',
    'Gucci',
    'Versace',
    'Creed',
    'Amouage',
    'Maison Francis Kurkdjian',
    'Parfums de Marly',
    'Giorgio Armani',
    'Hermès',
    'Jo Malone',
    'Givenchy',
    'Lancôme',
    'Bvlgari',
    'Roja Parfums',
    'Xerjoff',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
  }

  void _syncAdsAutoScroll(int imageCount) {
    if (_adsImageCount != imageCount) {
      _adsImageCount = imageCount;
      _adsCurrentPage = imageCount > 1 ? imageCount * 1000 : 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_adsPageController.hasClients) return;
        _adsPageController.jumpToPage(_adsCurrentPage);
      });
    }

    if (imageCount > 1 && _adsTimer == null) {
      _adsTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!mounted || !_adsPageController.hasClients) return;
        _adsCurrentPage += 1;
        _adsPageController.animateToPage(
          _adsCurrentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      });
    } else if (imageCount <= 1) {
      _adsTimer?.cancel();
      _adsTimer = null;
    }
  }

  @override
  void dispose() {
    _adsTimer?.cancel();
    _adsPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedOccasion = ref.watch(selectedOccasionProvider);
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    final l10n = AppLocalizations.of(context)!;

    if (widget.saleOnly) {
      final bouquetsAsync = ref.watch(landingBouquetsProvider);
      return SectionContainer(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 48,
          vertical: 24,
        ),
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
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
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
                final list = bouquets
                    .where((b) => b.isOnSaleEffective)
                    .toList();
                if (list.isEmpty) {
                  if (bouquets.isNotEmpty) {
                    final fallbackList = bouquets
                        .take(isMobile ? 4 : 8)
                        .toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            l10n.noOffersBrowseAll,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: AppColors.inkMuted),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: FilledButton.icon(
                            onPressed: () => context.go('/'),
                            icon: const Icon(
                              Icons.local_florist_outlined,
                              size: 20,
                            ),
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
                          orderButtonEnabled:
                              ref.watch(connectivityStatusProvider).value ??
                              true,
                        ),
                      ],
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      l10n.noOffersYet,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  );
                }
                return _BouquetGrid(
                  list: list,
                  isMobile: isMobile,
                  orderButtonEnabled:
                      ref.watch(connectivityStatusProvider).value ?? true,
                );
              },
            ),
          ],
        ),
      );
    }

    Query<Map<String, dynamic>> bouquetQuery = FirebaseFirestore.instance
        .collection('bouquets')
        .where('approvalStatus', isEqualTo: 'approved');
    if (selectedOccasion != 'All') {
      bouquetQuery = bouquetQuery.where(
        'emotionCategoryId',
        isEqualTo: selectedOccasion,
      );
    }
    bouquetQuery = bouquetQuery.limit(_bouquetLimit);

    Query<Map<String, dynamic>> perfumeQuery = FirebaseFirestore.instance
        .collection('perfumes')
        .where('approvalStatus', isEqualTo: 'approved');
    if (_selectedPerfumeBrand != 'All') {
      perfumeQuery = perfumeQuery.where(
        'brand',
        isEqualTo: _selectedPerfumeBrand,
      );
    }

    return SectionContainer(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 48,
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: isMobile ? 8 : 16),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: bouquetQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: ProductGridShimmerGrid(itemCount: 6),
                );
              }
              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.couldNotLoadBouquets,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(l10n.retry),
                    ),
                  ],
                );
              }

              final docs = snapshot.data?.docs ?? const [];
              final bouquets = docs
                  .map((doc) => FlowerModel.fromJson(doc.id, doc.data()))
                  .toList();
              final hasMoreBouquets = docs.length >= _bouquetLimit;
              final isOnline =
                  ref.watch(connectivityStatusProvider).value ?? true;

              if (bouquets.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    selectedOccasion == 'All'
                        ? l10n.noBouquetsYet
                        : l10n.noBouquetsForFeeling,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BouquetGrid(
                    list: bouquets,
                    isMobile: isMobile,
                    orderButtonEnabled: isOnline,
                  ),
                  if (hasMoreBouquets)
                    Padding(
                      padding: const EdgeInsets.only(top: 18, bottom: 10),
                      child: Center(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _bouquetLimit += 6),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.inkCharcoal,
                            side: BorderSide(
                              color: AppColors.inkMuted.withValues(alpha: 0.35),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            l10n.seeMoreBouquets,
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            height: 1,
            color: AppColors.border.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 22),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('settings')
                .doc('home_ads')
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              final imageUrls = ((data?['imageUrls'] as List?) ?? const [])
                  .map((e) => e.toString())
                  .where((e) => e.isNotEmpty)
                  .toList();
              if (imageUrls.isEmpty) return const SizedBox.shrink();
              _syncAdsAutoScroll(imageUrls.length);
              return _LuxuryHomeAdsCarousel(
                imageUrls: imageUrls,
                controller: _adsPageController,
              );
            },
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              l10n.luxury_perfumes,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: isMobile ? 22 : 26,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFB8892A),
                letterSpacing: 0.35,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _premiumPerfumeBrands.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final brand = _premiumPerfumeBrands[index];
                final isSelected = _selectedPerfumeBrand == brand;
                return InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedPerfumeBrand = brand);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFB8892A).withValues(alpha: 0.12)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFB8892A)
                            : AppColors.border.withValues(alpha: 0.75),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        brand,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? const Color(0xFF8E6A1C)
                              : AppColors.inkMuted,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: perfumeQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ProductGridShimmerGrid(itemCount: 4);
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'More exclusive perfumes arriving soon.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? const [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'More exclusive perfumes arriving soon.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                );
              }

              final perfumeItems = docs.map((e) {
                final m = Map<String, dynamic>.from(e.data());
                m['id'] = e.id;
                return m;
              }).toList();

              return _PerfumeGrid(
                items: perfumeItems,
                isMobile: isMobile,
                currencyLabel: l10n.currencyIqd,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LuxuryHomeAdsCarousel extends StatelessWidget {
  const _LuxuryHomeAdsCarousel({
    required this.imageUrls,
    required this.controller,
  });

  final List<String> imageUrls;
  final PageController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        height: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: PageView.builder(
            controller: controller,
            itemCount: imageUrls.length > 1 ? null : 1,
            itemBuilder: (context, index) {
              final imageUrl = imageUrls[index % imageUrls.length];
              return AppCachedImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorIcon: Icons.image_not_supported_outlined,
                errorIconSize: 34,
              );
            },
          ),
        ),
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
    final gap = width < kMobileBreakpoint ? (width < 380 ? 8.0 : 10.0) : 16.0;
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
            final displayPrice =
                b.isOnSaleEffective &&
                    b.discountPrice != null &&
                    b.discountPrice! > 0
                ? formatPriceWithCurrency(b.discountPrice!, l10n.currencyIqd)
                : formatPriceWithCurrency(b.priceIqd, l10n.currencyIqd);
            final originalPrice =
                b.isOnSaleEffective &&
                    b.discountPrice != null &&
                    b.discountPrice! > 0
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
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 48,
        vertical: 48,
      ),
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
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 20,
        vertical: 12,
      ),
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

class _PerfumeGrid extends StatelessWidget {
  const _PerfumeGrid({
    required this.items,
    required this.isMobile,
    required this.currencyLabel,
  });

  final List<Map<String, dynamic>> items;
  final bool isMobile;
  final String currencyLabel;

  String _resolvePerfumeImageUrl(Map<String, dynamic> item) {
    final rawImageUrls = item['imageUrls'];
    final imageUrls = rawImageUrls is List ? rawImageUrls : const [];
    if (imageUrls.isNotEmpty) {
      final firstUrl = imageUrls.first?.toString() ?? '';
      if (firstUrl.isNotEmpty) return firstUrl;
    }
    return item['imageUrl']?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width < kMobileBreakpoint
        ? 2
        : width < kTabletBreakpoint
        ? 3
        : 4;
    final gap = width < kMobileBreakpoint ? 10.0 : 16.0;
    final gapTotal = (crossAxisCount - 1) * gap;
    return LayoutBuilder(
      builder: (context, constraints) {
        final childWidth = (constraints.maxWidth - gapTotal) / crossAxisCount;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items.map((item) {
            return SizedBox(
              width: childWidth,
              child: _PerfumeCard(
                item: item,
                imageUrl: _resolvePerfumeImageUrl(item),
                brand: item['brand']?.toString() ?? 'Luxury Brand',
                name: item['name']?.toString() ?? 'Exclusive Perfume',
                priceRaw: item['priceIqd'] ?? item['price'],
                currencyLabel: currencyLabel,
                isCompact: isMobile,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _PerfumeCard extends ConsumerStatefulWidget {
  const _PerfumeCard({
    required this.item,
    required this.imageUrl,
    required this.brand,
    required this.name,
    required this.priceRaw,
    required this.currencyLabel,
    required this.isCompact,
  });

  final Map<String, dynamic> item;
  final String imageUrl;
  final String brand;
  final String name;
  final Object? priceRaw;
  final String currencyLabel;
  final bool isCompact;

  @override
  ConsumerState<_PerfumeCard> createState() => _PerfumeCardState();
}

class _PerfumeCardState extends ConsumerState<_PerfumeCard> {
  static const Duration _favoriteAnimDuration = Duration(milliseconds: 220);

  bool? _wishlistOptimistic;

  bool _favoriteToggleInFlight = false;

  bool _effectiveFavorite(List<String> wishlist, String productId) {
    if (productId.isEmpty) return false;
    return _wishlistOptimistic ?? wishlist.contains(productId);
  }

  void _syncWishlistOptimistic(List<String> wishlist, String productId) {
    final o = _wishlistOptimistic;
    if (o == null || productId.isEmpty) return;
    if (wishlist.contains(productId) == o) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _wishlistOptimistic = null);
      });
    }
  }

  Future<void> _toggleFavoriteOptimistic(
    List<String> wishlist,
    String? uid,
    String productId,
  ) async {
    if (_favoriteToggleInFlight) return;
    if (!mounted) return;
    if (uid == null) {
      showLoginModalOrPush(context);
      return;
    }
    if (productId.isEmpty) return;
    final was = _effectiveFavorite(wishlist, productId);
    setState(() {
      _favoriteToggleInFlight = true;
      _wishlistOptimistic = !was;
    });
    try {
      await ref.read(authRepositoryProvider).toggleFavorite(productId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _wishlistOptimistic = null);
      final messenger = ScaffoldMessenger.maybeOf(context);
      final msg = AppLocalizations.of(context)?.favoriteUpdateFailed ??
          'Failed to update favorites. Please check your connection.';
      messenger?.showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _favoriteToggleInFlight = false);
    }
  }

  void _openPerfumeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          PerfumeAddonBottomSheet(perfume: PerfumeAddonData.fromItemMap(widget.item)),
    );
  }

  Widget _buildPerfumeImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 34,
          color: AppColors.inkMuted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parsedPrice = widget.priceRaw is num
        ? (widget.priceRaw as num).toInt()
        : int.tryParse(widget.priceRaw?.toString() ?? '') ?? 0;
    final displayPrice = formatPriceWithCurrency(parsedPrice, widget.currencyLabel);
    final fallbackImage =
        'https://images.unsplash.com/photo-1594035910387-fea47794261f?auto=format&fit=crop&w=900&q=80';
    final cardRadius = BorderRadius.circular(18);
    final l10n = AppLocalizations.of(context)!;
    final authUser = ref.watch(authStateProvider).value;
    final wishlist = authUser == null
        ? const <String>[]
        : (ref.watch(userWishlistProvider(authUser.uid)).value ?? const <String>[]);
    final productId = widget.item['id']?.toString() ?? '';
    _syncWishlistOptimistic(wishlist, productId);
    final isFavorite = _effectiveFavorite(wishlist, productId);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPerfumeSheet(context),
        borderRadius: cardRadius,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: cardRadius,
            border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: cardRadius,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: widget.isCompact ? 1 : 1.12,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildPerfumeImage(
                        widget.imageUrl.isEmpty ? fallbackImage : widget.imageUrl,
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Material(
                              color: Colors.white.withValues(alpha: 0.22),
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  _toggleFavoriteOptimistic(
                                    wishlist,
                                    authUser?.uid,
                                    productId,
                                  );
                                },
                                child: SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: Center(
                                    child: AnimatedSwitcher(
                                      duration: _favoriteAnimDuration,
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      transitionBuilder: (child, animation) =>
                                          FadeTransition(
                                        opacity: animation,
                                        child: ScaleTransition(
                                          scale: Tween<double>(begin: 0.88, end: 1.0)
                                              .animate(animation),
                                          child: child,
                                        ),
                                      ),
                                      child: Icon(
                                        key: ValueKey<bool>(isFavorite),
                                        isFavorite
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        size: 20,
                                        color: isFavorite
                                            ? AppColors.rosePrimary
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.brand,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF9A7A2D),
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkCharcoal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              displayPrice,
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.perfumeOrderCta,
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkCharcoal.withValues(
                                alpha: 0.78,
                              ),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
