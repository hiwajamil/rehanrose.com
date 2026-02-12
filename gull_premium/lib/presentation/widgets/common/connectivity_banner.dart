import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/connectivity_controller.dart';
import '../../../l10n/app_localizations.dart';

/// Bottom banner that shows "No Internet Connection" when offline (red) and
/// "Back Online" for 2 seconds when connectivity is restored (green).
class ConnectivityBanner extends ConsumerStatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  ConsumerState<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends ConsumerState<ConnectivityBanner> {
  bool _showBackOnline = false;
  Timer? _backOnlineTimer;
  bool _wasOffline = false;

  @override
  void dispose() {
    _backOnlineTimer?.cancel();
    super.dispose();
  }

  void _scheduleBackOnlineHide() {
    _backOnlineTimer?.cancel();
    _backOnlineTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showBackOnline = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityStatusProvider);
    final isOnline = connectivity.value ?? true;

    if (connectivity.hasValue) {
      if (!isOnline) {
        _wasOffline = true;
        _showBackOnline = false;
        _backOnlineTimer?.cancel();
      } else if (_wasOffline) {
        _wasOffline = false;
        _showBackOnline = true;
        _scheduleBackOnlineHide();
      }
    }

    if (!_showBackOnline && isOnline) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final isOfflineBanner = !isOnline;

    return Material(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isOfflineBanner
            ? Colors.red.shade700
            : Colors.green.shade700,
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Icon(
                isOfflineBanner ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isOfflineBanner
                      ? l10n.noInternetConnection
                      : l10n.backOnline,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
