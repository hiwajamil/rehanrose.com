import '../constants/emotion_categories.dart';

/// Prefer [codePrefixForEmotionValue] from emotion_categories.dart for new bouquet creation.
/// This is kept for backward compatibility only.
String getOccasionPrefix(String occasion) {
  final prefix = codePrefixForEmotionValue(occasion);
  if (prefix.isNotEmpty) return prefix;
  final trimmed = occasion.trim();
  if (trimmed.isEmpty) return '';
  final two = trimmed.length >= 2 ? trimmed.substring(0, 2) : trimmed;
  return two.toUpperCase();
}
