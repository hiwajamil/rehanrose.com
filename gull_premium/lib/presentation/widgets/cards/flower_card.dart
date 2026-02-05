import 'package:flutter/material.dart';

import '../../../core/services/whatsapp_service.dart';
import '../../../core/theme/app_colors.dart';
import '../common/order_via_whatsapp_button.dart';

/// Bouquet card: static, no hover/transform/transition. Calm, premium experience.
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

  const FlowerCard({
    super.key,
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.note,
    this.onTap,
    this.bouquetCode,
  });

  /// Static shadow: no change on hover.
  static final List<BoxShadow> _cardShadow = [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: _cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
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
                            child: const Center(child: Icon(Icons.local_florist)),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            note,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            price,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 10),
                    Text(
                      'Pay with FIB',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 20),
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
