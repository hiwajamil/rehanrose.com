import 'package:intl/intl.dart';

/// Formats an IQD price with thousands separators (e.g. 25000 → "25,000").
String formatPriceIqd(int priceIqd) {
  return NumberFormat('#,###').format(priceIqd);
}

/// Returns a display string for IQD (e.g. 25000 → "IQD 25,000").
String iqdPriceString(int priceIqd) {
  return 'IQD ${formatPriceIqd(priceIqd)}';
}
