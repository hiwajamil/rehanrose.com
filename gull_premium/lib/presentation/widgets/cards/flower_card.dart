import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../common/order_via_whatsapp_button.dart';

/// Bouquet card: static, no hover/transform/transition. Calm, premium experience.
/// When [isCompact] is true (mobile), uses reduced padding, capped image height, and smaller text.
/// Tapping anywhere on the card (image, title, price, or button) navigates to Product Details & Customization (/flower/:id/order).
class FlowerCard extends StatelessWidget {
  final String id;
  final String name;
  final String imageUrl;
  final String price;
  final String note;
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

  static const double _compactPadding = 10.0;
  /// Image aspect: 1:1 on compact (mobile) for balanced card height on narrow screens.
  static const double _compactImageAspect = 1.0;
  static const double _defaultImageAspect = 4 / 5;

  /// Single navigation target: Product Details & Customization (Vases, Chocolates, etc.).
  void _navigateToProductDetails(BuildContext context) {
    context.push('/flower/$id/order');
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = isCompact ? 14.0 : 24.0;
    final contentPadding = isCompact ? _compactPadding : 20.0;
    final imageAspect = isCompact ? _compactImageAspect : _defaultImageAspect;
    final cacheW = isCompact ? 360 : 400;
    final cacheH = isCompact ? 360 : 500;
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
              onTap: () => _navigateToProductDetails(context),
              borderRadius: BorderRadius.circular(borderRadius),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: imageAspect,
                    child: ClipRect(
                      child: Image.network(
                        imageUrl.isEmpty
                            ? 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80'
                            : imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        cacheWidth: cacheW,
                        cacheHeight: cacheH,
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: isCompact
                              ? Theme.of(context).textTheme.titleMedium
                              : Theme.of(context).textTheme.titleLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isCompact ? 2 : 6),
                        Text(
                          note,
                          style: isCompact
                              ? Theme.of(context).textTheme.bodySmall
                              : Theme.of(context).textTheme.bodyMedium,
                          maxLines: isCompact ? 1 : null,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isCompact ? 6 : 14),
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
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: contentPadding, vertical: 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: isCompact ? 8 : 16),
                        SizedBox(
                          width: double.infinity,
                          child: OrderViaWhatsAppButton(
                            onPressed: () =>
                                _navigateToProductDetails(context),
                          ),
                        ),
                        SizedBox(height: isCompact ? 4 : 10),
                        Text(
                          'Pay with FIB',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w600,
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
