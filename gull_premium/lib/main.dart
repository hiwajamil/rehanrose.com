import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'core/routing/app_router.dart';
import 'core/services/firebase_init.dart' as fb;
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

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
                    details.exceptionAsString(),
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
      await Firebase.initializeApp(
        options: options,
      );
      fb.setFirebaseInitialized(true);
    } catch (e, st) {
      debugPrint('Firebase.initializeApp failed: $e');
      debugPrintStack(stackTrace: st);
      fb.setFirebaseInitialized(false);
      // Continue so the app still shows; Firestore/Analytics will fail later.
    }

    runApp(const ProviderScope(child: MainApp()));
  }, (error, stack) {
    debugPrint('Uncaught error: $error');
    debugPrintStack(stackTrace: stack);
  });
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: AppRouter.router,
    );
  }
}
