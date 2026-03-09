import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../controllers/controllers.dart';
import '../../../l10n/app_localizations.dart';

/// Super Admin: Vendors Management. Grid of approved vendors with stats and quick actions.
class AdminVendorsManagementPage extends ConsumerWidget {
  const AdminVendorsManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final vendorsAsync = ref.watch(approvedVendorsStreamProvider);
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width < kMobileBreakpoint ? 1 : 3;
    final childAspectRatio = width < kMobileBreakpoint ? 1.4 : 0.95;
    final mainAxisSpacing = width < kMobileBreakpoint ? 12.0 : 16.0;
    final crossAxisSpacing = width < kMobileBreakpoint ? 0.0 : 16.0;

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
          child: vendorsAsync.when(
            loading: () => Center(
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
            ),
            error: (_, __) => Center(
              child: Text(
                l10n.adminUnableToLoadApplications,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkMuted,
                    ),
              ),
            ),
            data: (snapshot) {
              final docs = snapshot.docs;
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
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  mainAxisSpacing: mainAxisSpacing,
                  crossAxisSpacing: crossAxisSpacing,
                  mainAxisExtent: null,
                ),
                padding: const EdgeInsets.only(bottom: 32),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  return _AdminVendorCard(
                    vendorId: doc.id,
                    data: doc.data(),
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
  });

  final String vendorId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final statsAsync = ref.watch(vendorStatsProvider(vendorId));

    final shopName = data['shopName']?.toString().trim() ??
        data['displayName']?.toString().trim() ??
        data['email']?.toString().split('@').first ??
        l10n.vendorDefaultName;
    final isOnline = data['isOnline'] == true;
    final phone = data['phoneNumber']?.toString().trim() ?? data['phone']?.toString().trim() ?? '';
    final createdAt = data['createdAt'];
    DateTime? regDate;
    if (createdAt is Timestamp) regDate = createdAt.toDate();
    final regDateStr = regDate != null
        ? DateFormat.yMMMd().format(regDate)
        : '—';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        shopName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkCharcoal,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _StatusIndicator(isOnline: isOnline, l10n: l10n),
                  ],
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: l10n.adminVendorRegDate,
                  value: regDateStr,
                ),
                statsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.rosePrimary,
                        ),
                      ),
                    ),
                  ),
                  error: (_, __) => const SizedBox(height: 8),
                  data: (stats) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        _DetailRow(
                          icon: Icons.eco_outlined,
                          label: l10n.adminVendorPublishedBouquets,
                          value: '${stats.bouquetCount}',
                        ),
                        const SizedBox(height: 4),
                        _DetailRow(
                          icon: Icons.check_circle_outline,
                          label: l10n.adminVendorCompletedOrders,
                          value: '${stats.completedOrders}',
                        ),
                        const SizedBox(height: 12),
                        _FinancialSection(
                          totalRevenue: stats.totalRevenue,
                          l10n: l10n,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (phone.isNotEmpty)
                  IconButton(
                    onPressed: () => _launchWhatsApp(phone),
                    icon: FaIcon(
                      FontAwesomeIcons.whatsapp,
                      size: 20,
                      color: AppColors.inkMuted,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.border.withValues(alpha: 0.5),
                      padding: const EdgeInsets.all(10),
                    ),
                    tooltip: l10n.adminVendorWhatsAppCall,
                  ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: AppColors.inkMuted, size: 22),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'suspend') {
                      // TODO: Implement suspend
                    } else if (value == 'edit') {
                      // TODO: Implement edit
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'suspend',
                      child: Row(
                        children: [
                          Icon(Icons.block, size: 20, color: AppColors.inkMuted),
                          const SizedBox(width: 12),
                          Text(l10n.adminVendorSuspend),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20, color: AppColors.inkMuted),
                          const SizedBox(width: 12),
                          Text(l10n.adminVendorEdit),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchWhatsApp(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse(
      'https://wa.me/${cleaned.startsWith('+') ? cleaned.substring(1) : cleaned}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.isOnline, required this.l10n});

  final bool isOnline;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? const Color(0xFF10B981) : AppColors.inkMuted;
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
            isOnline ? l10n.adminVendorActive : l10n.adminVendorOffline,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.inkMuted),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w500,
                ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkCharcoal,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinancialSection extends StatelessWidget {
  const _FinancialSection({
    required this.totalRevenue,
    required this.l10n,
  });

  final num totalRevenue;
  final AppLocalizations l10n;

  static const double _commissionRate = 0.15;
  static const double _vendorShareRate = 0.85;

  @override
  Widget build(BuildContext context) {
    final commission = totalRevenue * _commissionRate;
    final vendorEarnings = totalRevenue * _vendorShareRate;
    final fmt = NumberFormat('#,###', 'en_US');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.badgeGoldBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FinanceRow(
            label: l10n.adminVendorTotalGrossSales,
            value: '${fmt.format(totalRevenue)} IQD',
            highlight: false,
          ),
          const SizedBox(height: 6),
          _FinanceRow(
            label: l10n.adminVendorRehanCommission,
            value: '${fmt.format(commission)} IQD',
            highlight: true,
            accentColor: AppColors.rosePrimary,
          ),
          const SizedBox(height: 6),
          _FinanceRow(
            label: l10n.adminVendorEarnings,
            value: '${fmt.format(vendorEarnings)} IQD',
            highlight: false,
          ),
        ],
      ),
    );
  }
}

class _FinanceRow extends StatelessWidget {
  const _FinanceRow({
    required this.label,
    required this.value,
    required this.highlight,
    this.accentColor,
  });

  final String label;
  final String value;
  final bool highlight;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final textColor = accentColor ?? (highlight ? AppColors.rosePrimary : AppColors.inkCharcoal);
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
          style: Theme.of(context).textTheme.labelMedium!.copyWith(
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
