import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Minimalist CTA: Dark charcoal, rounded 8, white text, WhatsApp icon, no shadow.
class OrderViaWhatsAppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  /// Label: 'Order via WhatsApp' or Kurdish 'داواکردن بە نامە'.
  final String label;
  /// When false, button is disabled (e.g. when offline). Defaults to true.
  final bool enabled;

  const OrderViaWhatsAppButton({
    super.key,
    required this.onPressed,
    this.label = 'Order via WhatsApp',
    this.enabled = true,
  });

  /// Dark charcoal as specified (#1A1A1A).
  static const Color _buttonColor = Color(0xFF1A1A1A);

  /// Readable font on mobile; compact on desktop.
  static double _buttonFontSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).shortestSide;
    return width < 600 ? 18.0 : 16.0;
  }

  /// Minimum touch target height (Material guideline).
  static const double _minHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).shortestSide < 600;
    final fontSize = _buttonFontSize(context);
    final iconSize = isMobile ? 20.0 : 18.0;
    final padding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 20, vertical: 14)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ) ??
        TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        );

    final textChild = Text(
      label,
      style: textStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final effectiveOnPressed = enabled ? onPressed : null;

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Material(
        color: _buttonColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: effectiveOnPressed,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _minHeight),
            child: Padding(
              padding: padding,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(
                    FontAwesomeIcons.whatsapp,
                    color: Colors.white,
                    size: iconSize,
                  ),
                  SizedBox(width: isMobile ? 12 : 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: textChild,
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
