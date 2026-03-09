// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rehan_rose/main.dart';
import 'package:rehan_rose/core/routing/app_router.dart';
import 'package:rehan_rose/core/routing/auth_redirect_notifier.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final authRedirectNotifier = AuthRedirectNotifier();
    final router = AppRouter.createRouter(authRedirectNotifier);
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        child: MainAppWithSplash(
          router: router,
          authRedirectNotifier: authRedirectNotifier,
        ),
      ),
    );

    // Verify that the app builds (MaterialApp is present).
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
