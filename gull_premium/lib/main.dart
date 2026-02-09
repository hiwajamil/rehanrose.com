import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants/breakpoints.dart';
import 'core/routing/app_router.dart';
import 'core/services/firebase_init.dart' as fb;
import 'core/theme/app_theme.dart';
import 'controllers/controllers.dart';
import 'core/utils/locale_provider.dart';
import 'core/utils/material_localizations_fallback.dart';
import 'core/utils/rtl_utils.dart';
import 'data/repositories/auth_repository.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'presentation/widgets/common/splash_screen.dart';

const String _localePrefKey = 'app_locale';

/// Localization delegates with Kurdish (ku) fallbacks so Material/Cupertino
/// widgets work when [GlobalMaterialLocalizations] / [GlobalCupertinoLocalizations]
/// don't support ku. Fallback delegates must appear before the Global ones.
const List<LocalizationsDelegate<dynamic>> _localizationsDelegates = [
  AppLocalizations.delegate,
  MaterialLocalizationsKuFallbackDelegate(),
  CupertinoLocalizationsKuFallbackDelegate(),
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Surface errors instead of white screen: log and show in debug.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exception}');
      debugPrintStack(stackTrace: details.stack);
    };
    ErrorWidget.builder = (details) {
      final showDetails = kDebugMode;
      return Material(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    showDetails
                        ? details.exceptionAsString()
                        : 'Please refresh the page or try again later.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    };

    try {
      var options = DefaultFirebaseOptions.currentPlatform;
      if (kIsWeb &&
          (Uri.base.host == 'rehanrose.com' || Uri.base.host == 'www.rehanrose.com')) {
        options = DefaultFirebaseOptions.webCustomDomain;
      }
      await Firebase.initializeApp(options: options);
      fb.setFirebaseInitialized(true);
    } catch (e, st) {
      debugPrint('Firebase.initializeApp failed: $e');
      debugPrintStack(stackTrace: st);
      if (kIsWeb &&
          (Uri.base.host == 'rehanrose.com' || Uri.base.host == 'www.rehanrose.com')) {
        try {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
          fb.setFirebaseInitialized(true);
          debugPrint('Firebase initialized with default web config (fallback).');
        } catch (e2, st2) {
          debugPrint('Firebase fallback init failed: $e2');
          debugPrintStack(stackTrace: st2);
          fb.setFirebaseInitialized(false);
        }
      } else {
        fb.setFirebaseInitialized(false);
      }
    }

    // Resolve initial locale: SharedPreferences then Firestore (if logged in).
    // Wrap in try/catch so web (e.g. rehanrose.com) never gets stuck on white screen
    // if prefs or Firestore fail (storage disabled, CORS, etc.).
    Locale initialLocale = const Locale('en');
    try {
      final prefs = await SharedPreferences.getInstance();
      String? initialCode = prefs.getString(_localePrefKey);
      final user = fa.FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final repo = AuthRepository();
          final firestoreLang = await repo.getLanguage(user.uid);
          if (firestoreLang != null && kSupportedLanguageCodes.contains(firestoreLang)) {
            initialCode = firestoreLang;
          }
        } catch (_) {}
      }
      if (initialCode != null && kSupportedLanguageCodes.contains(initialCode)) {
        initialLocale = Locale(initialCode);
      }
    } catch (e, st) {
      debugPrint('Locale/prefs init failed (using en): $e');
      debugPrintStack(stackTrace: st);
    }

    runApp(ProviderScope(
      overrides: [
        initialLocaleProvider.overrideWith((ref) => initialLocale),
      ],
      child: const MainAppWithSplash(),
    ));
  }, (error, stack) {
    debugPrint('Uncaught error: $error');
    debugPrintStack(stackTrace: stack);
  });
}

/// Wraps the app with a splash screen that shows the mission statement.
class MainAppWithSplash extends ConsumerStatefulWidget {
  const MainAppWithSplash({super.key});

  @override
  ConsumerState<MainAppWithSplash> createState() => _MainAppWithSplashState();
}

class _MainAppWithSplashState extends ConsumerState<MainAppWithSplash> {
  bool _splashComplete = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (prev, next) {
      if (next.value != null) {
        ref.read(localeProvider.notifier).syncFromFirestoreIfLoggedIn();
      }
    });
    final locale = ref.watch(localeProvider);
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    final theme = isMobile
        ? AppTheme.lightMobile(locale)
        : AppTheme.light(locale);
    final direction = textDirectionForLocale(locale);

    if (!_splashComplete) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: _localizationsDelegates,
        theme: theme,
        builder: (context, child) => Directionality(
          textDirection: direction,
          child: child!,
        ),
        home: SplashScreen(
          onComplete: () => setState(() => _splashComplete = true),
        ),
      );
    }
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: _localizationsDelegates,
      theme: theme,
      builder: (context, child) => Directionality(
        textDirection: direction,
        child: child!,
      ),
      routerConfig: AppRouter.router,
    );
  }
}
