import '../../l10n/app_localizations.dart';

/// Returns the localized title for an emotion category [titleKey].
String localizedEmotionCategoryTitle(AppLocalizations l10n, String titleKey) {
  switch (titleKey) {
    case 'cat_love':
      return l10n.cat_love;
    case 'cat_apology':
      return l10n.cat_apology;
    case 'cat_gratitude':
      return l10n.cat_gratitude;
    case 'cat_sympathy':
      return l10n.cat_sympathy;
    case 'cat_wellness':
      return l10n.cat_wellness;
    case 'cat_celebration':
      return l10n.cat_celebration;
    case 'cat_birthday':
      return l10n.cat_birthday;
    case 'cat_anniversary':
      return l10n.cat_anniversary;
    case 'cat_newborn':
      return l10n.cat_newborn;
    case 'cat_wedding':
      return l10n.cat_wedding;
    default:
      return titleKey;
  }
}
