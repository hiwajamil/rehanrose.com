import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seo/seo.dart';

import '../../../controllers/controllers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../common/app_cached_image.dart';
import '../common/order_via_whatsapp_button.dart';
import '../common/product_info_column.dart';
import '../add_on_personalization_modal.dart';

/// Bouquet card with premium hover: lift, image zoom, deeper shadow, smooth transitions.
/// When [isCompact] is true (mobile), uses reduced padding, capped image height, and smaller text.
/// Tapping anywhere on the card opens the Add-on & Personalization modal.
class FlowerCard extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<FlowerCard> createState() => _FlowerCardState();
}

class _FlowerCardState extends ConsumerState<FlowerCard> {
  bool _hovered = false;

  /// Subtle shadow so the card pops slightly (compact design).
  static final List<BoxShadow> _cardShadow = [
    const BoxShadow(
      color: Color(0x1A000000), // black12
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  /// Deeper shadow on hover to enhance lift feel.
  static final List<BoxShadow> _cardShadowHover = [
    const BoxShadow(
      color: Color(0x22000000),
      blurRadius: 14,
      offset: Offset(0, 6),
      spreadRadius: 0,
    ),
  ];

  static const double _compactPadding = 10.0;
  static const double _hoverLiftPx = 8.0;
  static const double _hoverImageScale = 1.08;
  static const Duration _hoverDuration = Duration(milliseconds: 250);

  /// Image aspect: taller portrait for bouquet photos (smaller ratio = taller image).
  static const double _imageAspectRatio = 0.65;

  /// Opens the Add-on & Personalization modal (same as Order via WhatsApp).
  static void _openAddOnModal(BuildContext context, String flowerId) {
    showAddOnPersonalizationModal(context, flowerId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final borderRadius = widget.isCompact ? 14.0 : 24.0;
    final contentPadding = widget.isCompact ? _compactPadding : 20.0;
    final cacheW = widget.isCompact ? 360 : 400;
    final cacheH = (cacheW / _imageAspectRatio).round();
    final montserrat = GoogleFonts.montserrat();

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: _hoverDuration,
          curve: Curves.easeInOut,
          transform: Matrix4.translationValues(0, _hovered ? -_hoverLiftPx : 0, 0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppColors.border),
            boxShadow: _hovered ? _cardShadowHover : _cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openAddOnModal(context, widget.id),
                borderRadius: BorderRadius.circular(borderRadius),
                child: DefaultTextStyle(
                  style: montserrat,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Seo.image(
                        alt: widget.name,
                        src: widget.imageUrl.isEmpty
                            ? 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80'
                            : widget.imageUrl,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          child: AspectRatio(
                            aspectRatio: _imageAspectRatio,
                            child: AnimatedScale(
                              scale: _hovered ? _hoverImageScale : 1.0,
                              duration: _hoverDuration,
                              curve: Curves.easeInOut,
                              alignment: Alignment.center,
                              child: AppCachedImage(
                                imageUrl: widget.imageUrl.isEmpty
                                    ? 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80'
                                    : widget.imageUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: cacheW,
                                memCacheHeight: cacheH,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.isCompact ? 8 : contentPadding,
                          vertical: widget.isCompact ? 2 : 12,
                        ),
                        child: ProductInfoColumn(
                          code: widget.bouquetCode,
                          name: widget.name,
                          price: widget.price,
                          originalPrice: widget.originalPrice,
                          description: widget.note.isNotEmpty ? widget.note : null,
                          isDetailPage: false,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.isCompact ? 8 : contentPadding,
                          vertical: 0,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: widget.isCompact ? 4 : 8),
                            SizedBox(
                              width: double.infinity,
                              child: OrderViaWhatsAppButton(
                                label: l10n.orderViaWhatsApp,
                                onPressed: () {
                                  ref.read(analyticsServiceProvider).logClickWhatsApp(
                                        itemId: widget.id,
                                        itemName: widget.name,
                                      );
                                  showAddOnPersonalizationModal(context, widget.id);
                                },
                                enabled: widget.orderButtonEnabled,
                              ),
                            ),
                            SizedBox(height: widget.isCompact ? 4 : 10),
                            Center(
                              child: Text(
                                l10n.payWithFIB,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.ink,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            SizedBox(height: widget.isCompact ? 10 : 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
