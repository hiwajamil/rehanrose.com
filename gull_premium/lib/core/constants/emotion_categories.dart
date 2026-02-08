import 'package:flutter/material.dart' show IconData, Icons;

/// Single source of truth for emotion-based categories.
/// - label → user-facing (UI)
/// - value → stored in Firestore (normalized)
/// - codePrefix → used for bouquet auto-ID (e.g. Bi-1, We-2)
/// - icon → optional icon for dropdown and filter UI
class EmotionEntry {
  const EmotionEntry({
    required this.label,
    required this.value,
    required this.codePrefix,
    this.icon,
  });
  final String label;
  final String value;
  final String codePrefix;
  final IconData? icon;
}

const List<EmotionEntry> kEmotions = [
  EmotionEntry(label: 'Celebrate Them', value: 'birthday', codePrefix: 'Bi', icon: Icons.cake_outlined),
  EmotionEntry(label: 'Forever Begins', value: 'wedding', codePrefix: 'We', icon: Icons.favorite_outlined),
  EmotionEntry(label: "I'm Here", value: 'sympathy', codePrefix: 'Sy', icon: Icons.volunteer_activism_outlined),
  EmotionEntry(label: 'With Gratitude', value: 'thank_you', codePrefix: 'Th', icon: Icons.eco_outlined),
  EmotionEntry(label: 'Just Because', value: 'friendship', codePrefix: 'Fr', icon: Icons.local_florist_outlined),
  EmotionEntry(label: 'Well Deserved', value: 'congratulations', codePrefix: 'Co', icon: Icons.emoji_events_outlined),
  EmotionEntry(label: 'Still You', value: 'anniversary', codePrefix: 'An', icon: Icons.favorite_rounded),
  EmotionEntry(label: 'Thinking of You', value: 'miss_you', codePrefix: 'Mi', icon: Icons.send_outlined),
];

/// All valid emotion values (for validation and queries).
List<String> get kEmotionValues =>
    kEmotions.map((e) => e.value).toList();

/// User-facing labels in order (for dropdowns and filter cards).
List<String> get kEmotionLabels =>
    kEmotions.map((e) => e.label).toList();

/// Legacy Firestore occasion values → normalized emotion value.
/// Used for backward compatibility when reading/querying old bouquets.
const Map<String, String> kLegacyOccasionToEmotion = {
  'Birthday': 'birthday',
  'Wedding': 'wedding',
  'Sympathy': 'sympathy',
  'Thank You': 'thank_you',
  'Friendship': 'friendship',
  'Congratulations': 'congratulations',
  'Anniversary': 'anniversary',
  'Miss You': 'miss_you',
};

/// Normalize a stored occasion/emotion value to the canonical emotion value.
/// Handles legacy "Birthday" and new "birthday" both → "birthday".
String normalizeToEmotionValue(String? stored) {
  if (stored == null || stored.trim().isEmpty) return '';
  final t = stored.trim();
  return kLegacyOccasionToEmotion[t] ?? t;
}

/// Code prefix for bouquet ID (e.g. Bi, We). Uses [kEmotions] codePrefix.
String codePrefixForEmotionValue(String emotionValue) {
  final normalized = normalizeToEmotionValue(emotionValue);
  if (normalized.isEmpty) return '';
  for (final e in kEmotions) {
    if (e.value == normalized) return e.codePrefix;
  }
  return '';
}

/// Display label for a stored occasion/emotion value (vendor list, detail).
String labelForEmotionValue(String? stored) {
  final value = normalizeToEmotionValue(stored);
  if (value.isEmpty) return stored ?? '';
  for (final e in kEmotions) {
    if (e.value == value) return e.label;
  }
  return stored ?? '';
}

/// Emotion value for a given label (e.g. "Celebrate Them" → "birthday").
String? emotionValueForLabel(String label) {
  for (final e in kEmotions) {
    if (e.label == label) return e.value;
  }
  return null;
}

/// Icon for a given emotion label (for dropdowns and filters).
IconData? iconForEmotionLabel(String label) {
  for (final e in kEmotions) {
    if (e.label == label) return e.icon;
  }
  return null;
}

/// For Firestore query: possible stored values when filtering by emotion.
/// New data uses value ("birthday"); old data may use "Birthday".
List<String> storedValuesForFilter(String emotionValue) {
  final normalized = normalizeToEmotionValue(emotionValue);
  if (normalized.isEmpty) return [];
  final legacyKeys = kLegacyOccasionToEmotion.entries
      .where((e) => e.value == normalized)
      .map((e) => e.key)
      .toList();
  final result = <String>[normalized];
  for (final k in legacyKeys) {
    if (k != normalized) result.add(k);
  }
  return result;
}

// --- Legacy compatibility for existing code that used kEmotionToOccasion etc. ---

/// Emotion label → Firestore value (legacy: now we use emotion value).
/// Prefer [emotionValueForLabel] and [kEmotions].
const Map<String, String> kEmotionToOccasion = {
  'Celebrate Them': 'birthday',
  'Forever Begins': 'wedding',
  "I'm Here": 'sympathy',
  'With Gratitude': 'thank_you',
  'Just Because': 'friendship',
  'Well Deserved': 'congratulations',
  'Still You': 'anniversary',
  'Thinking of You': 'miss_you',
};

/// First dropdown label that maps to [occasion/emotion value]. Null if no match (e.g. "All").
String? dropdownLabelForOccasion(String occasionOrValue) {
  if (occasionOrValue.isEmpty || occasionOrValue == 'All') return null;
  final value = normalizeToEmotionValue(occasionOrValue);
  if (value.isEmpty) return null;
  for (final e in kEmotions) {
    if (e.value == value) return e.label;
  }
  return null;
}

/// Landing page dropdown: same emotion labels (no emojis for consistency with vendor).
const List<String> kDropdownEmotionLabels = [
  'Celebrate Them',
  'Forever Begins',
  "I'm Here",
  'With Gratitude',
  'Just Because',
  'Well Deserved',
  'Still You',
  'Thinking of You',
];

const Map<String, String> kDropdownEmotionToOccasion = {
  'Celebrate Them': 'birthday',
  'Forever Begins': 'wedding',
  "I'm Here": 'sympathy',
  'With Gratitude': 'thank_you',
  'Just Because': 'friendship',
  'Well Deserved': 'congratulations',
  'Still You': 'anniversary',
  'Thinking of You': 'miss_you',
};

/// Search keywords (feeling words) mapped to emotion value.
const Map<String, String> kSearchKeywordToOccasion = {
  'love': 'anniversary',
  'apology': 'sympathy',
  'gratitude': 'thank_you',
  'thanks': 'thank_you',
  'thank': 'thank_you',
  'birthday': 'birthday',
  'wedding': 'wedding',
  'sympathy': 'sympathy',
  'sorry': 'sympathy',
  'condolence': 'sympathy',
  'friendship': 'friendship',
  'friend': 'friendship',
  'congrats': 'congratulations',
  'congratulations': 'congratulations',
  'anniversary': 'anniversary',
  'miss': 'miss_you',
  'thinking': 'miss_you',
};

/// Resolves a search query or emotion label to emotion value. Returns null if no match.
String? resolveQueryToOccasion(String query) {
  final trimmed = query.trim().toLowerCase();
  if (trimmed.isEmpty) return null;
  for (final entry in kEmotionToOccasion.entries) {
    if (entry.key.toLowerCase() == trimmed) return entry.value;
  }
  for (final entry in kSearchKeywordToOccasion.entries) {
    if (trimmed.contains(entry.key)) return entry.value;
  }
  for (final value in kEmotionToOccasion.values) {
    if (value.toLowerCase() == trimmed) return value;
  }
  return null;
}
