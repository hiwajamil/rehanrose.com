import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seo/seo.dart';

import '../../../controllers/controllers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../common/app_cached_image.dart';
import '../add_on_personalization_modal.dart';

/// Luxury minimalist bouquet card: image-led (~70% height), glassmorphism badge,
/// elegant typography, subtle shadow, minimal action row.
/// Tapping the card or "Order" opens the Add-on & Personalization modal.
class FlowerCard extends ConsumerStatefulWidget {
  final String id;
  final String name;
  final String imageUrl;
  final String price;
  final String note;
  final String? originalPrice;
  final String? bouquetCode;
  final bool isCompact;
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

  /// Soft diffuse shadow for luxury feel.
  static List<BoxShadow> get _cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 15,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get _cardShadowHover => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 6),
          spreadRadius: 0,
        ),
      ];

  static const double _hoverLiftPx = 4.0;
  static const double _hoverImageScale = 1.03;
  static const Duration _hoverDuration = Duration(milliseconds: 220);

  /// Image aspect: taller so image occupies ~70% of card with compact footer.
  static const double _imageAspectRatio = 0.72;

  static void _openAddOnModal(BuildContext context, String flowerId) {
    showAddOnPersonalizationModal(context, flowerId);
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.isCompact ? 16.0 : 20.0;
    final contentPadding = widget.isCompact ? 12.0 : 16.0;
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
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hovered ? -_hoverLiftPx : 0, 0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(borderRadius),
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
                      // —— Image ~70% height, rounded top, cover ———
                      Seo.image(
                        alt: widget.name,
                        src: widget.imageUrl.isEmpty
                            ? 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80'
                            : widget.imageUrl,
                        child: ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(borderRadius),
                          ),
                          child: AspectRatio(
                            aspectRatio: _imageAspectRatio,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                AnimatedScale(
                                  scale: _hovered ? _hoverImageScale : 1.0,
                                  duration: _hoverDuration,
                                  curve: Curves.easeOut,
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
                                // Glassmorphism badge: Free QR Voice
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: _VoiceQrBadge(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // —— White bottom area: code (subtle), name, price, actions ———
                      Container(
                        color: Colors.white,
                        padding: EdgeInsets.fromLTRB(
                          contentPadding,
                          widget.isCompact ? 8 : 12,
                          contentPadding,
                          widget.isCompact ? 10 : 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.bouquetCode != null &&
                                widget.bouquetCode!.isNotEmpty) ...[
                              Seo.text(
                                text: '#${widget.bouquetCode}',
                                style: TextTagStyle.p,
                                child: Text(
                                  '#${widget.bouquetCode}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.inkMuted
                                        .withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            // Product name: focal, 1 line
                            Seo.text(
                              text: widget.name,
                              style: TextTagStyle.h2,
                              child: Text(
                                widget.name,
                                style: TextStyle(
                                  fontSize: widget.isCompact ? 15 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.inkCharcoal,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.originalPrice != null &&
                                widget.originalPrice!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.originalPrice!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkMuted,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: AppColors.inkMuted,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            // Price: brand rose
                            Seo.text(
                              text: widget.price,
                              style: TextTagStyle.p,
                              child: Text(
                                widget.price,
                                style: GoogleFonts.montserrat(
                                  fontSize: widget.isCompact ? 15 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.rosePrimary,
                                ),
                              ),
                            ),
                            SizedBox(height: widget.isCompact ? 10 : 12),
                            // Minimal action row: Order > on right, or two icon buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _OrderCtaButton(
                                  onTap: () {
                                    ref
                                        .read(analyticsServiceProvider)
                                        .logClickWhatsApp(
                                          itemId: widget.id,
                                          itemName: widget.name,
                                        );
                                    _openAddOnModal(context, widget.id);
                                  },
                                  enabled: widget.orderButtonEnabled,
                                ),
                              ],
                            ),
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

/// Glassmorphism badge: "Free QR Voice" with microphone icon.
class _VoiceQrBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mic_none_rounded,
                size: 14,
                color: Colors.white.withOpacity(0.95),
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)?.freeQrVoice ?? 'Free QR Voice',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.95),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal "Order >" CTA with WhatsApp icon.
class _OrderCtaButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool enabled;

  const _OrderCtaButton({
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                FontAwesomeIcons.whatsapp,
                size: 18,
                color: enabled
                    ? const Color(0xFF25D366)
                    : AppColors.inkMuted.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)?.order ?? 'Order',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? AppColors.inkCharcoal
                      : AppColors.inkMuted.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: enabled
                    ? AppColors.inkCharcoal
                    : AppColors.inkMuted.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
