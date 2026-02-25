import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../controllers/controllers.dart';
import '../../../data/models/order_model.dart';
import '../../widgets/layout/section_container.dart';
import '../../widgets/oms/oms_order_card.dart';

/// OMS orders for vendor: New Requests (pending), Preparing, Ready. Single Firestore stream, filter in UI.
/// Supports ?tab=new query param to show New Requests tab when navigating from the notification bell.
class VendorOrdersPage extends ConsumerStatefulWidget {
  const VendorOrdersPage({super.key});

  @override
  ConsumerState<VendorOrdersPage> createState() => _VendorOrdersPageState();
}

class _VendorOrdersPageState extends ConsumerState<VendorOrdersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final tabParam = GoRouterState.of(context).uri.queryParameters['tab'];
    final initialIndex = tabParam == 'new' ? 0 : 0;
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SectionContainer(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Orders',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Manage and update order status.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
            ),
            const SizedBox(height: 24),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.rosePrimary,
              unselectedLabelColor: AppColors.inkMuted,
              indicatorColor: AppColors.rosePrimary,
              tabs: const [
                Tab(text: 'New Requests'),
                Tab(text: 'Preparing'),
                Tab(text: 'Ready'),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 520,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _VendorOrderList(status: OmsOrderStatus.pending),
                  _VendorOrderList(status: OmsOrderStatus.preparing),
                  _VendorOrderList(status: OmsOrderStatus.ready),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorOrderList extends ConsumerStatefulWidget {
  final OmsOrderStatus status;

  const _VendorOrderList({required this.status});

  @override
  ConsumerState<_VendorOrderList> createState() => _VendorOrderListState();
}

class _VendorOrderListState extends ConsumerState<_VendorOrderList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static String _emptyLabel(OmsOrderStatus s) {
    switch (s) {
      case OmsOrderStatus.pending:
        return 'No new requests.';
      case OmsOrderStatus.preparing:
        return 'No orders in preparation.';
      case OmsOrderStatus.ready:
        return 'No ready bouquets.';
      case OmsOrderStatus.delivered:
        return 'No delivered orders.';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ordersAsync = ref.watch(omsOrdersForVendorStreamProvider);
    return ordersAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.rose),
      ),
      error: (e, _) => Center(
        child: Text(
          'Unable to load orders.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.inkMuted,
              ),
        ),
      ),
      data: (allOrders) {
        final orders = allOrders.where((o) => o.status == widget.status).toList();
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.status == OmsOrderStatus.pending
                      ? Icons.inbox_outlined
                      : widget.status == OmsOrderStatus.preparing
                          ? Icons.schedule_outlined
                          : Icons.check_circle_outline,
                  size: 48,
                  color: AppColors.inkMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  _emptyLabel(widget.status),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        final repo = ref.read(omsOrderRepositoryProvider);

        // Ready tab: group by bouquet so vendor sees how many of each bouquet are prepared.
        if (widget.status == OmsOrderStatus.ready) {
          final grouped = <String, List<OmsOrderModel>>{};
          for (final o in orders) {
            grouped.putIfAbsent(o.bouquetId, () => []).add(o);
          }
          final entries = grouped.entries.toList();
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final first = entry.value.first;
              final count = entry.value.length;
              return KeyedSubtree(
                key: ValueKey('ready-${first.bouquetId}'),
                child: OmsOrderCard(
                  order: first,
                  showVendorLine: false,
                  showOrderIdInSubtitle: true,
                  preparedCount: count,
                ),
              );
            },
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return KeyedSubtree(
              key: ValueKey(order.orderId),
              child: OmsOrderCard(
                order: order,
                showVendorLine: false,
                showOrderIdInSubtitle: true,
                onAccept: widget.status == OmsOrderStatus.pending
                    ? () => repo.updateOmsOrderStatus(
                          orderId: order.orderId,
                          status: OmsOrderStatus.preparing,
                        )
                    : null,
                onReady: widget.status == OmsOrderStatus.preparing
                    ? () => repo.updateOmsOrderStatus(
                          orderId: order.orderId,
                          status: OmsOrderStatus.ready,
                        )
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}
