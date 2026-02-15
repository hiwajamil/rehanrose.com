import 'package:intl/intl.dart';

/// Formats an IQD price with thousands separators (e.g. 25000 → "25,000").
String formatPriceIqd(int priceIqd) {
  return NumberFormat('#,###').format(priceIqd);
}

/// Non-breaking space so currency and amount stay on the same line.
const _nbsp = '\u00A0';

/// Returns a display string for IQD (e.g. 25000 → "IQD 25,000").
String iqdPriceString(int priceIqd) {
  return 'IQD$_nbsp${formatPriceIqd(priceIqd)}';
}

/// Returns a display string with the given currency label (e.g. 25000, "دینار" → "دینار 25,000").
String formatPriceWithCurrency(int priceIqd, String currency) {
  return '$currency$_nbsp${formatPriceIqd(priceIqd)}';
}
