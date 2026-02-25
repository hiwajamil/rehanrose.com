import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../controllers/controllers.dart';
import '../../../core/services/notification_sound_service.dart';
import '../../../data/models/order_model.dart';

/// Listens to vendor OMS orders and plays a sound when the number of pending (new) orders increases.
/// Skips sound when the vendor is already on the Orders page. Place inside the vendor shell.
class VendorNewOrderSoundListener extends ConsumerWidget {
  const VendorNewOrderSoundListener({super.key, required this.child});

  final Widget child;


  static int _pendingCount(List<OmsOrderModel> list) {
    return list.where((o) => o.status == OmsOrderStatus.pending).length;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<List<OmsOrderModel>>>(
      omsOrdersForVendorStreamProvider,
      (previous, next) {
        next.when(
          data: (nextList) {
            final count = _pendingCount(nextList);
            final prevCount = previous?.value != null
                ? _pendingCount(previous!.value!)
                : null;
            if (prevCount == null || count <= prevCount) return;
            if (context.mounted &&
                GoRouterState.of(context).uri.path != '/vendor/orders') {
              playOrderNotificationSound();
            }
          },
          loading: () {},
          error: (_, __) {},
        );
      },
    );
    return child;
  }
}
