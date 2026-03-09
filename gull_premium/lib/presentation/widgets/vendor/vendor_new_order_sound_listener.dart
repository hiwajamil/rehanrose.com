import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/controllers.dart';
import '../../../core/services/notification_sound_service.dart';
import '../../../data/models/order_model.dart';

/// Listens to vendor OMS orders and plays the notification sound as soon as a NEW
/// pending order is detected (semantically: DocumentChangeType.added for this vendor).
/// Sound is triggered by the stream here, not by UI clicks. Plays on all routes so the
/// "Ding" is guaranteed the moment the database receives the order (Mobile, Tablet, Web).
class VendorNewOrderSoundListener extends ConsumerWidget {
  const VendorNewOrderSoundListener({super.key, required this.child});

  final Widget child;

  /// Order IDs present in [prevList]. Empty set if no previous data (initial load → no sound).
  static Set<String> _orderIds(List<OmsOrderModel> list) {
    return list.map((o) => o.orderId).toSet();
  }

  /// True when at least one pending order in [nextList] is newly added (not in [prevList]).
  static bool _hasNewPendingOrders(
    List<OmsOrderModel>? prevList,
    List<OmsOrderModel> nextList,
  ) {
    if (prevList == null) return false; // Initial load: do not play
    final prevIds = _orderIds(prevList);
    return nextList.any((o) =>
        o.status == OmsOrderStatus.pending && !prevIds.contains(o.orderId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<List<OmsOrderModel>>>(
      omsOrdersForVendorStreamProvider,
      (previous, next) {
        next.when(
          data: (nextList) {
            final prevList = previous?.value;
            if (!_hasNewPendingOrders(prevList, nextList)) return;
            // New order(s) detected → play sound immediately (cross-platform).
            playOrderNotificationSound();
          },
          loading: () {},
          error: (_, __) {},
        );
      },
    );
    return child;
  }
}
