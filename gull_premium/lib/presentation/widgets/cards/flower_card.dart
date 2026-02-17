import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seo/seo.dart';

import '../../../controllers/controllers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../common/app_cached_image.dart';
import '../common/order_via_whatsapp_button.dart';
import '../common/product_info_column.dart';
import '../add_on_personalization_modal.dart';

/// Bouquet card: static, no hover/transform/transition. Calm, premium experience.
/// When [isCompact] is true (mobile), uses reduced padding, capped image height, and smaller text.
/// Tapping anywhere on the card (image, title, price, or button) opens the Add-on & Personalization modal.
class FlowerCard extends ConsumerWidget {
  final String id;
  final String name;
  final String imageUrl;
  final String price;
  final String note;
  /// When set, show strikethrough (sale: original price) and [price] as the sale price.
  final String? originalPrice;
  /// Optional bouquet code (e.g. RR-355) for admin reference in WhatsApp orders.
  final String? bouquetCode;
  /// When true, use compact layout for mobile grid (smaller padding, image height, text).
  final bool isCompact;
  /// When false, the Order via WhatsApp button is disabled (e.g. when offline). Defaults to true.
  final bool orderButtonEnabled;

  const FlowerCard({
    super.key,
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.note,
    this.originalPrice,
    this.bouquetCode,
    this.isCompact = false,
    this.orderButtonEnabled = true,
  });

  /// Subtle shadow so the card pops slightly (compact design).
  static final List<BoxShadow> _cardShadow = [
    const BoxShadow(
      color: Color(0x1A000000), // black12
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  static const double _compactPadding = 10.0;
  /// Image aspect: taller portrait for bouquet photos (smaller ratio = taller image).
  static const double _imageAspectRatio = 0.65;

  /// Opens the Add-on & Personalization modal (same as Order via WhatsApp).
  static void _openAddOnModal(BuildContext context, String flowerId) {
    showAddOnPersonalizationModal(context, flowerId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final borderRadius = isCompact ? 14.0 : 24.0;
    final contentPadding = isCompact ? _compactPadding : 20.0;
    final cacheW = isCompact ? 360 : 400;
    final cacheH = (cacheW / _imageAspectRatio).round();
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: AppColors.border),
          boxShadow: _cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openAddOnModal(context, id),
              borderRadius: BorderRadius.circular(borderRadius),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Seo.image(
                    alt: name,
                    src: imageUrl.isEmpty
                        ? 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80'
                        : imageUrl,
                    child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        child: AspectRatio(
                          aspectRatio: _imageAspectRatio,
                          child: AppCachedImage(
                            imageUrl: imageUrl.isEmpty
                                ? 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80'
                                : imageUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: cacheW,
                            memCacheHeight: cacheH,
                          ),
                        ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 8 : contentPadding,
                      vertical: isCompact ? 2 : 12,
                    ),
                    child: ProductInfoColumn(
                      code: bouquetCode,
                      name: name,
                      price: price,
                      originalPrice: originalPrice,
                      description: note.isNotEmpty ? note : null,
                      isDetailPage: false,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 8 : contentPadding,
                      vertical: 0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: isCompact ? 4 : 8),
                        SizedBox(
                          width: double.infinity,
                          child: OrderViaWhatsAppButton(
                            label: l10n.orderViaWhatsApp,
                            onPressed: () {
                              ref.read(analyticsServiceProvider).logClickWhatsApp(
                                    itemId: id,
                                    itemName: name,
                                  );
                              showAddOnPersonalizationModal(context, id);
                            },
                            enabled: orderButtonEnabled,
                          ),
                        ),
                        SizedBox(height: isCompact ? 4 : 10),
                        Center(
                          child: Text(
                            l10n.payWithFIB,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        SizedBox(height: isCompact ? 10 : 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
