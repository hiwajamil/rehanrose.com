import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/controllers.dart';
import '../../../core/services/vendor_presence_platform.dart';

/// Wraps the vendor shell content and tracks online presence in Firestore.
/// Sets [isOnline: true] when the vendor is active, and [isOnline: false] on
/// app pause, tab close (web beforeunload), or dispose (e.g. sign out).
class VendorPresenceController extends ConsumerStatefulWidget {
  const VendorPresenceController({
    super.key,
    required this.vendorUid,
    required this.child,
  });

  final String vendorUid;
  final Widget child;

  @override
  ConsumerState<VendorPresenceController> createState() =>
      _VendorPresenceControllerState();
}

class _VendorPresenceControllerState extends ConsumerState<VendorPresenceController>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setOnline(true);
    final repo = ref.read(authRepositoryProvider);
    final uid = widget.vendorUid;
    registerVendorPresenceBeforeUnload(() {
      repo.setVendorOnline(uid, false);
    });
  }

  @override
  void dispose() {
    unregisterVendorPresenceBeforeUnload();
    _setOnline(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _setOnline(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _setOnline(false);
        break;
    }
  }

  void _setOnline(bool online) {
    ref.read(authRepositoryProvider).setVendorOnline(widget.vendorUid, online);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
