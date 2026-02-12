import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/connectivity_service.dart';

/// Global connectivity service instance. Stays alive for the app lifetime.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Current connectivity status: true when online, false when offline.
/// Rebuilds widgets when connectivity changes.
final connectivityStatusProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).isOnlineStream;
});
