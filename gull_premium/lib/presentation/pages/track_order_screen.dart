import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/auth_controller.dart';
import '../../core/theme/app_colors.dart';

/// Premium customer-facing order tracking screen.
///
/// - Shows a search field for order ID lookups.
/// - If logged in, also streams the user's active orders (excluding delivered).
/// - Each order renders a 4-stage timeline card.
class TrackOrderScreen extends ConsumerStatefulWidget {
  const TrackOrderScreen({super.key});

  @override
  ConsumerState<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends ConsumerState<TrackOrderScreen> {
  final _orderIdController = TextEditingController();
  bool _searchLoading = false;
  String? _searchError;

  _TrackedOrder? _searchedOrder;

  @override
  void dispose() {
    _orderIdController.dispose();
    super.dispose();
  }

  Future<void> _submitSearch() async {
    final raw = _orderIdController.text.trim();
    _orderIdController.text = raw;

    final orderId = raw.replaceFirst(RegExp(r'^#\s*'), '');
    if (orderId.isEmpty) return;

    setState(() {
      _searchLoading = true;
      _searchError = null;
      _searchedOrder = null;
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (!mounted) return;

      if (!snap.exists || snap.data() == null) {
        setState(() {
          _searchLoading = false;
          _searchError = 'Order not found';
        });
        return;
      }

      final data = snap.data()!;
      final status = (data['status'] ?? '').toString();
      setState(() {
        _searchLoading = false;
        _searchError = null;
        _searchedOrder = _TrackedOrder(orderId: snap.id, status: status);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchLoading = false;
        _searchError = 'Could not fetch order. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          'Track Order',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: TextField(
                controller: _orderIdController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submitSearch(),
                decoration: InputDecoration(
                  labelText: 'Enter Order ID (e.g., #RR-1024)',
                  hintText: '#RR-1024',
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: IconButton(
                    tooltip: 'Search',
                    icon: const Icon(Icons.search_rounded),
                    onPressed: _searchLoading ? null : _submitSearch,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.accentGold.withValues(alpha: 0.7)),
                  ),
                ),
              ),
            ),
            if (_searchLoading)
              const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_searchError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  _searchError!,
                  style: TextStyle(
                    color: Colors.red.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Expanded(
              child: authAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _OrdersBodyGuest(
                  searchedOrder: _searchedOrder,
                  showEmpty: _searchedOrder == null,
                ),
                data: (user) {
                  if (user == null) {
                    return _OrdersBodyGuest(
                      searchedOrder: _searchedOrder,
                      showEmpty: _searchedOrder == null,
                    );
                  }

                  return _OrdersBodyAuthed(
                    uid: user.uid,
                    searchedOrder: _searchedOrder,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersBodyGuest extends StatelessWidget {
  const _OrdersBodyGuest({
    required this.searchedOrder,
    required this.showEmpty,
  });

  final _TrackedOrder? searchedOrder;
  final bool showEmpty;

  @override
  Widget build(BuildContext context) {
    if (searchedOrder != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          _OrderTimelineCard(order: searchedOrder!),
        ],
      );
    }

    if (!showEmpty) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: const [
        _EmptyTrackOrderState(
          title: 'No active orders yet',
          subtitle:
              'Sign in to see your active orders. Or enter an order ID to track it.',
        ),
      ],
    );
  }
}

class _OrdersBodyAuthed extends StatelessWidget {
  const _OrdersBodyAuthed({
    required this.uid,
    required this.searchedOrder,
  });

  final String uid;
  final _TrackedOrder? searchedOrder;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: const [
              _EmptyTrackOrderState(
                title: 'Could not load orders',
                subtitle: 'Please try again later.',
              ),
            ],
          );
        }

        final docs = snapshot.data?.docs ?? const [];
        final active = docs
            .map((d) {
              final data = d.data();
              final status = (data['status'] ?? '').toString();
              final createdAt = _parseFirestoreDateTime(
                data['createdAt'] ?? data['timestamp'],
              );
              return _TrackedOrder(
                orderId: d.id,
                status: status,
                createdAt: createdAt,
              );
            })
            .where((o) => !_isDelivered(o.status))
            .toList();

        active.sort((a, b) {
          final aMs = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final bMs = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return bMs.compareTo(aMs);
        });

        final merged = [...active];
        if (searchedOrder != null) {
          final exists = merged.any((o) => o.orderId == searchedOrder!.orderId);
          if (!exists) merged.insert(0, searchedOrder!);
        }

        if (merged.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: const [
              _EmptyTrackOrderState(
                title: 'No active orders found',
                subtitle: 'When your order is placed, it will appear here.',
              ),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          itemCount: merged.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _OrderTimelineCard(order: merged[index]);
          },
        );
      },
    );
  }
}

class _EmptyTrackOrderState extends StatelessWidget {
  const _EmptyTrackOrderState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}

class _OrderTimelineCard extends StatelessWidget {
  const _OrderTimelineCard({required this.order});

  final _TrackedOrder order;

  @override
  Widget build(BuildContext context) {
    final stepIndex = _stepIndexForStatus(order.status);

    const labels = [
      'Order Placed',
      'Preparing',
      'On the Way',
      'Delivered',
    ];

    const icons = [
      Icons.receipt_long_rounded,
      Icons.local_florist_rounded,
      Icons.local_shipping_rounded,
      Icons.check_circle_rounded,
    ];

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.orderId,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: List.generate(4, (index) {
                final isCompleted = stepIndex != -1 && index < stepIndex;
                final isActive = stepIndex != -1 && index == stepIndex;

                final iconColor = isCompleted
                    ? AppColors.forestGreen
                    : isActive
                        ? AppColors.accentGold
                        : AppColors.inkMuted.withValues(alpha: 0.55);
                final lineColor = isCompleted
                    ? AppColors.forestGreen.withValues(alpha: 0.85)
                    : AppColors.border.withValues(alpha: 0.65);

                final circleBg = isCompleted
                    ? AppColors.forestGreen.withValues(alpha: 0.12)
                    : isActive
                        ? AppColors.badgeGoldBackground
                        : AppColors.background.withValues(alpha: 0.35);

                final textColor = isActive || isCompleted
                    ? AppColors.ink
                    : AppColors.inkMuted.withValues(alpha: 0.55);

                final fontWeight = isActive
                    ? FontWeight.w800
                    : isCompleted
                        ? FontWeight.w700
                        : FontWeight.w600;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: circleBg,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: (isCompleted || isActive)
                                    ? AppColors.border.withValues(alpha: 0.65)
                                    : AppColors.border,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                icons[index],
                                size: 20,
                                color: iconColor,
                              ),
                            ),
                          ),
                          if (index != 3)
                            Expanded(
                              child: Container(
                                width: 2,
                                margin:
                                    const EdgeInsets.symmetric(vertical: 2),
                                color: lineColor,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          labels[index],
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: fontWeight,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final stepIndex = _stepIndexForStatus(status);

    final (bg, fg) = switch (stepIndex) {
      0 => (AppColors.badgeGoldBackground, AppColors.inkCharcoal),
      1 => (AppColors.sage.withValues(alpha: 0.25), AppColors.inkCharcoal),
      2 => (AppColors.badgeGoldBackground, AppColors.inkCharcoal),
      3 => (AppColors.forestGreen.withValues(alpha: 0.14), AppColors.forestGreen),
      _ => (AppColors.background.withValues(alpha: 0.6), AppColors.inkMuted),
    };

    final text = normalized.isEmpty ? 'Unknown' : status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
      ),
      child: Text(
        text,
        style: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _TrackedOrder {
  final String orderId;
  final String status;
  final DateTime? createdAt;

  const _TrackedOrder({
    required this.orderId,
    required this.status,
    this.createdAt,
  });
}

bool _isDelivered(String status) {
  final s = status.trim().toLowerCase();
  return s == 'delivered';
}

int _stepIndexForStatus(String status) {
  final s = status.trim().toLowerCase().replaceAll(' ', '_');

  // Requirement stages: pending → accepted → on_the_way → delivered.
  // Existing code often uses: received → preparing → on_the_way → delivered.
  // This function supports both.
  if (s == 'pending' || s == 'received' || s == 'new') return 0;
  if (s == 'accepted' || s == 'preparing') return 1;
  if (s == 'on_the_way' || s == 'ontheway' || s == 'on-the-way') return 2;
  if (s == 'ready') return 2; // OMS "ready" is typically near-delivery.
  if (s == 'delivered') return 3;
  return -1; // unknown
}

DateTime? _parseFirestoreDateTime(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

