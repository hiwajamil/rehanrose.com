import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../controllers/controllers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/custom_request_model.dart';

/// Super-admin: custom bouquet tenders, broadcast to vendors, accept bids, mark completed.
class AdminCustomRequestsScreen extends ConsumerStatefulWidget {
  const AdminCustomRequestsScreen({super.key});

  @override
  ConsumerState<AdminCustomRequestsScreen> createState() =>
      _AdminCustomRequestsScreenState();
}

class _AdminCustomRequestsScreenState extends ConsumerState<AdminCustomRequestsScreen> {
  final Map<String, String> _vendorNameCache = {};

  Future<String> _vendorName(String vendorId) async {
    if (vendorId.isEmpty) return '—';
    final c = _vendorNameCache[vendorId];
    if (c != null) return c;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(vendorId).get();
    final data = doc.data();
    final name = data?['fullName']?.toString().trim().isNotEmpty == true
        ? data!['fullName'].toString().trim()
        : (data?['displayName']?.toString().trim() ??
            data?['email']?.toString() ??
            vendorId);
    _vendorNameCache[vendorId] = name;
    return name;
  }

  Future<void> _broadcast(String requestId) async {
    try {
      await ref.read(customRequestRepositoryProvider).broadcastToVendors(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request is now visible to vendors.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Broadcast failed: $e')),
        );
      }
    }
  }

  Future<void> _acceptBid(String requestId, CustomRequestBidEntry bid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept this bid?'),
        content: Text(
          'Vendor ${bid.vendorId}\n'
          'Price: ${bid.offeredPrice}\n'
          'The customer will be asked to approve this price before the order is sent for preparation.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Accept')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await ref.read(customRequestRepositoryProvider).acceptBidPendingCustomer(
            requestId: requestId,
            bidDocId: bid.id,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bid accepted. The customer can now approve or decline the offer.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Accept failed: $e')),
        );
      }
    }
  }

  Future<void> _markCompleted(String requestId) async {
    try {
      await ref.read(customRequestRepositoryProvider).markCompleted(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as completed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  List<CustomRequestBidEntry> _bidsForRequest(
    List<CustomRequestBidEntry> all,
    String requestId,
  ) {
    final list = all.where((b) => b.requestId == requestId).toList();
    list.sort((a, b) => a.offeredPrice.compareTo(b.offeredPrice));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(adminCustomRequestsStreamProvider);
    final bidsAsync = ref.watch(adminCustomBidsStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Custom Requests',
          style: GoogleFonts.montserrat(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.inkCharcoal,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Review bespoke inquiries, broadcast to vendors for bidding, accept the winning offer, then let the customer confirm before you dispatch production.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: requestsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (requests) {
              return bidsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Bids error: $e')),
                data: (allBids) {
                  if (requests.isEmpty) {
                    return Center(
                      child: Text(
                        'No custom requests yet.',
                        style: TextStyle(color: AppColors.inkMuted),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final r = requests[index];
                      final bids = _bidsForRequest(allBids, r.requestId);
                      return _RequestCard(
                        request: r,
                        bids: bids,
                        vendorNameResolver: _vendorName,
                        onBroadcast: () => _broadcast(r.requestId),
                        onAcceptBid: (b) => _acceptBid(r.requestId, b),
                        onMarkCompleted: () => _markCompleted(r.requestId),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.bids,
    required this.vendorNameResolver,
    required this.onBroadcast,
    required this.onAcceptBid,
    required this.onMarkCompleted,
  });

  final CustomRequestModel request;
  final List<CustomRequestBidEntry> bids;
  final Future<String> Function(String vendorId) vendorNameResolver;
  final VoidCallback onBroadcast;
  final void Function(CustomRequestBidEntry bid) onAcceptBid;
  final VoidCallback onMarkCompleted;

  @override
  Widget build(BuildContext context) {
    final st = request.status;
    final canBroadcast = st == CustomRequestStatus.pendingAdmin;
    final showBidList =
        st == CustomRequestStatus.broadcasting || st == CustomRequestStatus.bidAccepted;
    final showCustomerPendingSummary = st == CustomRequestStatus.pendingCustomer;
    final showCustomerAcceptedBanner = st == CustomRequestStatus.customerAccepted;
    final showCustomerDeclined = st == CustomRequestStatus.customerDeclined;
    final canComplete = st == CustomRequestStatus.bidAccepted ||
        st == CustomRequestStatus.customerDeclined;
    final showAcceptButtons = st == CustomRequestStatus.broadcasting;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.85)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (request.imagePath.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      request.imagePath,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 88,
                        height: 88,
                        color: AppColors.background,
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_outlined, color: AppColors.inkMuted),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Request ${request.requestId}',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Customer: ${request.customerId}',
                        style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                      ),
                      const SizedBox(height: 6),
                      _StatusChip(status: st),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Budget', style: TextStyle(fontSize: 11, color: AppColors.inkMuted)),
            Text(request.budget, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text('Description', style: TextStyle(fontSize: 11, color: AppColors.inkMuted)),
            Text(request.description, style: const TextStyle(height: 1.35)),
            if (request.linkedOrderId != null && request.linkedOrderId!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Linked order: ${request.linkedOrderId}',
                style: TextStyle(
                  color: AppColors.rosePrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (canBroadcast)
                  FilledButton.icon(
                    onPressed: onBroadcast,
                    icon: const Icon(Icons.campaign_outlined, size: 18),
                    label: const Text('Broadcast to Vendors'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.rosePrimary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (canComplete)
                  OutlinedButton.icon(
                    onPressed: onMarkCompleted,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Mark completed'),
                  ),
              ],
            ),
            if (showCustomerPendingSummary) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                'Awaiting customer',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 8),
              if (request.winningVendorId != null && request.winningVendorId!.isNotEmpty)
                FutureBuilder<String>(
                  future: vendorNameResolver(request.winningVendorId!),
                  builder: (context, snap) {
                    return Text(
                      'Winning vendor: ${snap.data ?? request.winningVendorId}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    );
                  },
                ),
              const SizedBox(height: 6),
              Text(
                'Accepted price (IQD): ${request.effectiveAcceptedPrice ?? '—'}',
                style: TextStyle(color: AppColors.rosePrimary, fontWeight: FontWeight.w700),
              ),
            ],
            if (showCustomerAcceptedBanner) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                'Customer accepted — dispatch from Bouquet Orders → Custom Orders tab.',
                style: TextStyle(
                  color: AppColors.rosePrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
            if (showCustomerDeclined) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                'Customer declined this offer.',
                style: TextStyle(color: AppColors.inkMuted, fontWeight: FontWeight.w600),
              ),
            ],
            if (showBidList) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Vendor bids (${bids.length})',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (showAcceptButtons) ...[
                    const SizedBox(width: 8),
                    Text(
                      '— lowest first',
                      style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              if (bids.isEmpty)
                Text(
                  st == CustomRequestStatus.broadcasting
                      ? 'No bids yet. Vendors will appear here in real time.'
                      : 'No bids recorded for this request.',
                  style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
                )
              else
                ...bids.map((b) => _BidRow(
                      bid: b,
                      vendorNameResolver: vendorNameResolver,
                      showAccept: showAcceptButtons,
                      onAccept: () => onAcceptBid(b),
                    )),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final CustomRequestStatus? status;

  @override
  Widget build(BuildContext context) {
    final label = status?.value ?? 'unknown';
    Color bg = AppColors.inkMuted.withValues(alpha: 0.12);
    Color fg = AppColors.inkCharcoal;
    if (status == CustomRequestStatus.pendingAdmin) {
      bg = Colors.orange.withValues(alpha: 0.15);
      fg = const Color(0xFFB45309);
    } else if (status == CustomRequestStatus.broadcasting) {
      bg = Colors.blue.withValues(alpha: 0.12);
      fg = const Color(0xFF1D4ED8);
    } else if (status == CustomRequestStatus.bidAccepted) {
      bg = AppColors.rosePrimary.withValues(alpha: 0.12);
      fg = AppColors.rosePrimary;
    } else if (status == CustomRequestStatus.pendingCustomer) {
      bg = Colors.deepPurple.withValues(alpha: 0.12);
      fg = const Color(0xFF5B21B6);
    } else if (status == CustomRequestStatus.customerAccepted) {
      bg = Colors.teal.withValues(alpha: 0.12);
      fg = const Color(0xFF0F766E);
    } else if (status == CustomRequestStatus.customerDeclined) {
      bg = Colors.red.withValues(alpha: 0.1);
      fg = const Color(0xFFB91C1C);
    } else if (status == CustomRequestStatus.completed) {
      bg = Colors.green.withValues(alpha: 0.12);
      fg = const Color(0xFF15803D);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _BidRow extends StatelessWidget {
  const _BidRow({
    required this.bid,
    required this.vendorNameResolver,
    required this.showAccept,
    required this.onAccept,
  });

  final CustomRequestBidEntry bid;
  final Future<String> Function(String vendorId) vendorNameResolver;
  final bool showAccept;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<String>(
                      future: vendorNameResolver(bid.vendorId),
                      builder: (context, snap) {
                        final name = snap.data ?? bid.vendorId;
                        return Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                    Text(
                      'IQD ${bid.offeredPrice}',
                      style: TextStyle(
                        color: AppColors.rosePrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (bid.vendorNote.isNotEmpty)
                      Text(
                        'Notes (ETA): ${bid.vendorNote}',
                        style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                      ),
                  ],
                ),
              ),
              if (showAccept)
                FilledButton(
                  onPressed: onAccept,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.inkCharcoal,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Accept Bid'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
