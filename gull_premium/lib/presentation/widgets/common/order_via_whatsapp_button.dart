import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../l10n/app_localizations.dart';

/// Minimalist CTA: Dark charcoal, rounded 8, white text, WhatsApp icon, no shadow.
class OrderViaWhatsAppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  /// Label: 'Order via WhatsApp' or Kurdish 'داواکردن بە نامە'.
  final String label;
  /// When false, button is disabled (e.g. when offline). Defaults to true.
  final bool enabled;
  /// When true, button looks disabled (opacity/grey) but onTap still fires (e.g. to show a SnackBar). Defaults to false.
  final bool appearsDisabled;
  /// Value proposition shown below the button. Set to empty string to hide. When null, uses localized "Includes Free Voice Message QR Code".
  final String? valueProposition;

  const OrderViaWhatsAppButton({
    super.key,
    required this.onPressed,
    this.label = 'Order via WhatsApp',
    this.enabled = true,
    this.appearsDisabled = false,
    this.valueProposition,
  });

  /// WhatsApp brand green (#25D366).
  static const Color _buttonColor = Color(0xFF25D366);

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
    final showDisabledStyle = !enabled || appearsDisabled;

    final button = Opacity(
      opacity: showDisabledStyle ? 0.5 : 1.0,
      child: Material(
        color: showDisabledStyle && appearsDisabled
            ? const Color(0xFF9E9E9E)
            : _buttonColor,
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

    final l10n = AppLocalizations.of(context)!;
    final subtitleText = valueProposition == null
        ? l10n.includesFreeVoiceMessageQRCode
        : valueProposition!;
    if (subtitleText.isEmpty) {
      return button;
    }

    final mutedColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65);
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: mutedColor,
          fontSize: isMobile ? 12.0 : 11.0,
          fontWeight: FontWeight.w500,
        ) ??
        TextStyle(
          color: mutedColor,
          fontSize: isMobile ? 12.0 : 11.0,
          fontWeight: FontWeight.w500,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        button,
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_2, size: 14, color: mutedColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  subtitleText,
                  style: subtitleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
