import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bouquets_controller.dart';
import 'oms_order_controller.dart';

/// Stats for an approved vendor (bouquet count, completed orders, revenue).
class VendorStats {
  final int bouquetCount;
  final int completedOrders;
  final num totalRevenue;

  const VendorStats({
    required this.bouquetCount,
    required this.completedOrders,
    required this.totalRevenue,
  });
}

/// Future provider for vendor stats. Fetches bouquet count and OMS delivered stats.
final vendorStatsProvider =
    FutureProvider.autoDispose.family<VendorStats, String>((ref, vendorId) async {
  final bouquetRepo = ref.read(bouquetRepositoryProvider);
  final omsRepo = ref.read(omsOrderRepositoryProvider);
  final bouquetCount = await bouquetRepo.countApprovedBouquetsByVendor(vendorId);
  final omsStats = await omsRepo.getVendorDeliveredStats(vendorId);
  return VendorStats(
    bouquetCount: bouquetCount,
    completedOrders: omsStats.count,
    totalRevenue: omsStats.totalRevenue,
  );
});
