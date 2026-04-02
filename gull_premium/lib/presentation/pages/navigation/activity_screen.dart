import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../controllers/account_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_format_utils.dart';
import '../../../data/models/user_occasion_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/account/add_occasion_sheet.dart';
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
            const OrdersListView(),
            OccasionsListView(uid: uid),
          ],
        ),
      ),
    );
  }
}

class OrdersListView extends StatelessWidget {
  const OrdersListView({super.key});

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stream = FirebaseFirestore.instance
        .collection('oms_orders')
        .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
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
        final docs = snapshot.data?.docs ?? const [];
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final created = _parseCreatedAt(data);
            final dateStr = created != null
                ? formatOmsOrderDate(created, short: true)
                : '—';
            final shortId = _shortDocId(doc.id);
            final total = _parseTotalPriceIqd(data);
            final statusRaw = data['status']?.toString();
            final chip = _statusChipStyle(statusRaw);
            final priceStr = total > 0
                ? '${l10n.currencyIqd} ${formatPriceIqd(total)}'
                : '—';

            return Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
            );
          },
        );
      },
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
