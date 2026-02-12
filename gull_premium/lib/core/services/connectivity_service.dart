import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Exposes a stream of connectivity status: true when online, false when offline.
/// Uses [ConnectivityPlus] to listen to network changes.
class ConnectivityService {
  ConnectivityService() {
    _subscription = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    _init();
  }

  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  final _controller = StreamController<bool>.broadcast();
  bool? _lastValue;

  Stream<bool> get isOnlineStream => _controller.stream;

  void _onConnectivityChanged(List<ConnectivityResult> result) {
    final online = _isOnline(result);
    if (_lastValue != online) {
      _lastValue = online;
      _controller.add(online);
    }
  }

  Future<void> _init() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _lastValue = _isOnline(result);
      _controller.add(_lastValue!);
    } catch (_) {
      _lastValue = true;
      _controller.add(true);
    }
  }

  static bool _isOnline(List<ConnectivityResult> result) {
    if (result.isEmpty) return false;
    if (result.length == 1 && result.single == ConnectivityResult.none) return false;
    return true;
  }

  void dispose() {
    _subscription.cancel();
    _controller.close();
  }
}
