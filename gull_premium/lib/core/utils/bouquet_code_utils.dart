/// Generates the two-letter uppercase prefix for a bouquet code from the occasion name.
/// Example: "Thank You" → "TH", "Birthday" → "BI".
String getOccasionPrefix(String occasion) {
  final trimmed = occasion.trim();
  if (trimmed.isEmpty) return '';
  final two = trimmed.length >= 2 ? trimmed.substring(0, 2) : trimmed;
  return two.toUpperCase();
}
