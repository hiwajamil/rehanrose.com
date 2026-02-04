import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Minimalist CTA: Dark charcoal, rounded 8, white text, WhatsApp icon, no shadow.
class OrderViaWhatsAppButton extends StatelessWidget {
  final VoidCallback onPressed;
  /// Label: 'Order via WhatsApp' or Kurdish 'داواکردن بە نامە'.
  final String label;

  const OrderViaWhatsAppButton({
    super.key,
    required this.onPressed,
    this.label = 'Order via WhatsApp',
  });

  /// Dark charcoal as specified (#1A1A1A).
  static const Color _buttonColor = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _buttonColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FaIcon(
                FontAwesomeIcons.whatsapp,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ) ??
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
