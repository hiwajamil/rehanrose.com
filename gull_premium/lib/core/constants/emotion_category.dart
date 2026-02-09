import 'package:flutter/material.dart' show Color, IconData, Icons;

/// Primary emotion categories for flowers.
/// - id: database key (stored in Firestore as emotionCategoryId)
/// - titleKey: l10n key for translated display (e.g. cat_love)
/// - icon: visual icon for cards and dropdown
/// - color: soft background color hex
class EmotionCategory {
  const EmotionCategory({
    required this.id,
    required this.titleKey,
    required this.icon,
    required this.color,
  });
  final String id;
  final String titleKey;
  final IconData icon;
  final Color color;
}

/// All valid emotion category IDs (for strict validation).
const List<String> kEmotionCategoryIds = [
  'love',
  'apology',
  'gratitude',
  'sympathy',
  'wellness',
  'celebration',
];

/// Static list of emotion categories.
const List<EmotionCategory> kEmotionCategories = [
  EmotionCategory(
    id: 'love',
    titleKey: 'cat_love',
    icon: Icons.favorite_outlined,
    color: Color(0xFFFCE4EC), // soft pink
  ),
  EmotionCategory(
    id: 'apology',
    titleKey: 'cat_apology',
    icon: Icons.handshake_outlined,
    color: Color(0xFFE8F5E9), // soft green
  ),
  EmotionCategory(
    id: 'gratitude',
    titleKey: 'cat_gratitude',
    icon: Icons.eco_outlined,
    color: Color(0xFFE3F2FD), // soft blue
  ),
  EmotionCategory(
    id: 'sympathy',
    titleKey: 'cat_sympathy',
    icon: Icons.volunteer_activism_outlined,
    color: Color(0xFFF3E5F5), // soft purple
  ),
  EmotionCategory(
    id: 'wellness',
    titleKey: 'cat_wellness',
    icon: Icons.local_hospital_outlined,
    color: Color(0xFFFFF8E1), // soft amber
  ),
  EmotionCategory(
    id: 'celebration',
    titleKey: 'cat_celebration',
    icon: Icons.celebration_outlined,
    color: Color(0xFFFFECB3), // soft gold
  ),
];

/// Returns true if [id] is a valid emotion category ID.
bool isValidEmotionCategoryId(String? id) {
  if (id == null || id.isEmpty) return false;
  return kEmotionCategoryIds.contains(id);
}

/// Returns the [EmotionCategory] for the given [id], or null if invalid.
EmotionCategory? getEmotionCategoryById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final c in kEmotionCategories) {
    if (c.id == id) return c;
  }
  return null;
}

/// Code prefix for bouquet ID (e.g. Lo, Ap). Used when generating bouquet codes.
String codePrefixForEmotionCategoryId(String emotionCategoryId) {
  const prefixes = {
    'love': 'Lo',
    'apology': 'Ap',
    'gratitude': 'Gr',
    'sympathy': 'Sy',
    'wellness': 'We',
    'celebration': 'Ce',
  };
  return prefixes[emotionCategoryId] ?? '';
}
