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
    default:
      return titleKey;
  }
}
