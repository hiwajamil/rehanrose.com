import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seo/seo.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants/breakpoints.dart';
import 'core/routing/app_router.dart';
import 'core/routing/auth_redirect_notifier.dart';
import 'core/services/firebase_init.dart' as fb;
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'controllers/controllers.dart';
import 'core/utils/locale_provider.dart';
import 'core/utils/material_localizations_fallback.dart';
import 'core/utils/rtl_utils.dart';
import 'data/repositories/auth_repository.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'presentation/widgets/common/connectivity_banner.dart';
import 'presentation/widgets/common/splash_screen.dart';
import 'presentation/pages/admin/admin_vendors_management_page.dart';

const String _localePrefKey = 'app_locale';
const bool _debugOnlyShowVendorsManagementPage = true;

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
                    style: GoogleFonts.montserrat(
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
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
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
      // Firebase Analytics is available; screen tracking via FirebaseAnalyticsObserver in AppRouter.
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

    if (kIsWeb) usePathUrlStrategy();

    // Router and auth notifier: redirect waits for auth to be determined so web
    // refresh keeps the user on the current URL (e.g. /vendor/orders, /admin/analytics).
    final authRedirectNotifier = AuthRedirectNotifier();
    final appRouter = AppRouter.createRouter(authRedirectNotifier);

    runApp(ProviderScope(
      overrides: [
        initialLocaleProvider.overrideWith((ref) => initialLocale),
      ],
      child: MainAppWithSplash(
        router: appRouter,
        authRedirectNotifier: authRedirectNotifier,
      ),
    ));
  }, (error, stack) {
    debugPrint('Uncaught error: $error');
    debugPrintStack(stackTrace: stack);
  });
}

/// Wraps the app with a splash screen that shows the mission statement.
class MainAppWithSplash extends ConsumerStatefulWidget {
  const MainAppWithSplash({
    super.key,
    required this.router,
    required this.authRedirectNotifier,
  });

  final GoRouter router;
  final AuthRedirectNotifier authRedirectNotifier;

  @override
  ConsumerState<MainAppWithSplash> createState() => _MainAppWithSplashState();
}

class _MainAppWithSplashState extends ConsumerState<MainAppWithSplash> {
  bool _splashComplete = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _customerOrderSubscription;
  final Map<String, String> _lastKnownOrderStatuses = {};
  String? _listenerUid;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeNotificationsAndListener());
  }

  Future<void> _initializeNotificationsAndListener() async {
    await NotificationService.instance.initialize();
    await NotificationService.instance.requestPermissions();
    await _configureOrderListenerForUser(ref.read(authStateProvider).value);
  }

  Future<void> _configureOrderListenerForUser(fa.User? user) async {
    final uid = user?.uid;
    if (_listenerUid == uid) return;

    await _customerOrderSubscription?.cancel();
    _customerOrderSubscription = null;
    _lastKnownOrderStatuses.clear();
    _listenerUid = uid;

    if (uid == null) return;

        _customerOrderSubscription = FirebaseFirestore.instance
        .collection('oms_orders')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        final orderId = change.doc.id;
        final newStatus = (data['status'] ?? '').toString().trim().toLowerCase();

        if (change.type == DocumentChangeType.removed) {
          _lastKnownOrderStatuses.remove(orderId);
          continue;
        }

        if (change.type == DocumentChangeType.added) {
          _lastKnownOrderStatuses[orderId] = newStatus;
          continue;
        }

        if (change.type == DocumentChangeType.modified) {
          final oldStatus = _lastKnownOrderStatuses[orderId];
          _lastKnownOrderStatuses[orderId] = newStatus;
          if (oldStatus == null || oldStatus == newStatus) continue;
          await _showOrderStatusNotificationForTransition(newStatus);
        }
      }
    });
  }

  Future<void> _showOrderStatusNotificationForTransition(String status) async {
    switch (status) {
      case 'preparing':
        await NotificationService.instance.showOrderStatusNotification(
          'Great News! 🌸',
          'Your luxury order is now being prepared by our artisan florists.',
        );
        return;
      case 'ready':
        await NotificationService.instance.showOrderStatusNotification(
          'Order Ready! ✨',
          'Your beautiful order is fully prepared and ready.',
        );
        return;
      default:
        return;
    }
  }

  @override
  void dispose() {
    _customerOrderSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep router's redirect in sync with auth so refresh on web preserves URL.
    widget.authRedirectNotifier.update(ref.read(authStateProvider));
    ref.listen(authStateProvider, (prev, next) {
      widget.authRedirectNotifier.update(next);
      if (next.value != null) {
        ref.read(localeProvider.notifier).syncFromFirestoreIfLoggedIn();
      }
      unawaited(_configureOrderListenerForUser(next.value));
    });
    final locale = ref.watch(localeProvider);
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    final baseTheme = isMobile ? AppTheme.lightMobile(locale) : AppTheme.light(locale);
    final theme = baseTheme.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
    final direction = textDirectionForLocale(locale);

    if (kDebugMode && _debugOnlyShowVendorsManagementPage) {
      return SeoController(
        enabled: true,
        tree: WidgetTree(context: context),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: _localizationsDelegates,
          theme: theme,
          builder: (context, child) => Directionality(
            textDirection: direction,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                child!,
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ConnectivityBanner(),
                ),
              ],
            ),
          ),
          home: const Scaffold(
            body: SafeArea(
              child: AdminVendorsManagementPage(),
            ),
          ),
        ),
      );
    }

    if (!_splashComplete) {
      return SeoController(
        enabled: true,
        tree: WidgetTree(context: context),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: _localizationsDelegates,
          theme: theme,
          builder: (context, child) => Directionality(
            textDirection: direction,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                child!,
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ConnectivityBanner(),
                ),
              ],
            ),
          ),
          home: SplashScreen(
            onComplete: () => setState(() => _splashComplete = true),
          ),
        ),
      );
    }
    return SeoController(
      enabled: true,
      tree: WidgetTree(context: context),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: _localizationsDelegates,
        theme: theme,
        builder: (context, child) => Directionality(
          textDirection: direction,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              child!,
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ConnectivityBanner(),
              ),
            ],
          ),
        ),
        routerConfig: widget.router,
      ),
    );
  }
}
