import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controllers/controllers.dart';
import '../../l10n/app_localizations.dart';

const String _localeKey = 'app_locale';
const String _defaultLanguageCode = 'en';

/// Supported language codes; must match [AppLocalizations.supportedLocales].
const List<String> kSupportedLanguageCodes = ['en', 'ku', 'ar'];

/// Initial locale resolved in main (prefs + optional Firestore when user logged in).
/// Override this in main when you have the resolved initial locale.
final initialLocaleProvider = Provider<Locale?>((ref) => null);

/// Current app locale. Persisted to SharedPreferences and Firestore (if logged in).
final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final initial = ref.watch(initialLocaleProvider);
    return initial ?? const Locale(_defaultLanguageCode);
  }

  SharedPreferences? _prefs;

  /// Set locale and persist to SharedPreferences and Firestore (if logged in).
  Future<void> setLocale(Locale locale) async {
    if (!kSupportedLanguageCodes.contains(locale.languageCode)) return;
    state = locale;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_localeKey, locale.languageCode);
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid != null) {
      await ref.read(authRepositoryProvider).setLanguage(uid, locale.languageCode);
    }
  }

  /// When user logs in, optionally sync locale from Firestore and overwrite local.
  Future<void> syncFromFirestoreIfLoggedIn() async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    final firestoreLang = await ref.read(authRepositoryProvider).getLanguage(uid);
    if (firestoreLang != null &&
        kSupportedLanguageCodes.contains(firestoreLang) &&
        state.languageCode != firestoreLang) {
      state = Locale(firestoreLang);
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_localeKey, firestoreLang);
    }
  }
}

/// Resolves the display name for the current locale (for language switcher).
String languageDisplayName(String languageCode, BuildContext context) {
  final l10n = AppLocalizations.of(context);
  if (l10n == null) return languageCode;
  switch (languageCode) {
    case 'en':
      return l10n.languageEnglish;
    case 'ku':
      return l10n.languageKurdish;
    case 'ar':
      return l10n.languageArabic;
    default:
      return languageCode;
  }
}
