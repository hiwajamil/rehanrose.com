import 'package:flutter/material.dart';

import '../../../core/services/whatsapp_service.dart';
import '../../../core/theme/app_colors.dart';
import '../common/order_via_whatsapp_button.dart';

/// Bouquet card: static, no hover/transform/transition. Calm, premium experience.
/// When [isCompact] is true (mobile), uses reduced padding, capped image height, and smaller text.
class FlowerCard extends StatelessWidget {
  final String id;
  final String name;
  final String imageUrl;
  final String price;
  final String note;
  /// Optional. When set, tapping the card (image/title area) navigates to product detail.
  final VoidCallback? onTap;
  /// Optional bouquet code (e.g. RR-355) for admin reference in WhatsApp orders.
  final String? bouquetCode;
  /// When true, use compact layout for mobile grid (smaller padding, image height, text).
  final bool isCompact;

  const FlowerCard({
    super.key,
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.note,
    this.onTap,
    this.bouquetCode,
    this.isCompact = false,
  });

  /// Static shadow: no change on hover.
  static final List<BoxShadow> _cardShadow = [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  static const double _compactPadding = 12.0;

  @override
  Widget build(BuildContext context) {
    final borderRadius = isCompact ? 16.0 : 24.0;
    final contentPadding = isCompact ? _compactPadding : 20.0;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    isCompact
                        ? AspectRatio(
                            aspectRatio: 4 / 5,
                            child: ClipRect(
                              child: Image.network(
                                imageUrl.isEmpty
                                    ? 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80'
                                    : imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                cacheWidth: 400,
                                cacheHeight: 500,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: AppColors.border,
                                  child: const Center(
                                      child: Icon(Icons.local_florist)),
                                ),
                              ),
                            ),
                          )
                        : AspectRatio(
                            aspectRatio: 4 / 5,
                            child: ClipRect(
                              child: Image.network(
                                imageUrl.isEmpty
                                    ? 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80'
                                    : imageUrl,
                                fit: BoxFit.cover,
                                cacheWidth: 400,
                                cacheHeight: 500,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: AppColors.border,
                                  child: const Center(
                                      child: Icon(Icons.local_florist)),
                                ),
                              ),
                            ),
                          ),
                    Padding(
                      padding: EdgeInsets.all(contentPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: isCompact
                                ? Theme.of(context).textTheme.titleMedium
                                : Theme.of(context).textTheme.titleLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isCompact ? 4 : 6),
                          Text(
                            note,
                            style: isCompact
                                ? Theme.of(context).textTheme.bodySmall
                                : Theme.of(context).textTheme.bodyMedium,
                            maxLines: isCompact ? 2 : null,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isCompact ? 8 : 14),
                          Text(
                            price,
                            style: (isCompact
                                    ? Theme.of(context).textTheme.bodyMedium
                                    : Theme.of(context).textTheme.bodyLarge)
                                ?.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: contentPadding, vertical: 0),
                child: Column(
                  children: [
                    SizedBox(height: isCompact ? 10 : 16),
                    SizedBox(
                      width: double.infinity,
                      child: OrderViaWhatsAppButton(
                        onPressed: () => launchOrderWhatsApp(
                          flowerName: name,
                          flowerPrice: price,
                          flowerId: id,
                          flowerImageUrl: imageUrl,
                          bouquetCode: bouquetCode,
                        ),
                      ),
                    ),
                    SizedBox(height: isCompact ? 6 : 10),
                    Text(
                      'Pay with FIB',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    SizedBox(height: isCompact ? 12 : 20),
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
