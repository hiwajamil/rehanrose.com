import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../controllers/controllers.dart';
import '../../widgets/cards/flower_card.dart';
import '../../widgets/common/occasion_filter_chips.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';

class LandingPage extends ConsumerStatefulWidget {
  const LandingPage({super.key});

  @override
  ConsumerState<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends ConsumerState<LandingPage> {
  final _featuredSectionKey = GlobalKey();

  void _scrollToFlowers() {
    final context = _featuredSectionKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        children: [
          _HeroSection(onShopFlowers: _scrollToFlowers),
          _FeaturedSection(key: _featuredSectionKey),
          _VendorSection(),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final VoidCallback? onShopFlowers;

  const _HeroSection({this.onShopFlowers});

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 72),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 980;
          final isMobile = constraints.maxWidth <= kMobileBreakpoint;
          final innerPadding = isMobile ? 16.0 : 48.0;
          return Container(
            padding: EdgeInsets.all(innerPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.background,
                  AppColors.blush.withValues(alpha:0.3),
                  AppColors.sage.withValues(alpha:0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: AppColors.border.withValues(alpha:0.8),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.blush.withValues(alpha:0.08),
                  blurRadius: 48,
                  offset: const Offset(0, 16),
                  spreadRadius: -8,
                ),
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha:0.04),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Flex(
              direction: isNarrow ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment:
                  isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: isNarrow ? 0 : 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Florals that speak before you do.',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Curated bouquets from artisan studios. Soft, modern, and delivered with care.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 32),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          PrimaryButton(
                            label: 'Shop Flowers',
                            onPressed: onShopFlowers ?? () {},
                            variant: PrimaryButtonVariant.primary,
                          ),
                          PrimaryButton(
                            label: 'Become a Vendor',
                            onPressed: () => context.go('/vendor'),
                            variant: PrimaryButtonVariant.outline,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      isMobile
                          ? Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: const [
                                _HeroBadge(
                                  label: 'Same-day delivery',
                                  icon: Icons.local_shipping_outlined,
                                ),
                                _HeroBadge(
                                  label: 'Ethically sourced',
                                  icon: Icons.eco_outlined,
                                ),
                                _HeroBadge(
                                  label: 'Concierge service',
                                  icon: Icons.volunteer_activism_outlined,
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                _HeroBadge(
                                  label: 'Same-day delivery',
                                  icon: Icons.local_shipping_outlined,
                                ),
                                const SizedBox(width: 12),
                                _HeroBadge(
                                  label: 'Ethically sourced',
                                  icon: Icons.eco_outlined,
                                ),
                                const SizedBox(width: 12),
                                _HeroBadge(
                                  label: 'Concierge service',
                                  icon: Icons.volunteer_activism_outlined,
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
                if (!isNarrow) const SizedBox(width: 40),
                Expanded(
                  flex: isNarrow ? 0 : 5,
                  child: Padding(
                    padding: EdgeInsets.only(top: isNarrow ? 32 : 0),
                    child: _HeroImageStack(isNarrow: isNarrow),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroImageStack extends StatefulWidget {
  final bool isNarrow;

  const _HeroImageStack({required this.isNarrow});

  @override
  State<_HeroImageStack> createState() => _HeroImageStackState();
}

class _HeroImageStackState extends State<_HeroImageStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    final height = isMobile ? 280.0 : (widget.isNarrow ? 360.0 : 480.0);
    final card1Height = isMobile ? 160.0 : (widget.isNarrow ? 220.0 : 280.0);
    final card2Height = isMobile ? 180.0 : (widget.isNarrow ? 240.0 : 320.0);
    return SizedBox(
      height: height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            clipBehavior: isMobile ? Clip.hardEdge : Clip.none,
            children: [
              Positioned(
                left: 0,
                top: widget.isNarrow ? 12 : 16,
                child: SlideTransition(
                  position: _slide,
                  child: FadeTransition(
                    opacity: _opacity,
                    child: _HeroImageCard(
                      imageUrl:
                          'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?auto=format&fit=crop&w=800&q=80',
                      height: card1Height,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: isMobile ? 0 : (widget.isNarrow ? 0 : -20),
                bottom: 0,
                child: SlideTransition(
                  position: _slide,
                  child: FadeTransition(
                    opacity: _opacity,
                    child: _HeroImageCard(
                      imageUrl:
                          'https://images.unsplash.com/photo-1471899236350-e3016bf1e69e?auto=format&fit=crop&w=800&q=80',
                      height: card2Height,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroImageCard extends StatelessWidget {
  final String imageUrl;
  final double height;

  const _HeroImageCard({required this.imageUrl, required this.height});

  @override
  Widget build(BuildContext context) {
    const radius = 32.0;
    return Container(
      height: height,
      width: height * 0.72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border.withValues(alpha:0.6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha:0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: AppColors.shadow.withValues(alpha:0.12),
            blurRadius: 40,
            offset: const Offset(0, 20),
            spreadRadius: -8,
          ),
        ],
      ),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          cacheWidth: 400,
          cacheHeight: 500,
        ),
      ),
    );
  }
}

class _HeroBadge extends StatefulWidget {
  final String label;
  final IconData? icon;

  const _HeroBadge({required this.label, this.icon});

  @override
  State<_HeroBadge> createState() => _HeroBadgeState();
}

class _HeroBadgeState extends State<_HeroBadge> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered
              ? Colors.white.withValues(alpha:0.85)
              : Colors.white.withValues(alpha:0.65),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.border.withValues(alpha:0.6),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                size: 14,
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              widget.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedSection extends ConsumerWidget {
  const _FeaturedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedOccasion = ref.watch(selectedOccasionProvider);
    final bouquetsAsync = ref.watch(bouquetsStreamProvider);

    return SectionContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fresh Blooms from Local Shops',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Designed by sought-after studios for modern rituals.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          OccasionFilterChips(
            selectedOccasion: selectedOccasion,
            onSelected: (occasion) =>
                ref.read(selectedOccasionProvider.notifier).setOccasion(occasion),
          ),
          const SizedBox(height: 32),
          bouquetsAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Loading bouquets…',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.inkMuted),
              ),
            ),
            error: (err, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Could not load bouquets.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.inkMuted),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => ref.invalidate(bouquetsStreamProvider),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                ),
              ],
            ),
            data: (bouquets) {
              if (bouquets.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    selectedOccasion == 'All'
                        ? 'No vendor bouquets yet.'
                        : 'No bouquets for $selectedOccasion yet.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.inkMuted),
                  ),
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 980;
                  final isMobile = constraints.maxWidth <= kMobileBreakpoint;
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    transitionBuilder: (child, animation) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.03),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        )),
                        child: child,
                      );
                    },
                    child: Wrap(
                      key: ValueKey(selectedOccasion),
                      spacing: 24,
                      runSpacing: 24,
                      children: bouquets.map((b) {
                        final imageUrl = b.imageUrls.isNotEmpty
                            ? b.imageUrls.first
                            : 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80';
                        return SizedBox(
                          width: isNarrow || isMobile
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 48) / 3,
                          child: FlowerCard(
                            id: b.id,
                            name: b.name,
                            note: b.description,
                            price: 'IQD ${b.priceIqd}',
                            imageUrl: imageUrl,
                            onTap: () => context.go('/flower/${b.id}'),
                            bouquetCode: b.bouquetCode.isNotEmpty
                                ? b.bouquetCode
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
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

class _VendorSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    return SectionContainer(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 980;
            return Flex(
              direction: isNarrow ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment:
                  isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vendor spotlight: Lune Botanica',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'A Paris-inspired atelier crafting sculptural arrangements with a calm, romantic palette.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'Explore the studio',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                if (!isNarrow) const SizedBox(width: 32),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      'https://images.unsplash.com/photo-1487070183336-b863922373d4?auto=format&fit=crop&w=900&q=80',
                      height: 280,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      cacheWidth: 600,
                      cacheHeight: 280,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
