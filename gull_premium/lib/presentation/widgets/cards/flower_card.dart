import 'package:flutter/material.dart';

import '../../../core/services/whatsapp_service.dart';
import '../../../core/theme/app_colors.dart';
import '../common/order_via_whatsapp_button.dart';

class FlowerCard extends StatefulWidget {
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

  @override
  State<FlowerCard> createState() => _FlowerCardState();
}

class _FlowerCardState extends State<FlowerCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..translateByDouble(0.0, _hovered ? -6.0 : 0.0, 0.0, 0.0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: _hovered
              ? [
                  const BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: widget.onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 4 / 5,
                      child: Image.network(
                        widget.imageUrl,
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
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.note,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            widget.price,
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
                          flowerName: widget.name,
                          flowerPrice: widget.price,
                          flowerId: widget.id,
                          flowerImageUrl: widget.imageUrl,
                          bouquetCode: widget.bouquetCode,
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
    ),
    );
  }
}
