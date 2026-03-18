import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../controllers/controllers.dart';
import '../../../../data/models/customer_member_model.dart';
import '../../../../data/models/order_model.dart';
import '../../../widgets/common/app_cached_image.dart';

/// Super Admin CRM: list of all registered customers (role == 'customer').
/// Uses cursor-based pagination (20 per page) with infinite scroll.
class MembersListScreen extends ConsumerStatefulWidget {
  const MembersListScreen({super.key});

  @override
  ConsumerState<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends ConsumerState<MembersListScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _didInitialLoad = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final notifier = ref.read(paginatedCustomersProvider.notifier);
    final state = ref.read(paginatedCustomersProvider);
    if (!state.hasMore || state.isLoadingMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      notifier.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paginatedCustomersProvider);

    if (!_didInitialLoad) {
      _didInitialLoad = true;
      Future.microtask(() {
        ref.read(paginatedCustomersProvider.notifier).loadInitial();
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer Base',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
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
          child: state.isLoading && state.list.isEmpty
              ? const _MembersListShimmer()
              : state.error != null && state.list.isEmpty
                  ? Center(
                      child: _AdminEmptyState(
                        icon: Icons.cloud_off_outlined,
                        message: 'Unable to load members',
                        subtitle: state.error!,
                      ),
                    )
                  : state.list.isEmpty
                      ? Center(
                          child: _AdminEmptyState(
                            icon: Icons.people_outline,
                            message: 'No members yet.',
                            subtitle: 'Registered customers will appear here.',
                          ),
                        )
                      : _MembersPremiumCards(
                          members: state.list,
                          scrollController: _scrollController,
                          hasMore: state.hasMore,
                          isLoadingMore: state.isLoadingMore,
                          onOrderHistory: (member) => _showOrderHistoryBottomSheet(
                            context,
                            ref,
                            member,
                          ),
                        ),
        ),
      ],
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

/// Premium CRM cards: responsive grid (desktop) / list (mobile).
class _MembersPremiumCards extends StatelessWidget {
  const _MembersPremiumCards({
    required this.members,
    required this.scrollController,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onOrderHistory,
  });

  final List<CustomerMemberModel> members;
  final ScrollController scrollController;
  final bool hasMore;
  final bool isLoadingMore;
  final void Function(CustomerMemberModel member) onOrderHistory;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bool useGrid = width >= 900;
        final int crossAxisCount = useGrid ? (width >= 1200 ? 3 : 2) : 1;

        final itemCount = members.length + ((hasMore && isLoadingMore) ? 1 : 0);

        if (!useGrid) {
          return ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (index >= members.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.rosePrimary,
                      ),
                    ),
                  ),
                );
              }
              final member = members[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _MemberPremiumCard(
                  member: member,
                  onOrderHistory: () => onOrderHistory(member),
                ),
              );
            },
          );
        }

        return GridView.builder(
          controller: scrollController,
          padding: const EdgeInsets.only(bottom: 32),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 220,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index >= members.length) {
              return const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.rosePrimary,
                  ),
                ),
              );
            }
            final member = members[index];
            return _MemberPremiumCard(
              member: member,
              onOrderHistory: () => onOrderHistory(member),
            );
          },
        );
      },
    );
  }
}

class _MemberPremiumCard extends StatelessWidget {
  const _MemberPremiumCard({
    required this.member,
    required this.onOrderHistory,
  });

  final CustomerMemberModel member;
  final VoidCallback onOrderHistory;

  static String _initials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    String takeFirstChar(String s) => s.isNotEmpty ? s.substring(0, 1) : '';
    final a = takeFirstChar(parts.first).toUpperCase();
    final b = parts.length > 1 ? takeFirstChar(parts.last).toUpperCase() : '';
    return (a + b).trim();
  }

  static Color _avatarBg(String seed) {
    // Soft luxury palette; deterministic per user.
    const colors = [
      Color(0xFFF4E7EC), // blush
      Color(0xFFE8EEF6), // mist blue
      Color(0xFFEAF4EF), // mint
      Color(0xFFF6F1E7), // champagne
      Color(0xFFEFEAF7), // lavender
    ];
    final hash = seed.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final name = member.fullName.trim().isNotEmpty ? member.fullName.trim() : 'No Name';
    final emailRaw = member.email.trim();
    final phoneRaw = member.phone.trim();

    final email = (emailRaw.isEmpty ||
            emailRaw.toLowerCase() == 'no email' ||
            !emailRaw.contains('@'))
        ? 'No Email Provided'
        : emailRaw;

    final phone = (phoneRaw.isEmpty ||
            phoneRaw.toLowerCase() == 'n/a' ||
            phoneRaw.toLowerCase() == 'na')
        ? 'No Phone Provided'
        : phoneRaw;

    final joined = member.createdAt != null
        ? 'Registered: ${DateFormat('MMM d, y').format(member.createdAt!)}'
        : 'Registered: —';

    final avatarBg = _avatarBg(member.uid);
    final avatarFg = AppColors.inkCharcoal.withValues(alpha: 0.85);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarBg,
                  child: Text(
                    _initials(name),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: avatarFg,
                        ),
                  ),
                ),
                title: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                ),
                subtitle: Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.75)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 18, color: AppColors.inkMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.inkMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            joined,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.inkMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PopupMenuButton<_MemberManageAction>(
                    tooltip: 'Manage',
                    onSelected: (value) {
                      switch (value) {
                        case _MemberManageAction.orderHistory:
                          onOrderHistory();
                        case _MemberManageAction.comingSoon:
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('More member tools coming soon.')),
                          );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _MemberManageAction.orderHistory,
                        child: Text('Order History'),
                      ),
                      PopupMenuItem(
                        value: _MemberManageAction.comingSoon,
                        child: Text('Coming Soon'),
                      ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: Text(
                        'Manage',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.rosePrimary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MemberManageAction { orderHistory, comingSoon }

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
                ? AppCachedImage(
                    imageUrl: imageUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(12),
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

/// Premium empty/error state for admin CRM: soft icon + message.
class _AdminEmptyState extends StatelessWidget {
  const _AdminEmptyState({
    required this.icon,
    required this.message,
    this.subtitle,
  });

  final IconData icon;
  final String message;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.inkMuted.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 56,
              color: AppColors.inkMuted.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
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
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
