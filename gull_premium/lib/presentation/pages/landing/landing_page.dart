import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/breakpoints.dart';
import '../../../core/constants/emotion_category.dart';
import '../../../core/utils/emotion_category_l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../controllers/controllers.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/cards/flower_card.dart';
import '../../widgets/common/emotion_dropdown.dart';
import '../../widgets/common/emotion_filter_cards.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';

class LandingPage extends ConsumerStatefulWidget {
  const LandingPage({super.key});

  @override
  ConsumerState<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends ConsumerState<LandingPage> {
  final _productsSectionKey = GlobalKey();

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
    return AppScaffold(
      child: Column(
        children: [
          const _HeroSection(),
          _CategoryCardsSection(onCategorySelected: _scrollToProducts),
          Transform.translate(
            offset: const Offset(0, -48),
            child: _EmotionDropdownBlock(onSelection: _scrollToProducts),
          ),
          const SizedBox(height: 24),
          _TransitionSection(onExplore: _scrollToProducts),
          _ProductsSection(key: _productsSectionKey, onScrollToProducts: _scrollToProducts),
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
                RichText(
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
                SizedBox(height: isMobile ? 20 : 28),
                Text(
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
                const SizedBox(height: 40),
                Text(
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
    final crossAxisCount = isMobile ? 2 : 4;
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
          Text(
            l10n.home_question,
            textAlign: TextAlign.center,
            textDirection: Directionality.of(context),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
          ),
          const SizedBox(height: 24),
          Directionality(
            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.1,
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
          padding: const EdgeInsetsDirectional.all(20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
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
              const SizedBox(height: 12),
              Text(
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
          Text(
            l10n.flowersForEveryFeeling,
            textAlign: TextAlign.center,
            textDirection: Directionality.of(context),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.eachBouquetCopy,
            textAlign: TextAlign.center,
            textDirection: Directionality.of(context),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// Products section: emotion filter + bouquet grid.
class _ProductsSection extends ConsumerWidget {
  final VoidCallback? onScrollToProducts;

  const _ProductsSection({super.key, this.onScrollToProducts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedOccasion = ref.watch(selectedOccasionProvider);
    final bouquetsAsync = ref.watch(landingBouquetsProvider);
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;

    final l10n = AppLocalizations.of(context)!;
    return SectionContainer(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 48, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmotionFilterCards(
            selectedOccasion: selectedOccasion,
            onSelected: (occasion) =>
                ref.read(selectedOccasionProvider.notifier).setOccasion(occasion),
          ),
          const SizedBox(height: 40),
          bouquetsAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                l10n.loadingBouquets,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.inkMuted),
              ),
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
              if (bouquets.isEmpty) {
                return Padding(
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
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = isMobile ? 1 : 3;
                  final childWidth = (constraints.maxWidth - 48) / crossAxisCount;
                  return Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    children: bouquets.map((b) {
                      final imageUrl = b.imageUrls.isNotEmpty
                          ? b.imageUrls.first
                          : 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80';
                      return SizedBox(
                        width: childWidth,
                        child: FlowerCard(
                          id: b.id,
                          name: b.name,
                          note: b.description,
                          price: 'IQD ${b.priceIqd}',
                          imageUrl: imageUrl,
                          onTap: () => context.go('/flower/${b.id}'),
                          bouquetCode: b.bouquetCode.isNotEmpty ? b.bouquetCode : null,
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
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
          Text(
            l10n.carefullyCurated,
            textAlign: TextAlign.center,
            textDirection: Directionality.of(context),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w500,
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
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
          ),
        ],
      ),
    );
  }
}
