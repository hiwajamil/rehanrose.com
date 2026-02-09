import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Locale codes that Flutter's built-in delegates do not support (e.g. Kurdish).
/// For these we provide English fallbacks so Material/Cupertino widgets work.
const List<String> _kuFallbackLocales = ['ku'];

/// Provides [MaterialLocalizations] for locales (e.g. Kurdish 'ku') that
/// [GlobalMaterialLocalizations] does not support. Uses [DefaultMaterialLocalizations]
/// (US English) as fallback so Material widgets like [PopupMenuButton] and
/// [DropdownButton] work when the app locale is Kurdish.
class MaterialLocalizationsKuFallbackDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const MaterialLocalizationsKuFallbackDelegate();

  @override
  bool isSupported(Locale locale) =>
      _kuFallbackLocales.contains(locale.languageCode);

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture<MaterialLocalizations>(
        const DefaultMaterialLocalizations(),
      );

  @override
  bool shouldReload(MaterialLocalizationsKuFallbackDelegate old) => false;
}

/// Provides [CupertinoLocalizations] for locales (e.g. Kurdish 'ku') that
/// [GlobalCupertinoLocalizations] does not support. Uses [DefaultCupertinoLocalizations]
/// (US English) as fallback so Cupertino widgets work when the app locale is Kurdish.
class CupertinoLocalizationsKuFallbackDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const CupertinoLocalizationsKuFallbackDelegate();

  @override
  bool isSupported(Locale locale) =>
      _kuFallbackLocales.contains(locale.languageCode);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture<CupertinoLocalizations>(
        const DefaultCupertinoLocalizations(),
      );

  @override
  bool shouldReload(CupertinoLocalizationsKuFallbackDelegate old) => false;
}
