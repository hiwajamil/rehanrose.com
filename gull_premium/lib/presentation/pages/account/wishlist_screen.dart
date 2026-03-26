import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../controllers/controllers.dart';
import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_format_utils.dart';
import '../../../data/models/flower_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/add_on_personalization_modal.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';
import '../../widgets/perfume_addon_sheet.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      return AppScaffold(
        title: 'My Favorites',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Sign in to access your VIP wishlist.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final wishlistAsync = ref.watch(userWishlistProvider(user.uid));
    return AppScaffold(
      title: 'My Favorites',
      child: wishlistAsync.when(
        data: (ids) => _WishlistContent(ids: ids),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(
            'Could not load your wishlist right now.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
        ),
      ),
    );
  }
}

class _WishlistContent extends ConsumerWidget {
  const _WishlistContent({required this.ids});

  final List<String> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    if (ids.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'Your VIP wishlist is empty. Discover our luxury collections.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
        ),
      );
    }

    return FutureBuilder<List<_WishlistItem>>(
      future: _fetchWishlistItems(ids),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load your wishlist right now.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.inkMuted,
                  ),
            ),
          );
        }
        final items = snapshot.data ?? const <_WishlistItem>[];
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'Your VIP wishlist is empty. Discover our luxury collections.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.inkMuted,
                    ),
              ),
            ),
          );
        }

        final width = MediaQuery.sizeOf(context).width;
        final crossAxisCount = width < kMobileBreakpoint
            ? 2
            : width < kTabletBreakpoint
                ? 3
                : 4;
        final gap = width < kMobileBreakpoint ? 10.0 : 16.0;
        final gapTotal = (crossAxisCount - 1) * gap;

        return SectionContainer(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 48, vertical: 28),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final childWidth = (constraints.maxWidth - gapTotal) / crossAxisCount;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: items.map((item) {
                  return SizedBox(
                    width: childWidth,
                    child: _WishlistCard(
                      item: item,
                      currencyLabel: l10n.currencyIqd,
                      isCompact: isMobile,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        );
      },
    );
  }
}

class _WishlistCard extends ConsumerWidget {
  const _WishlistCard({
    required this.item,
    required this.currencyLabel,
    required this.isCompact,
  });

  final _WishlistItem item;
  final String currencyLabel;
  final bool isCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = formatPriceWithCurrency(item.model.priceIqd, currencyLabel);
    final imageUrl = item.model.listingImageUrl.isNotEmpty
        ? item.model.listingImageUrl
        : (item.type == _WishlistType.perfume
            ? 'https://images.unsplash.com/photo-1594035910387-fea47794261f?auto=format&fit=crop&w=900&q=80'
            : 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (item.type == _WishlistType.perfume) {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => PerfumeAddonBottomSheet(
                perfume: PerfumeAddonData(
                  product: item.model,
                  brand: item.brand ?? 'Luxury Brand',
                ),
              ),
            );
            return;
          }
          showAddOnPersonalizationModal(context, item.model.id);
        },
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: AspectRatio(
                  aspectRatio: isCompact ? 1 : 1.08,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(imageUrl, fit: BoxFit.cover),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.85),
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: Icon(Icons.favorite, color: AppColors.rosePrimary, size: 20),
                            onPressed: () {
                              ref.read(authRepositoryProvider).toggleFavorite(item.model.id);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.type == _WishlistType.perfume && (item.brand ?? '').isNotEmpty)
                      Text(
                        item.brand!,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF9A7A2D),
                        ),
                      ),
                    if (item.type == _WishlistType.perfume && (item.brand ?? '').isNotEmpty)
                      const SizedBox(height: 6),
                    Text(
                      item.model.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      price,
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _WishlistType { bouquet, perfume }

class _WishlistItem {
  const _WishlistItem({
    required this.model,
    required this.type,
    this.brand,
  });

  final FlowerModel model;
  final _WishlistType type;
  final String? brand;
}

Future<List<_WishlistItem>> _fetchWishlistItems(List<String> ids) async {
  final uniqueIds = ids.toSet().toList(growable: false);
  final bouquetDocs = await _fetchByIds('bouquets', uniqueIds);
  final perfumeDocs = await _fetchByIds('perfumes', uniqueIds);

  final byId = <String, _WishlistItem>{};
  for (final doc in bouquetDocs) {
    byId[doc.id] = _WishlistItem(
      model: FlowerModel.fromJson(doc.id, doc.data()),
      type: _WishlistType.bouquet,
    );
  }
  for (final doc in perfumeDocs) {
    final data = doc.data();
    byId[doc.id] = _WishlistItem(
      model: FlowerModel.fromJson(doc.id, data),
      type: _WishlistType.perfume,
      brand: data['brand']?.toString(),
    );
  }

  return uniqueIds.where(byId.containsKey).map((id) => byId[id]!).toList(growable: false);
}

Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchByIds(
  String collection,
  List<String> ids,
) async {
  if (ids.isEmpty) return const [];
  const chunkSize = 10;
  final result = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  for (var i = 0; i < ids.length; i += chunkSize) {
    final chunk = ids.sublist(i, i + chunkSize > ids.length ? ids.length : i + chunkSize);
    final snap = await FirebaseFirestore.instance
        .collection(collection)
        .where(FieldPath.documentId, whereIn: chunk)
        .get();
    result.addAll(snap.docs);
  }
  return result;
}
