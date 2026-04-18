import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seo/seo.dart';

import '../../../core/theme/app_colors.dart';
import '../custom_bouquet_request_sheet.dart';

/// First grid tile: same footprint as [FlowerCard], distinct cream “design your own” styling.
class CustomOrderCard extends StatefulWidget {
  const CustomOrderCard({
    super.key,
    this.isCompact = false,
    this.orderButtonEnabled = true,
  });

  final bool isCompact;
  final bool orderButtonEnabled;

  static const double _imageAspectRatio = 0.72;

  @override
  State<CustomOrderCard> createState() => _CustomOrderCardState();
}

class _CustomOrderCardState extends State<CustomOrderCard> {
  bool _hovered = false;

  static List<BoxShadow> get _cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 15,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get _cardShadowHover => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];

  static const double _hoverLiftPx = 4.0;
  static const Duration _hoverDuration = Duration(milliseconds: 220);

  void _openSheet() {
    showCustomBouquetRequestSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.isCompact ? 16.0 : 20.0;
    final contentPadding = widget.isCompact ? 12.0 : 16.0;
    final montserrat = GoogleFonts.montserrat();

    const creamTop = Color(0xFFF7F2EA);
    const creamMid = Color(0xFFFDF9F3);
    const accentLine = Color(0xFFC4A574);

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
                onTap: widget.orderButtonEnabled ? _openSheet : null,
                borderRadius: BorderRadius.circular(borderRadius),
                child: DefaultTextStyle(
                  style: montserrat,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Seo.text(
                        text: 'Design your own custom bouquet',
                        style: TextTagStyle.h2,
                        child: ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(borderRadius),
                          ),
                          child: AspectRatio(
                            aspectRatio: CustomOrderCard._imageAspectRatio,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [creamTop, creamMid, Color(0xFFF5EFE6)],
                                ),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _FloralOutlinePainter(
                                        color: accentLine.withValues(alpha: 0.22),
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.85),
                                            borderRadius: BorderRadius.circular(28),
                                            border: Border.all(
                                              color: accentLine.withValues(alpha: 0.45),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: accentLine.withValues(alpha: 0.12),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.add_rounded,
                                                size: 22,
                                                color: accentLine.withValues(alpha: 0.95),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Add',
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.inkCharcoal,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Icon(
                                          Icons.local_florist_outlined,
                                          size: 36,
                                          color: AppColors.rosePrimary.withValues(alpha: 0.35),
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
                            Seo.text(
                              text: 'Design Your Own',
                              style: TextTagStyle.h2,
                              child: Text(
                                'Design Your Own',
                                style: TextStyle(
                                  fontSize: widget.isCompact ? 15 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.inkCharcoal,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Custom bouquet',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.inkMuted.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Seo.text(
                              text: 'Custom Price',
                              style: TextTagStyle.p,
                              child: Text(
                                'Custom Price',
                                style: GoogleFonts.montserrat(
                                  fontSize: widget.isCompact ? 15 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.rosePrimary,
                                ),
                              ),
                            ),
                            SizedBox(height: widget.isCompact ? 10 : 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _CustomOrderCta(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    _openSheet();
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

class _CustomOrderCta extends StatefulWidget {
  const _CustomOrderCta({required this.onTap, required this.enabled});

  final VoidCallback onTap;
  final bool enabled;

  @override
  State<_CustomOrderCta> createState() => _CustomOrderCtaState();
}

class _CustomOrderCtaState extends State<_CustomOrderCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutBack,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.enabled ? widget.onTap : null,
          onHighlightChanged: (h) {
            if (mounted) setState(() => _pressed = h);
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: widget.enabled
                      ? const Color(0xFFB8892A)
                      : AppColors.inkMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
                Text(
                  'Request',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.enabled
                        ? AppColors.inkCharcoal
                        : AppColors.inkMuted.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: widget.enabled
                      ? AppColors.inkCharcoal
                      : AppColors.inkMuted.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Subtle curved stems / petals for the hero area (vector-free).
class _FloralOutlinePainter extends CustomPainter {
  _FloralOutlinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.08, h * 0.85)
      ..quadraticBezierTo(w * 0.15, h * 0.55, w * 0.35, h * 0.45)
      ..quadraticBezierTo(w * 0.5, h * 0.38, w * 0.62, h * 0.22)
      ..moveTo(w * 0.92, h * 0.78)
      ..quadraticBezierTo(w * 0.78, h * 0.5, w * 0.58, h * 0.42)
      ..quadraticBezierTo(w * 0.42, h * 0.35, w * 0.48, h * 0.12);

    canvas.drawPath(path, paint);

    final petal = Path()
      ..addOval(Rect.fromCenter(center: Offset(w * 0.48, h * 0.14), width: w * 0.14, height: h * 0.1));
    canvas.drawPath(petal, paint);

    final petal2 = Path()
      ..addOval(Rect.fromCenter(center: Offset(w * 0.62, h * 0.2), width: w * 0.11, height: h * 0.08));
    canvas.drawPath(petal2, paint);
  }

  @override
  bool shouldRepaint(covariant _FloralOutlinePainter oldDelegate) =>
      oldDelegate.color != color;
}
