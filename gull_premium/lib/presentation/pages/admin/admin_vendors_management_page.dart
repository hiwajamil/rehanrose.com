import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../controllers/controllers.dart';
import '../../../l10n/app_localizations.dart';

/// Super Admin: Vendors Management. Grid of approved vendors with stats and quick actions.
class AdminVendorsManagementPage extends ConsumerWidget {
  const AdminVendorsManagementPage({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _vendorsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'vendor')
        .snapshots();
  }

  int _crossAxisCountForWidth(double width) {
    if (width > 1100) return 3;
    if (width > 700) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.adminVendorsManagement,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.adminVendorsManagementSubtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.inkMuted,
              ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _vendorsStream(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.rosePrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.adminLoadingVendors,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.inkMuted,
                            ),
                      ),
                    ],
                  ),
                );
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    l10n.adminUnableToLoadApplications,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                  ),
                );
              }
              final docs = snap.data?.docs ?? const [];
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.store_outlined,
                        size: 48,
                        color: AppColors.inkMuted.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.adminNoApprovedVendors,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.inkMuted,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = _crossAxisCountForWidth(width);
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 420,
                    ),
                    padding: const EdgeInsets.only(bottom: 32),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final vendorData = doc.data();
                      final bool isOnline =
                          vendorData.containsKey('isOnline') ? doc['isOnline'] == true : false;
                      return _AdminVendorCard(
                        vendorId: doc.id,
                        data: vendorData,
                        isOnline: isOnline,
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

class _AdminVendorCard extends ConsumerWidget {
  const _AdminVendorCard({
    required this.vendorId,
    required this.data,
    required this.isOnline,
  });

  final String vendorId;
  final Map<String, dynamic> data;
  final bool isOnline;

  static const double _defaultCommissionRate = 0.15;

  Future<void> _setSuspended(BuildContext context, bool value) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(vendorId)
        .update({'isSuspended': value});
  }

  double _commissionRateForVendor() {
    final commissionRateRaw = data['commissionRate'];
    final double? v = commissionRateRaw is num ? commissionRateRaw.toDouble() : null;
    if (v != null && v >= 0 && v <= 1) return v;
    return _defaultCommissionRate;
  }

  Future<DateTimeRange?> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final initialEnd = DateTime(now.year, now.month, now.day);
    final initialStart = initialEnd.subtract(const Duration(days: 29));
    return showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      helpText: 'Select payout period',
      saveText: 'Generate',
    );
  }

  Future<_PeriodFinancials> _fetchPeriodFinancials({
    required DateTime startDate,
    required DateTime endDate,
    required double commissionRate,
  }) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

    final snap = await FirebaseFirestore.instance
        .collection('orders')
        .where('vendorId', isEqualTo: vendorId)
        .where('status', whereIn: const ['ready', 'delivered'])
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    num totalSales = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      totalSales += _asNum(data['totalPrice']);
    }

    final commission = totalSales * commissionRate;
    final payout = totalSales - commission;

    return _PeriodFinancials(
      start: start,
      end: end,
      totalSales: totalSales,
      rehanRoseCommission: commission,
      vendorPayout: payout,
      completedOrders: snap.size,
      commissionRate: commissionRate,
    );
  }

  Future<void> _openFinancialReport(BuildContext context, {required String vendorName}) async {
    final range = await _pickDateRange(context);
    if (range == null) return;

    final commissionRate = _commissionRateForVendor();
    final future = _fetchPeriodFinancials(
      startDate: range.start,
      endDate: range.end,
      commissionRate: commissionRate,
    );

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _VendorFinancialReportSheet(
                  vendorName: vendorName,
                  future: future,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEditModal(
    BuildContext context, {
    required String initialName,
    required String initialPhone,
  }) async {
    final nameController = TextEditingController(text: initialName);
    final phoneController = TextEditingController(text: initialPhone);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Material(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Edit Vendor',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            prefixIcon: Icon(Icons.store_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () async {
                                  final name = nameController.text.trim();
                                  final phone = phoneController.text.trim();
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(vendorId)
                                      .update({
                                    if (name.isNotEmpty) 'shopName': name,
                                    'phoneNumber': phone,
                                  });
                                  if (sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop();
                                  }
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.ink,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Save Changes'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: sheetContext,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Vendor?'),
                                  content: const Text(
                                    'Are you absolutely sure you want to delete this vendor account?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      child: const Text(
                                        'Delete Vendor',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(vendorId)
                                  .delete();
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: BorderSide(color: Colors.red.shade200),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Delete Vendor'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final statsAsync = ref.watch(vendorStatsProvider(vendorId));

    final shopName = data['shopName']?.toString().trim() ??
        data['displayName']?.toString().trim() ??
        data['email']?.toString().split('@').first ??
        l10n.vendorDefaultName;
    final isSuspended = data['isSuspended'] == true;
    final phone = data['phoneNumber']?.toString().trim() ??
        data['phone']?.toString().trim() ??
        '';

    final createdAt = data['createdAt'];
    DateTime? regDate;
    if (createdAt is Timestamp) regDate = createdAt.toDate();
    final regDateStr = regDate != null ? DateFormat.yMMMd().format(regDate) : '—';

    final theme = Theme.of(context);
    final nameStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: AppColors.ink,
      letterSpacing: -0.2,
    );

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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.rose.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      shopName.isNotEmpty ? shopName.characters.first.toUpperCase() : 'V',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: nameStyle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Registered · $regDateStr',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.inkMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusBadge(
                    isOnline: isOnline,
                    isSuspended: isSuspended,
                    l10n: l10n,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: statsAsync.when(
                  loading: () => const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.rosePrimary,
                      ),
                    ),
                  ),
                  error: (_, __) => Center(
                    child: Text(
                      'Unable to load stats',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  data: (stats) {
                    final num totalGrossSales = _asNum(data['totalGrossSales']);
                    final num rehanRoseCommission = _asNum(data['rehanRoseCommission']);
                    final num vendorEarnings = _asNum(data['vendorEarnings']);
                    final int completedOrdersFromDoc = _asInt(data['completedOrders']);
                    final completedOrders =
                        completedOrdersFromDoc > 0 ? completedOrdersFromDoc : stats.completedOrders;

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _PremiumStat(
                                  icon: Icons.eco_outlined,
                                  value: '${stats.bouquetCount}',
                                  label: l10n.adminVendorPublishedBouquets,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PremiumStat(
                                  icon: Icons.check_circle_outline,
                                  value: '$completedOrders',
                                  label: l10n.adminVendorCompletedOrders,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _FinancialReport(
                            totalGrossSales: totalGrossSales,
                            rehanRoseCommission: rehanRoseCommission,
                            vendorEarnings: vendorEarnings,
                            l10n: l10n,
                            onGenerateReport: () => _openFinancialReport(
                              context,
                              vendorName: shopName,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Divider(color: Colors.grey.shade200, height: 24),
              Padding(
                padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _setSuspended(context, !isSuspended);
                        },
                        icon: Icon(isSuspended ? Icons.check_circle_outline : Icons.block, size: 18),
                        label: Text(isSuspended ? 'Unsuspend' : 'Suspend'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          foregroundColor:
                              isSuspended ? const Color(0xFF059669) : const Color(0xFFF97316),
                          side: BorderSide(
                            color: (isSuspended ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                                .withValues(alpha: 0.75),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          await _openEditModal(
                            context,
                            initialName: shopName,
                            initialPhone: phone,
                          );
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          backgroundColor: AppColors.ink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumStat extends StatelessWidget {
  const _PremiumStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade200),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: AppColors.inkMuted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.inkMuted,
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
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.isOnline,
    required this.isSuspended,
    required this.l10n,
  });

  final bool isOnline;
  final bool isSuspended;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String text;
    if (isSuspended) {
      color = const Color(0xFFF97316);
      text = 'Suspended';
    } else {
      color = isOnline ? const Color(0xFF10B981) : Colors.grey;
      text = isOnline ? 'Online' : 'Offline';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _FinancialReport extends StatelessWidget {
  const _FinancialReport({
    required this.totalGrossSales,
    required this.rehanRoseCommission,
    required this.vendorEarnings,
    required this.l10n,
    this.onGenerateReport,
  });

  final num totalGrossSales;
  final num rehanRoseCommission;
  final num vendorEarnings;
  final AppLocalizations l10n;
  final VoidCallback? onGenerateReport;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Financial Breakdown',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                ),
              ),
              if (onGenerateReport != null)
                IconButton(
                  onPressed: onGenerateReport,
                  icon: const Icon(Icons.date_range_rounded, size: 20),
                  tooltip: 'Generate financial report',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade50,
                    foregroundColor: AppColors.ink,
                    padding: const EdgeInsets.all(10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF8F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _FinanceRow(
                  label: l10n.adminVendorTotalGrossSales,
                  value: '${fmt.format(totalGrossSales)} IQD',
                ),
                Divider(color: Colors.grey.shade200, height: 18),
                _FinanceRow(
                  label: l10n.adminVendorRehanCommission,
                  value: '${fmt.format(rehanRoseCommission)} IQD',
                  valueColor: AppColors.rosePrimary,
                ),
                Divider(color: Colors.grey.shade200, height: 18),
                _FinanceRow(
                  label: l10n.adminVendorEarnings,
                  value: '${fmt.format(vendorEarnings)} IQD',
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodFinancials {
  const _PeriodFinancials({
    required this.start,
    required this.end,
    required this.totalSales,
    required this.rehanRoseCommission,
    required this.vendorPayout,
    required this.completedOrders,
    required this.commissionRate,
  });

  final DateTime start;
  final DateTime end;
  final num totalSales;
  final num rehanRoseCommission;
  final num vendorPayout;
  final int completedOrders;
  final double commissionRate;
}

class _VendorFinancialReportSheet extends StatelessWidget {
  const _VendorFinancialReportSheet({
    required this.vendorName,
    required this.future,
  });

  final String vendorName;
  final Future<_PeriodFinancials> future;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final dateFmt = DateFormat.yMMMd();

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: FutureBuilder<_PeriodFinancials>(
          future: future,
          builder: (context, snap) {
            final isLoading = snap.connectionState == ConnectionState.waiting;
            final hasError = snap.hasError;
            final data = snap.data;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Financial Report: $vendorName',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (data != null)
                  Text(
                    '${dateFmt.format(data.start)} - ${dateFmt.format(data.end)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkMuted,
                          fontWeight: FontWeight.w600,
                        ),
                  )
                else
                  Text(
                    'Selected date range',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkMuted,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.75)),
                  ),
                  child: isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.rosePrimary,
                              ),
                            ),
                          ),
                        )
                      : hasError
                          ? Text(
                              'Unable to generate report. Please try again.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _BigMoneyLine(
                                  label: 'Total Sales',
                                  value: '${fmt.format(data!.totalSales)} IQD',
                                  valueColor: AppColors.ink,
                                ),
                                const SizedBox(height: 10),
                                _BigMoneyLine(
                                  label:
                                      'Rehan Rose Commission (${(data.commissionRate * 100).toStringAsFixed(0)}%)',
                                  value: '${fmt.format(data.rehanRoseCommission)} IQD',
                                  valueColor: AppColors.rosePrimary,
                                ),
                                const SizedBox(height: 10),
                                _BigMoneyLine(
                                  label: 'Vendor Payout',
                                  value: '${fmt.format(data.vendorPayout)} IQD',
                                  valueColor: const Color(0xFF059669),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(height: 1),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _SmallStat(
                                        label: 'Completed Orders',
                                        value: '${data.completedOrders}',
                                        icon: Icons.check_circle_outline,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _SmallStat(
                                        label: 'Days',
                                        value:
                                            '${data.end.difference(data.start).inDays + 1}',
                                        icon: Icons.calendar_today_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BigMoneyLine extends StatelessWidget {
  const _BigMoneyLine({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
        ),
      ],
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.inkMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

num _asNum(Object? v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v.replaceAll(',', '')) ?? 0;
  return 0;
}

int _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.replaceAll(',', '')) ?? 0;
  return 0;
}

class _FinanceRow extends StatelessWidget {
  const _FinanceRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.labelLarge!.copyWith(
                fontWeight: FontWeight.w800,
                color: valueColor ?? AppColors.ink,
              ),
        ),
      ],
    );
  }
}
