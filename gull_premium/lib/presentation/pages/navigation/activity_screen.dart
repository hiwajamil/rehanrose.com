import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../controllers/controllers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/custom_request_model.dart';
import '../../../core/utils/app_cache_manager.dart';
import '../../../core/utils/price_format_utils.dart';
import '../../../data/models/user_occasion_model.dart';
import '../../../l10n/app_localizations.dart';
import '../account/customer_oms_order_detail_screen.dart';
import '../cart/cart_screen.dart';
import '../../widgets/account/add_occasion_sheet.dart';
import '../../widgets/common/app_cached_image.dart';
import '../../widgets/oms/oms_order_card.dart';

/// Bottom-nav hub: customer orders (`oms_orders` collection) and saved occasions.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Activity',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.inkCharcoal,
            ),
          ),
          actions: const [_CartAppBarAction()],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Please sign in to view your orders and occasions.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.inkMuted,
                  ),
            ),
          ),
        ),
      );
    }

    final uid = user.uid;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Activity',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.inkCharcoal,
            ),
          ),
          actions: const [_CartAppBarAction()],
          bottom: TabBar(
            indicatorColor: AppColors.accentGold,
            indicatorWeight: 3,
            labelColor: AppColors.inkCharcoal,
            unselectedLabelColor: AppColors.inkMuted,
            labelStyle: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'My Orders'),
              Tab(text: 'My Occasions'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            OrdersListView(
              key: const PageStorageKey<String>('activity-orders-tab'),
              uid: uid,
            ),
            OccasionsListView(
              key: const PageStorageKey<String>('activity-occasions-tab'),
              uid: uid,
            ),
          ],
        ),
      ),
    );
  }
}

class _CartAppBarAction extends StatelessWidget {
  const _CartAppBarAction();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return IconButton(
        tooltip: 'Cart',
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CartScreen()));
        },
        icon: const Icon(Icons.shopping_bag_outlined),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('cart')
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        final icon = IconButton(
          tooltip: 'Cart',
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CartScreen()));
          },
          icon: const Icon(Icons.shopping_bag_outlined),
        );
        if (count <= 0) return icon;
        return Badge(
          label: Text('$count'),
          child: icon,
        );
      },
    );
  }
}

class OrdersListView extends ConsumerStatefulWidget {
  const OrdersListView({super.key, required this.uid});

  final String uid;

  static String _shortDocId(String id) {
    if (id.length <= 6) return id;
    return id.substring(id.length - 6);
  }

  static DateTime? _parseCreatedAt(Map<String, dynamic> data) {
    final ts = data['createdAt'];
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    if (ts != null) return DateTime.tryParse(ts.toString());
    return null;
  }

  static int _parseTotalPriceIqd(Map<String, dynamic> data) {
    final v = data['totalPrice'] ?? data['total'] ?? data['priceIqd'];
    if (v is int) return v;
    if (v is num) return v.round();
    return 0;
  }

  static ({Color bg, Color fg, String label}) _statusChipStyle(String? raw) {
    final s = (raw ?? 'pending')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]'), '_');
    if (s.contains('cancel')) {
      return (
        bg: Colors.red.shade50,
        fg: Colors.red.shade800,
        label: raw?.trim().isNotEmpty == true ? raw!.trim() : 'Cancelled',
      );
    }
    if (s == 'pending') {
      return (
        bg: Colors.orange.shade50,
        fg: Colors.orange.shade900,
        label: 'Pending',
      );
    }
    if (s == 'delivered' || s == 'completed') {
      return (
        bg: Colors.green.shade50,
        fg: Colors.green.shade800,
        label: _prettyStatusLabel(raw, fallback: 'Delivered'),
      );
    }
    if (s == 'out_for_delivery') {
      return (
        bg: Colors.deepPurple.shade50,
        fg: Colors.deepPurple.shade900,
        label: 'Out for delivery',
      );
    }
    if (s == 'preparing' ||
        s == 'accepted' ||
        s == 'ready' ||
        s == 'on_the_way' ||
        s == 'received' ||
        s == 'new') {
      return (
        bg: Colors.blue.shade50,
        fg: Colors.blue.shade800,
        label: _prettyStatusLabel(raw, fallback: 'In progress'),
      );
    }
    return (
      bg: AppColors.badgeGoldBackground,
      fg: AppColors.inkCharcoal,
      label: raw?.trim().isNotEmpty == true ? raw!.trim() : 'Unknown',
    );
  }

  static String _prettyStatusLabel(String? raw, {required String fallback}) {
    final t = raw?.trim();
    if (t == null || t.isEmpty) return fallback;
    return t[0].toUpperCase() + t.substring(1).replaceAll('_', ' ');
  }

  /// 1–4 = current progress stage; 0 = cancelled / indeterminate (all grey).
  static int _orderProgressActiveStep(String? statusRaw) {
    final s = (statusRaw ?? 'pending')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]'), '_');
    if (s.contains('cancel')) return 0;
    if (s == 'delivered' || s == 'completed') return 4;
    if (s == 'out_for_delivery' || s == 'on_the_way') return 3;
    if (s == 'preparing' ||
        s == 'ready' ||
        s == 'accepted' ||
        s == 'received' ||
        s == 'new') {
      return 2;
    }
    if (s == 'pending') return 1;
    if (s == 'deleted') return 0;
    return 1;
  }

  static String _normalizedOrderStatus(String? statusRaw) {
    return (statusRaw ?? 'pending')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]'), '_');
  }

  /// Shown above the stepper; uses Firestore `eta` / similar when present.
  static String _orderEtaLine(Map<String, dynamic> data, String? statusRaw) {
    for (final key in ['eta', 'estimatedArrival', 'estimatedDelivery', 'etaText']) {
      final v = data[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    final s = (statusRaw ?? 'pending')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]'), '_');
    if (s.contains('cancel')) return 'Order cancelled';
    if (s == 'delivered' || s == 'completed') {
      return 'Thank you for your order';
    }
    if (s == 'out_for_delivery' || s == 'on_the_way') {
      return 'Arriving soon...';
    }
    if (s == 'preparing' ||
        s == 'ready' ||
        s == 'accepted' ||
        s == 'received' ||
        s == 'new') {
      return 'Being prepared for you';
    }
    if (s == 'pending') return 'Awaiting confirmation';
    return 'We\'re on it';
  }

  /// Thumbnail for order cards: [imagePath], [imageUrl], [bouquetImageUrl], or [imageUrls][0].
  static String? orderThumbImageUrl(Map<String, dynamic> data) {
    String? pick(String? v) {
      if (v == null) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    final a = pick(data['imagePath']?.toString());
    if (a != null) return a;
    final b = pick(data['imageUrl']?.toString());
    if (b != null) return b;
    final c = pick(data['bouquetImageUrl']?.toString());
    if (c != null) return c;
    final raw = data['imageUrls'];
    if (raw is List<dynamic>) {
      for (final e in raw) {
        final u = pick(e?.toString());
        if (u != null) return u;
      }
    }
    return null;
  }

  @override
  ConsumerState<OrdersListView> createState() => _OrdersListViewState();
}

class _OrdersListViewState extends ConsumerState<OrdersListView>
    with AutomaticKeepAliveClientMixin<OrdersListView> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream;
  QuerySnapshot<Map<String, dynamic>>? _lastSnapshot;

  @override
  void initState() {
    super.initState();
    _ordersStream = FirebaseFirestore.instance
        .collection('oms_orders')
        .where('userId', isEqualTo: widget.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          _lastSnapshot = snapshot;
          return snapshot;
        });
  }

  Widget _pendingCustomOffersStrip(List<CustomRequestModel> offers) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Custom bouquet — offer pending your approval',
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.inkCharcoal,
            ),
          ),
          const SizedBox(height: 10),
          ...offers.map((r) {
            final price = r.effectiveAcceptedPrice;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: r.imagePath.isNotEmpty
                              ? AppCachedImage(
                                  imageUrl: r.imagePath,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 144,
                                  memCacheHeight: 144,
                                  borderRadius: BorderRadius.circular(10),
                                )
                              : Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.photo_outlined, color: AppColors.inkMuted),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Accepted price: ${price != null ? '${AppLocalizations.of(context)!.currencyIqd} $price' : '—'}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.rosePrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (r.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        r.description,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Decline this offer?'),
                                  content: const Text(
                                    'You can submit a new custom request later if you change your mind.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Decline'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok != true || !mounted) return;
                              try {
                                await ref
                                    .read(customRequestRepositoryProvider)
                                    .setCustomerOfferResponse(
                                      requestId: r.requestId,
                                      accept: false,
                                    );
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Could not update: $e')),
                                  );
                                }
                              }
                            },
                            child: const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Accept this offer?'),
                                  content: Text(
                                    price != null
                                        ? 'You agree to proceed at ${AppLocalizations.of(context)!.currencyIqd} $price.'
                                        : 'You agree to proceed with this custom bouquet offer.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Accept offer'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok != true || !mounted) return;
                              try {
                                await ref
                                    .read(customRequestRepositoryProvider)
                                    .setCustomerOfferResponse(
                                      requestId: r.requestId,
                                      accept: true,
                                    );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Thank you! Our team will send your order for preparation shortly.',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Could not update: $e')),
                                  );
                                }
                              }
                            },
                            child: const Text('Accept offer'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    final pendingOffersAsync =
        ref.watch(customerPendingCustomOffersStreamProvider(widget.uid));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        pendingOffersAsync.when(
          data: (offers) =>
              offers.isEmpty ? const SizedBox.shrink() : _pendingCustomOffersStrip(offers),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ordersStream,
      initialData: _lastSnapshot,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];

        if (snapshot.connectionState == ConnectionState.waiting && docs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          debugPrint(
            'OrdersListView stream error (uid=${widget.uid}): ${snapshot.error}',
          );
          if (snapshot.stackTrace != null) {
            debugPrint(snapshot.stackTrace.toString());
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load your orders.',
                style: TextStyle(color: AppColors.inkMuted),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (docs.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_florist_rounded,
                    size: 72,
                    color: AppColors.accentGold.withValues(alpha: 0.85),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No orders yet',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkCharcoal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Discover our luxury bouquets and place your first order.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.inkMuted,
                          height: 1.45,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final created = OrdersListView._parseCreatedAt(data);
            final dateStr = created != null
                ? formatOmsOrderDate(created, short: true)
                : '—';
            final shortId = OrdersListView._shortDocId(doc.id);
            final total = OrdersListView._parseTotalPriceIqd(data);
            final statusRaw = data['status']?.toString();
            final normalizedStatus = OrdersListView._normalizedOrderStatus(statusRaw);
            final isDeleted = normalizedStatus == 'deleted';
            final chip = OrdersListView._statusChipStyle(statusRaw);
            final priceStr = total > 0
                ? '${l10n.currencyIqd} ${formatPriceIqd(total)}'
                : '—';
            final thumbUrl = OrdersListView.orderThumbImageUrl(data);
            final progressStep = OrdersListView._orderProgressActiveStep(statusRaw);
            final etaLine = OrdersListView._orderEtaLine(data, statusRaw);

            return Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CustomerOmsOrderDetailScreen(
                        orderDocId: doc.id,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _OrderListThumbnail(imageUrl: thumbUrl),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Order #$shortId',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.inkCharcoal,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          dateStr,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 13,
                                            color: AppColors.inkMuted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: chip.bg,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: chip.fg.withValues(alpha: 0.12),
                                      ),
                                    ),
                                    child: Text(
                                      chip.label,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: chip.fg,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (!isDeleted) ...[
                                const SizedBox(height: 8),
                                Text(
                                  etaLine,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.inkMuted,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _OrderProgressTracker(activeStep: progressStep),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          'Total',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          priceStr,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.forestGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ),
              ),
            );
          },
        );
      },
          ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

const double _kOrderListThumbSize = 50;

const Color _kOrderStepInactive = Color(0xFF827C75);
const Color _kOrderStepLineInactive = Color(0xFFB1ABA4);

class _OrderProgressTracker extends StatelessWidget {
  const _OrderProgressTracker({required this.activeStep});

  /// 0 = all inactive; 1–4 = Placed through Delivered.
  final int activeStep;

  static const _labels = ['Placed', 'Preparing', 'On the Way', 'Delivered'];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelFontSize = constraints.maxWidth < 320 ? 11.0 : 12.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List<Widget>.generate(4, (i) {
            final isCompleted = activeStep > 0 && activeStep >= i + 1;
            final isLive = activeStep == i + 1 && activeStep > 0 && activeStep < 4;
            final lineLeftActive = i > 0 && activeStep > i;
            final lineRightActive = i < 3 && activeStep > i + 1;
            return Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: i == 0
                            ? const SizedBox.shrink()
                            : Container(
                                height: 2,
                                margin: const EdgeInsets.only(right: 2),
                                color: lineLeftActive
                                    ? AppColors.forestGreen
                                    : _kOrderStepLineInactive,
                              ),
                      ),
                      _StepDot(isCompleted: isCompleted, isLive: isLive),
                      Expanded(
                        child: i == 3
                            ? const SizedBox.shrink()
                            : Container(
                                height: 2,
                                margin: const EdgeInsets.only(left: 2),
                                color: lineRightActive
                                    ? AppColors.forestGreen
                                    : _kOrderStepLineInactive,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.w500,
                      color: isCompleted ? AppColors.forestGreen : _kOrderStepInactive,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

class _StepDot extends StatefulWidget {
  const _StepDot({required this.isCompleted, required this.isLive});

  final bool isCompleted;
  final bool isLive;

  @override
  State<_StepDot> createState() => _StepDotState();
}

class _StepDotState extends State<_StepDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulse = Tween<double>(begin: 0.9, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isLive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _StepDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLive == oldWidget.isLive) return;
    if (widget.isLive) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.isLive ? 10.5 : 8.0;
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.isCompleted ? AppColors.forestGreen : _kOrderStepInactive,
      ),
    );

    if (!widget.isLive) return dot;
    return AnimatedBuilder(
      animation: _pulse,
      child: dot,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulse.value,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.forestGreen.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: (_pulse.value - 0.9) * 3,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _OrderListThumbnail extends StatelessWidget {
  const _OrderListThumbnail({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: _kOrderListThumbSize,
      height: _kOrderListThumbSize,
      color: const Color(0xFFE8EAED),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 20,
        color: AppColors.inkMuted,
      ),
    );
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: box,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        width: _kOrderListThumbSize,
        height: _kOrderListThumbSize,
        fit: BoxFit.cover,
        memCacheWidth: 100,
        memCacheHeight: 100,
        cacheManager: appCacheManager,
        placeholder: (_, __) => box,
        errorWidget: (_, __, ___) => box,
      ),
    );
  }
}

class OccasionsListView extends ConsumerWidget {
  const OccasionsListView({super.key, required this.uid});

  final String uid;

  void _showAdd(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddOccasionSheet(
        titleText: l10n.profileAddOccasion,
        submitText: 'Save',
        successText: 'Occasion saved.',
        onSave: (name, date, relation) async {
          await ref.read(userOccasionsRepositoryProvider).addOccasion(
                uid,
                name: name,
                date: date,
                relation: relation,
              );
        },
        l10n: l10n,
      ),
    );
  }

  void _showEdit(
    BuildContext context,
    WidgetRef ref,
    UserOccasionModel occasion,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddOccasionSheet(
        titleText: 'Edit occasion',
        submitText: 'Update',
        successText: 'Occasion updated.',
        initialName: occasion.name,
        initialDate: occasion.date,
        initialRelation: occasion.relation,
        onSave: (name, date, relation) async {
          await ref.read(userOccasionsRepositoryProvider).updateOccasion(
                uid,
                occasion.id,
                name: name,
                date: date,
                relation: relation,
              );
        },
        l10n: l10n,
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    UserOccasionModel occasion,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Delete Occasion?',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.inkCharcoal,
            ),
          ),
          content: Text(
            'Are you sure you want to remove this occasion?',
            style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(userOccasionsRepositoryProvider).deleteOccasion(uid, occasion.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Occasion removed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('occasions')
        .orderBy('date', descending: false)
        .snapshots();

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Could not load occasions.',
                    style: TextStyle(color: AppColors.inkMuted),
                  ),
                );
              }
              final docs = snapshot.data?.docs ?? const [];
              final occasions = docs
                  .map((d) => UserOccasionModel.fromFirestore(d.id, d.data()))
                  .whereType<UserOccasionModel>()
                  .toList();

              if (occasions.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  children: [
                    Icon(
                      Icons.celebration_rounded,
                      size: 64,
                      color: AppColors.rose.withValues(alpha: 0.55),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No occasions saved',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Save birthdays, anniversaries, and reminders so you never miss a moment.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkMuted,
                            height: 1.45,
                          ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: occasions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final o = occasions[index];
                  return Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.badgeGoldBackground,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.card_giftcard_rounded,
                              color: AppColors.accentGold,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  o.name,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.inkCharcoal,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat.yMMMd().format(o.date),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    color: AppColors.inkMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  o.relation,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.rosePrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () => _showEdit(context, ref, o),
                            icon: Icon(Icons.edit_rounded, color: AppColors.inkMuted, size: 20),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () => _confirmDelete(context, ref, o),
                            icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 21),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showAdd(context, ref),
              icon: const Icon(Icons.add_rounded, size: 22),
              label: Text(
                AppLocalizations.of(context)!.profileAddOccasion,
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
