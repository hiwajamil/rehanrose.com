import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../controllers/controllers.dart';
import '../../../../data/models/customer_member_model.dart';
import '../../../../data/models/order_model.dart';
import '../../../widgets/common/primary_button.dart';
import '../../../widgets/layout/app_scaffold.dart';
import '../../../widgets/layout/section_container.dart';

/// Super Admin CRM: list of all registered customers (role == 'customer').
class MembersListScreen extends ConsumerWidget {
  const MembersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersStreamProvider);

    return AppScaffold(
      child: SectionContainer(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/admin'),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.ink,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Customer Base',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Registered members (customers)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: customersAsync.when(
                loading: () => const _MembersListShimmer(),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: AppColors.inkMuted),
                      const SizedBox(height: 16),
                      Text(
                        'Unable to load members.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.inkMuted,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                data: (customers) {
                  if (customers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: AppColors.inkMuted),
                          const SizedBox(height: 16),
                          Text(
                            'No members yet.',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 32),
                    itemCount: customers.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _MemberCard(
                        member: customers[index],
                        onOrderHistory: () => _showOrderHistoryBottomSheet(
                          context,
                          ref,
                          customers[index],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showOrderHistoryBottomSheet(
    BuildContext context,
    WidgetRef ref,
    CustomerMemberModel member,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 24,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Row(
                  children: [
                    Text(
                      'Order History',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '— ${member.fullName}',
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<CustomerOrderItem>>(
                  future: ref.read(orderRepositoryProvider).listOrdersByUserId(member.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.rose,
                          ),
                        ),
                      );
                    }
                    final orders = snapshot.data ?? [];
                    if (orders.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 56,
                              color: AppColors.inkMuted,
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                "This user hasn't made any orders yet.",
                                style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                                      color: AppColors.inkMuted,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return _OrderHistoryTile(order: order);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single member card: name, chip, city/phone/join date, total orders, Order History button.
class _MemberCard extends ConsumerWidget {
  final CustomerMemberModel member;
  final VoidCallback onOrderHistory;

  const _MemberCard({
    required this.member,
    required this.onOrderHistory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderCountAsync = ref.watch(orderCountForUserProvider(member.uid));
    final joinDateStr = member.createdAt != null
        ? DateFormat('MMM d, y').format(member.createdAt!)
        : '—';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  member.fullName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.ink,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: member.isVip
                      ? AppColors.rosePrimary.withValues(alpha: 0.12)
                      : AppColors.sage.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: member.isVip ? AppColors.rosePrimary : AppColors.sage,
                    width: 1,
                  ),
                ),
                child: Text(
                  member.isVip ? 'VIP' : 'Member',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: member.isVip ? AppColors.rosePrimary : AppColors.inkMuted,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 18, color: AppColors.inkMuted),
              const SizedBox(width: 8),
              Text(
                member.city,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkMuted,
                    ),
              ),
              const SizedBox(width: 20),
              Icon(Icons.phone_outlined, size: 18, color: AppColors.inkMuted),
              const SizedBox(width: 8),
              Text(
                member.phone,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkMuted,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.inkMuted),
              const SizedBox(width: 8),
              Text(
                'Joined: $joinDateStr',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkMuted,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Total Orders: ',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkMuted,
                    ),
              ),
              orderCountAsync.when(
                data: (count) => Text(
                  '$count',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                ),
                loading: () => const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => Text(
                  '—',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Order History',
                onPressed: onOrderHistory,
                variant: PrimaryButtonVariant.outline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One row in the Order History bottom sheet: thumbnail, name/code, date, status.
class _OrderHistoryTile extends StatelessWidget {
  final CustomerOrderItem order;

  const _OrderHistoryTile({required this.order});

  static String _statusLabel(OrderTrackingStatus s) {
    switch (s) {
      case OrderTrackingStatus.received:
        return 'Received';
      case OrderTrackingStatus.preparing:
        return 'Preparing';
      case OrderTrackingStatus.onTheWay:
        return 'On the way';
      case OrderTrackingStatus.delivered:
        return 'Delivered';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = order.createdAt != null
        ? DateFormat('MMM d, y').format(order.createdAt!)
        : '—';
    final nameOrCode = order.bouquetName?.isNotEmpty == true
        ? order.bouquetName!
        : (order.bouquetCode?.isNotEmpty == true
            ? '#${order.bouquetCode}'
            : 'Order #${order.orderId}');
    final imageUrl = order.bouquetImageUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholderThumb(context),
                  )
                : _placeholderThumb(context),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nameOrCode,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusLabel(order.status),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.rosePrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderThumb(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      color: AppColors.border,
      child: Icon(Icons.local_florist_outlined, color: AppColors.inkMuted, size: 28),
    );
  }
}

/// Shimmer placeholder while members list is loading.
class _MembersListShimmer extends StatelessWidget {
  const _MembersListShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.surface,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: 6,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}
