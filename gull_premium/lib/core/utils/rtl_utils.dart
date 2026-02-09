import 'package:flutter/material.dart';

/// Whether the current locale is RTL (Arabic or Kurdish).
bool isRTL(BuildContext context) {
  return Directionality.of(context) == TextDirection.rtl;
}

/// Returns [TextDirection.rtl] for Arabic and Kurdish, [TextDirection.ltr] otherwise.
TextDirection textDirectionForLocale(Locale locale) {
  final code = locale.languageCode;
  if (code == 'ar' || code == 'ku') return TextDirection.rtl;
  return TextDirection.ltr;
}

/// Wraps a directional icon (back, arrow, chevron) so it flips in RTL.
/// Do not use for decorative icons.
Widget directionalIcon(BuildContext context, IconData icon, {
  double? size,
  Color? color,
}) {
  final rtl = isRTL(context);
  return Transform.scale(
    scaleX: rtl ? -1 : 1,
    child: Icon(icon, size: size, color: color),
  );
}
