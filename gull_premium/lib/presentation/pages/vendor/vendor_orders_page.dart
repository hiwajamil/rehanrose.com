import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../controllers/controllers.dart';
import '../../../data/models/order_model.dart';
import '../../../data/repositories/order_repository.dart';
import '../../widgets/layout/section_container.dart';
import '../../widgets/oms/oms_order_card.dart';

Future<void> _updateVendorOrderStatus(
  BuildContext context,
  OmsOrderRepository repo, {
  required String orderId,
  required OmsOrderStatus status,
}) async {
  try {
    await repo.updateOmsOrderStatus(
      orderId: orderId,
      status: status,
      applyCompletionFinancials: false,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not update order: $e')),
    );
  }
}

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
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage and update order status.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
            ),
            const SizedBox(height: 24),
            _PillTabBar(controller: _tabController),
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

/// Pill-shaped segmented control for order status tabs.
class _PillTabBar extends StatelessWidget {
  final TabController controller;

  const _PillTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: AppColors.rosePrimary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.rosePrimary.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.rosePrimary,
        unselectedLabelColor: AppColors.inkMuted,
        labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
        unselectedLabelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
        tabs: const [
          Tab(text: 'New Requests'),
          Tab(text: 'Preparing'),
          Tab(text: 'Ready'),
        ],
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
          return _OrdersEmptyState(
            status: widget.status,
            message: _emptyLabel(widget.status),
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
                    ? () => _updateVendorOrderStatus(
                          context,
                          repo,
                          orderId: order.orderId,
                          status: OmsOrderStatus.preparing,
                        )
                    : null,
                onReady: widget.status == OmsOrderStatus.preparing
                    ? () => _updateVendorOrderStatus(
                          context,
                          repo,
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

/// Premium empty state for orders tabs: soft icon + gentle placeholder text.
class _OrdersEmptyState extends StatelessWidget {
  final OmsOrderStatus status;
  final String message;

  const _OrdersEmptyState({
    required this.status,
    required this.message,
  });

  IconData get _icon {
    switch (status) {
      case OmsOrderStatus.pending:
        return Icons.inbox_outlined;
      case OmsOrderStatus.preparing:
        return Icons.schedule_outlined;
      case OmsOrderStatus.ready:
        return Icons.check_circle_outline;
      case OmsOrderStatus.delivered:
        return Icons.local_shipping_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.inkMuted.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, size: 36, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.inkMuted,
                    height: 1.4,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
