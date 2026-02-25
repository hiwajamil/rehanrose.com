import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';
import '../data/models/order_model.dart';
import '../data/repositories/order_repository.dart';
import '../data/repositories/repositories.dart';

final omsOrderRepositoryProvider = Provider<OmsOrderRepository>((ref) {
  return OmsOrderRepository();
});

/// Stream of all OMS orders for admin (real-time).
final omsOrdersForAdminStreamProvider =
    StreamProvider.autoDispose<List<OmsOrderModel>>((ref) {
  return ref.read(omsOrderRepositoryProvider).watchOmsOrdersForAdmin();
});

/// Single stream of all OMS orders for the current vendor. Filter by status in UI to avoid 3 Firestore listeners.
/// Uses select on authStateProvider so the stream is only re-initialized when uid changes, not on every auth emission.
/// Not autoDispose so tab switches don't restart the stream.
final omsOrdersForVendorStreamProvider =
    StreamProvider<List<OmsOrderModel>>((ref) {
  final vendorId = ref.watch(authStateProvider.select((s) => s.value?.uid)) ?? '';
  if (vendorId.isEmpty) return Stream.value([]);
  final source = ref.read(omsOrderRepositoryProvider).watchOmsOrdersForVendor(vendorId: vendorId);
  return _distinctOrderList(_vendorStreamWithErrorFallback(source, ref));
});

/// On Firestore/permission/network error, emits [] so UI shows empty state instead of "Unable to load orders".
/// Cancels the source subscription when the provider is disposed to avoid dangling Firestore listeners.
Stream<List<OmsOrderModel>> _vendorStreamWithErrorFallback(
  Stream<List<OmsOrderModel>> source,
  Ref ref,
) {
  final c = StreamController<List<OmsOrderModel>>(sync: true);
  final sub = source.listen(
    c.add,
    onError: (Object e, StackTrace st) {
      debugPrint('OMS vendor orders stream error: $e');
      c.add([]);
    },
    onDone: c.close,
    cancelOnError: false,
  );
  ref.onDispose(sub.cancel);
  return c.stream;
}

/// Forwards only when order list content (orderId + status) actually changed.
/// Uses set-based comparison so ordering differences don't trigger duplicate emissions.
Stream<List<OmsOrderModel>> _distinctOrderList(Stream<List<OmsOrderModel>> source) async* {
  Set<String>? lastKeys;
  await for (final list in source) {
    final keys = list.map((o) => '${o.orderId}:${o.status.value}').toSet();
    if (lastKeys == null || lastKeys != keys) {
      lastKeys = keys;
      yield list;
    }
  }
}

/// Pending (new) OMS orders count for the current vendor. Used for notification badge.
/// Uses select so rebuilds only occur when the count changes, not when other orders update.
final vendorPendingOmsCountProvider = Provider<int>((ref) {
  return ref.watch(
    omsOrdersForVendorStreamProvider.select((async) => async.when(
          data: (list) => list.where((o) => o.status == OmsOrderStatus.pending).length,
          loading: () => 0,
          error: (_, __) => 0,
        )),
  );
});

/// Last-seen pending count: when the vendor opens the notification menu (or views orders),
/// we set this to the current pending count so the red badge disappears.
final vendorLastSeenPendingCountProvider =
    NotifierProvider<VendorLastSeenPendingCountNotifier, int>(
  VendorLastSeenPendingCountNotifier.new,
);

/// Unread badge count: max(0, pendingCount - lastSeen). Pass this to the header for the bell badge.
final vendorUnreadNotificationBadgeCountProvider = Provider<int>((ref) {
  final pending = ref.watch(vendorPendingOmsCountProvider);
  final lastSeen = ref.watch(vendorLastSeenPendingCountProvider);
  final diff = pending - lastSeen;
  return diff > 0 ? diff : 0;
});

class VendorLastSeenPendingCountNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setLastSeen(int value) {
    state = value;
  }
}
