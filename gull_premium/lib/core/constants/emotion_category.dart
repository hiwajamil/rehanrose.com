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
  'birthday',
  'anniversary',
  'newborn',
  'wedding',
];

/// Static list of emotion categories (main page dropdown occasions).
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
  EmotionCategory(
    id: 'birthday',
    titleKey: 'cat_birthday',
    icon: Icons.cake_outlined,
    color: Color(0xFFFFE0E9), // birthday pink
  ),
  EmotionCategory(
    id: 'anniversary',
    titleKey: 'cat_anniversary',
    icon: Icons.favorite_rounded,
    color: Color(0xFFFCE4EC), // soft rose
  ),
  EmotionCategory(
    id: 'newborn',
    titleKey: 'cat_newborn',
    icon: Icons.child_care_outlined,
    color: Color(0xFFE1F5FE), // soft baby blue
  ),
  EmotionCategory(
    id: 'wedding',
    titleKey: 'cat_wedding',
    icon: Icons.diamond_outlined,
    color: Color(0xFFF3E5F5), // soft lavender
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
    'birthday': 'BD',
    'anniversary': 'AN',
    'newborn': 'NB',
    'wedding': 'WD',
  };
  return prefixes[emotionCategoryId] ?? '';
}

/// Canonical occasion label (English) for Firestore and vendor dropdown.
/// Single source of truth so vendor-selected occasion appears under the same occasion on the main page.
const Map<String, String> kOccasionLabelByEmotionCategoryId = {
  'love': 'Love',
  'apology': "I'm Sorry",
  'gratitude': 'Thank You',
  'sympathy': 'Sympathy',
  'wellness': 'Get Well',
  'celebration': 'Celebration',
  'birthday': 'Birthday',
  'anniversary': 'Anniversary',
  'newborn': 'New Born',
  'wedding': 'Wedding',
};

/// Display label for a bouquet's occasion (vendor list, detail). Prefers [emotionCategoryId], falls back to [occasion] string.
String occasionDisplayLabel({String? occasion, String? emotionCategoryId}) {
  if (emotionCategoryId != null && emotionCategoryId.isNotEmpty) {
    final label = kOccasionLabelByEmotionCategoryId[emotionCategoryId];
    if (label != null) return label;
  }
  return occasion?.trim().isNotEmpty == true ? occasion!.trim() : '';
}
