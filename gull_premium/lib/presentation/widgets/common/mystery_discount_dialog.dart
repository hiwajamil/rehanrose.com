import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MysteryDiscountDialog extends StatefulWidget {
  const MysteryDiscountDialog({super.key});

  static const String promoCode = 'VIP15';

  @override
  State<MysteryDiscountDialog> createState() => _MysteryDiscountDialogState();
}

class _MysteryDiscountDialogState extends State<MysteryDiscountDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HapticFeedback.heavyImpact();
    });
  }

  Future<void> _copyCodeAndClose() async {
    await Clipboard.setData(
      const ClipboardData(text: MysteryDiscountDialog.promoCode),
    );
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Promo code copied: VIP15'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C3428), Color(0xFF2D4A3E), Color(0xFFF7F2E8)],
            stops: [0.0, 0.48, 1.0],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 30,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0x33C9A962),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x66C9A962)),
              ),
              child: const Icon(
                CupertinoIcons.gift_fill,
                color: Color(0xFFC9A962),
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '✨ Surprise for our VIP!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Because you are one of our special customers, here is a 15% discount code valid for the next 48 hours.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 14.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFC9A962)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const SelectableText(
                MysteryDiscountDialog.promoCode,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4.5,
                  color: Color(0xFF1C3428),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _copyCodeAndClose,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy Code & Shop'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC9A962),
                  foregroundColor: const Color(0xFF1B2E1F),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
