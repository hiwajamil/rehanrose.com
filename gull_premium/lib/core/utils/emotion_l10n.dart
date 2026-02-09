import '../../l10n/app_localizations.dart';

/// Maps emotion value (Firestore) to localized label key.
/// Used so we keep storing 'birthday', 'wedding', etc. and only change display.
String localizedEmotionLabel(AppLocalizations l10n, String emotionValue) {
  switch (emotionValue) {
    case 'birthday':
      return l10n.emotionCelebrateThem;
    case 'wedding':
      return l10n.emotionForeverBegins;
    case 'sympathy':
      return l10n.emotionImHere;
    case 'thank_you':
      return l10n.emotionWithGratitude;
    case 'friendship':
      return l10n.emotionJustBecause;
    case 'congratulations':
      return l10n.emotionWellDeserved;
    case 'anniversary':
      return l10n.emotionStillYou;
    case 'miss_you':
      return l10n.emotionThinkingOfYou;
    default:
      return emotionValue;
  }
}

/// Ordered list of emotion values for dropdown/filters (same order as kEmotions).
const List<String> kEmotionValuesOrdered = [
  'birthday',
  'wedding',
  'sympathy',
  'thank_you',
  'friendship',
  'congratulations',
  'anniversary',
  'miss_you',
];
