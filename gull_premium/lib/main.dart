import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

import 'core/constants/breakpoints.dart';
import 'core/routing/app_router.dart';
import 'core/services/firebase_init.dart' as fb;
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'presentation/widgets/common/splash_screen.dart';

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
      // Never show raw exception strings (e.g. Pigeon/platform messages) to users.
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
      // On custom domain, fall back to default web config so Firestore/hosting still work.
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

    runApp(const ProviderScope(child: MainAppWithSplash()));
  }, (error, stack) {
    debugPrint('Uncaught error: $error');
    debugPrintStack(stackTrace: stack);
  });
}

/// Wraps the app with a splash screen that shows the mission statement.
class MainAppWithSplash extends StatefulWidget {
  const MainAppWithSplash({super.key});

  @override
  State<MainAppWithSplash> createState() => _MainAppWithSplashState();
}

class _MainAppWithSplashState extends State<MainAppWithSplash> {
  bool _splashComplete = false;

  @override
  Widget build(BuildContext context) {
    if (!_splashComplete) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(
          onComplete: () => setState(() => _splashComplete = true),
        ),
      );
    }
    return const MainApp();
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: isMobile ? AppTheme.lightMobile() : AppTheme.light(),
      routerConfig: AppRouter.router,
    );
  }
}
