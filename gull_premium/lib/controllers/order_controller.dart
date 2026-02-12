import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/order_model.dart';
import '../data/repositories/repositories.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository();
});

/// Admin order list (newest first). Uses denormalized user fields — no user reads.
final adminOrdersProvider =
    FutureProvider.autoDispose<List<AdminOrderModel>>((ref) {
  return ref.read(orderRepositoryProvider).listOrdersForAdmin();
});

/// Real-time stream of admin orders. Uses denormalized user fields.
final adminOrdersStreamProvider =
    StreamProvider.autoDispose<List<AdminOrderModel>>((ref) {
  return ref.read(orderRepositoryProvider).watchOrdersForAdmin();
});
