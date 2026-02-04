import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../widgets/cards/flower_card.dart';
import '../../widgets/common/occasion_filter_chips.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _featuredSectionKey = GlobalKey();
  String _selectedOccasion = 'All';

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
          _FeaturedSection(
            key: _featuredSectionKey,
            selectedOccasion: _selectedOccasion,
            onSelectedOccasion: (occasion) =>
                setState(() => _selectedOccasion = occasion),
          ),
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
          return Container(
            padding: const EdgeInsets.all(48),
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
                      Row(
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
    return SizedBox(
      height: widget.isNarrow ? 360 : 480,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            clipBehavior: Clip.none,
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
                      height: widget.isNarrow ? 220 : 280,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: widget.isNarrow ? 0 : -20,
                bottom: 0,
                child: SlideTransition(
                  position: _slide,
                  child: FadeTransition(
                    opacity: _opacity,
                    child: _HeroImageCard(
                      imageUrl:
                          'https://images.unsplash.com/photo-1471899236350-e3016bf1e69e?auto=format&fit=crop&w=800&q=80',
                      height: widget.isNarrow ? 240 : 320,
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

class _FeaturedSection extends StatefulWidget {
  const _FeaturedSection({
    super.key,
    required this.selectedOccasion,
    required this.onSelectedOccasion,
  });

  final String selectedOccasion;
  final ValueChanged<String> onSelectedOccasion;

  @override
  State<_FeaturedSection> createState() => _FeaturedSectionState();
}

class _FeaturedSectionState extends State<_FeaturedSection> {
  /// All bouquets stream, used when a filtered occasion has no results.
  static Stream<QuerySnapshot<Map<String, dynamic>>> get _allBouquetsStream =>
      FirebaseFirestore.instance
          .collection('bouquets')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .timeout(const Duration(seconds: 5));

  @override
  Widget build(BuildContext context) {
    final selectedOccasion = widget.selectedOccasion;
    final Query<Map<String, dynamic>> query;
    if (selectedOccasion == 'All') {
      query = FirebaseFirestore.instance
          .collection('bouquets')
          .orderBy('createdAt', descending: true)
          .limit(50);
    } else {
      query = FirebaseFirestore.instance
          .collection('bouquets')
          .where('occasion', isEqualTo: selectedOccasion)
          .orderBy('createdAt', descending: true)
          .limit(50);
    }

    final bouquetsStream = query.snapshots().timeout(
          const Duration(seconds: 5),
        );

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
            onSelected: widget.onSelectedOccasion,
          ),
          const SizedBox(height: 32),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: bouquetsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Loading bouquets…',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.inkMuted),
                      ),
                    ),
                    _buildPlaceholderGrid(context),
                  ],
                );
              }

              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Could not load bouquets. Showing samples.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.inkMuted),
                      ),
                    ),
                    _buildPlaceholderGrid(context),
                  ],
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                if (selectedOccasion == 'All') {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'No vendor bouquets yet. Here are some samples.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.inkMuted),
                        ),
                      ),
                      _buildPlaceholderGrid(context),
                    ],
                  );
                }
                // For a specific occasion with no results, show all bouquets with a hint.
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _allBouquetsStream,
                  builder: (context, allSnapshot) {
                    if (allSnapshot.connectionState == ConnectionState.waiting) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              'Loading…',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.inkMuted),
                            ),
                          ),
                          _buildPlaceholderGrid(context),
                        ],
                      );
                    }
                    final allDocs = allSnapshot.data?.docs ?? [];
                    if (allDocs.isEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              'No bouquets for $selectedOccasion yet. Here are some samples.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.inkMuted),
                            ),
                          ),
                          _buildPlaceholderGrid(context),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            'No bouquets for $selectedOccasion yet. Showing all bouquets.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.inkMuted),
                          ),
                        ),
                        _buildBouquetGrid(context, allDocs),
                      ],
                    );
                  },
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 980;
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.05),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Wrap(
                      key: ValueKey(widget.selectedOccasion),
                      spacing: 24,
                      runSpacing: 24,
                      children: docs.map((doc) {
                        final data = doc.data();
                        final imageUrls =
                            (data['imageUrls'] as List?)?.cast<String>() ?? [];
                        final price = data['priceIqd']?.toString() ?? '--';
                        final docId = doc.id;
                        final bouquetCode = data['bouquetCode']?.toString();
                        return SizedBox(
                          width: isNarrow
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 48) / 3,
                          child: FlowerCard(
                            id: docId,
                            name: data['name']?.toString() ?? 'Untitled bouquet',
                            note: data['description']?.toString() ??
                                'Vendor bouquet',
                            price: 'IQD $price',
                            imageUrl: imageUrls.isNotEmpty
                                ? imageUrls.first
                                : 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80',
                            onTap: () => context.go('/flower/$docId'),
                            bouquetCode: bouquetCode,
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

  static const List<Map<String, String>> _placeholderBouquets = [
    {
      'name': 'Spring Garden',
      'description': 'A fresh mix of seasonal blooms.',
      'price': 'IQD 35,000',
      'imageUrl': 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80',
    },
    {
      'name': 'Romantic Roses',
      'description': 'Classic red roses for your special day.',
      'price': 'IQD 45,000',
      'imageUrl': 'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?auto=format&fit=crop&w=800&q=80',
    },
    {
      'name': 'Minimalist White',
      'description': 'Elegant white florals, soft and modern.',
      'price': 'IQD 28,000',
      'imageUrl': 'https://images.unsplash.com/photo-1471899236350-e3016bf1e69e?auto=format&fit=crop&w=800&q=80',
    },
  ];

  Widget _buildPlaceholderGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 980;
        return Wrap(
          spacing: 24,
          runSpacing: 24,
          children: _placeholderBouquets.map((item) {
            return SizedBox(
              width: isNarrow
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 48) / 3,
              child: FlowerCard(
                id: 'placeholder-${item['name']}',
                name: item['name']!,
                note: item['description']!,
                price: item['price']!,
                imageUrl: item['imageUrl']!,
                onTap: null,
                bouquetCode: null,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildBouquetGrid(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 980;
        return Wrap(
          spacing: 24,
          runSpacing: 24,
          children: docs.map((doc) {
            final data = doc.data();
            final imageUrls =
                (data['imageUrls'] as List?)?.cast<String>() ?? [];
            final price = data['priceIqd']?.toString() ?? '--';
            final docId = doc.id;
            final bouquetCode = data['bouquetCode']?.toString();
            return SizedBox(
              width: isNarrow
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 48) / 3,
              child: FlowerCard(
                id: docId,
                name: data['name']?.toString() ?? 'Untitled bouquet',
                note: data['description']?.toString() ?? 'Vendor bouquet',
                price: 'IQD $price',
                imageUrl: imageUrls.isNotEmpty
                    ? imageUrls.first
                    : 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80',
                onTap: () => context.go('/flower/$docId'),
                bouquetCode: bouquetCode,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _VendorSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      child: Container(
        padding: const EdgeInsets.all(36),
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
