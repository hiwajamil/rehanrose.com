import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the latest auth state from [authStateProvider] so that [GoRouter]'s
/// redirect can read it without Riverpod ref, and so redirect re-runs when
/// auth state changes (via [refreshListenable]).
///
/// On web refresh, Firebase Auth restores the session asynchronously. While
/// auth is still loading, the router must not redirect away from the current
/// URL (e.g. /vendor/orders or /admin/analytics); otherwise the user is sent
/// to home. This notifier is updated by the app when [authStateProvider]
/// changes. The router's redirect returns null (stay) when [isLoading] is true.
class AuthRedirectNotifier extends ChangeNotifier {
  AsyncValue<fa.User?> _state = const AsyncValue.loading();

  AsyncValue<fa.User?> get currentState => _state;

  bool get isLoading => _state.isLoading;

  /// Called from the app when [authStateProvider] updates.
  void update(AsyncValue<fa.User?> state) {
    if (_state == state) return;
    _state = state;
    notifyListeners();
  }
}
