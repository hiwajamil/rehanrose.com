import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../controllers/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/layout/section_container.dart';

class VendorEarningsPage extends ConsumerWidget {
  const VendorEarningsPage({super.key});

  static const double _commissionRate = 0.15;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);

    return authAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildShell(
        context,
        child: _EmptyState(
          title: 'Earnings unavailable',
          subtitle: 'Please try again.',
        ),
      ),
      data: (user) {
        if (user == null) {
          return _buildShell(
            context,
            child: _EmptyState(
              title: 'Sign in required',
              subtitle: 'Please sign in to view your earnings.',
            ),
          );
        }

        final stream = FirebaseFirestore.instance
            .collection('orders')
            .where('vendorId', isEqualTo: user.uid)
            .snapshots();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              debugPrint('VendorEarningsPage stream error: ${snap.error}');
              final errorText = snap.error?.toString();
              return _buildShell(
                context,
                child: _EmptyState(
                  title: 'Could not load earnings',
                  subtitle: (kDebugMode && errorText != null && errorText.isNotEmpty)
                      ? errorText
                      : 'Please refresh the page.',
                ),
              );
            }

            final docs = snap.data?.docs ?? const [];
            final transactions = docs
                .map((d) => _TransactionRow.fromDoc(
                      d,
                      commissionRate: _commissionRate,
                    ))
                .where((t) => t.isCompleted)
                .toList();
            transactions.sort((a, b) {
              final aMs = a.createdAt?.millisecondsSinceEpoch ?? 0;
              final bMs = b.createdAt?.millisecondsSinceEpoch ?? 0;
              return bMs.compareTo(aMs);
            });

            final grossSales = transactions.fold<num>(0, (acc, t) => acc + t.totalPrice);
            final myNetEarnings = transactions.fold<num>(0, (acc, t) => acc + t.myEarning);
            final completedOrders = transactions.length;
            final pendingPayout =
                transactions.where((t) => !t.paidOut).fold<num>(0, (acc, t) => acc + t.myEarning);
            final last7DaysNet = _computeLast7DaysNetEarnings(transactions);

            return _buildShell(
              context,
              child: _EarningsBody(
                grossSales: grossSales,
                myNetEarnings: myNetEarnings,
                completedOrders: completedOrders,
                pendingPayout: pendingPayout,
                transactions: transactions.take(20).toList(),
                last7DaysNet: last7DaysNet,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShell(BuildContext context, {required Widget child}) {
    return SingleChildScrollView(
      child: SectionContainer(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: child,
      ),
    );
  }
}

class _EarningsBody extends StatelessWidget {
  const _EarningsBody({
    required this.grossSales,
    required this.myNetEarnings,
    required this.completedOrders,
    required this.pendingPayout,
    required this.transactions,
    required this.last7DaysNet,
  });

  final num grossSales;
  final num myNetEarnings;
  final int completedOrders;
  final num pendingPayout;
  final List<_TransactionRow> transactions;
  final List<num> last7DaysNet;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 980;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Earnings',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'A transparent breakdown of your sales, commission, and payouts.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.inkMuted,
                height: 1.35,
              ),
        ),
        const SizedBox(height: 24),
        _SummaryGrid(
          grossSales: grossSales,
          myNetEarnings: myNetEarnings,
          completedOrders: completedOrders,
          pendingPayout: pendingPayout,
        ),
        const SizedBox(height: 20),
        _ChartSection(isNarrow: isNarrow, last7DaysNet: last7DaysNet),
        const SizedBox(height: 20),
        _TransactionsSection(
          isNarrow: isNarrow,
          transactions: transactions,
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.grossSales,
    required this.myNetEarnings,
    required this.completedOrders,
    required this.pendingPayout,
  });

  final num grossSales;
  final num myNetEarnings;
  final int completedOrders;
  final num pendingPayout;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        int columns = 1;
        if (w >= 1200) {
          columns = 4;
        } else if (w >= 820) {
          columns = 2;
        }

        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.9,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _KpiCard(
              title: 'Total Gross Sales',
              value: _formatIqd(grossSales),
              subtitle: 'Total value of flowers sold',
              icon: Icons.payments_outlined,
              tint: AppColors.rose.withValues(alpha: 0.10),
              iconColor: AppColors.rosePrimary,
            ),
            _KpiCard(
              title: 'My Net Earnings',
              value: _formatIqd(myNetEarnings),
              subtitle: "After Rehan Rose’s 15% commission",
              icon: Icons.account_balance_wallet_outlined,
              isFeatured: true,
              tint: AppColors.badgeGoldBackground,
              iconColor: AppColors.accentGold,
            ),
            _KpiCard(
              title: 'Completed Orders',
              value: _formatInt(completedOrders),
              subtitle: 'Ready / delivered orders',
              icon: Icons.check_circle_outline,
              tint: AppColors.sage.withValues(alpha: 0.20),
              iconColor: AppColors.forestGreen,
            ),
            _KpiCard(
              title: 'Pending Payout',
              value: _formatIqd(pendingPayout),
              subtitle: 'Orders not marked as paid out',
              icon: Icons.schedule_outlined,
              tint: AppColors.rose.withValues(alpha: 0.08),
              iconColor: AppColors.rose,
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.iconColor,
    this.isFeatured = false,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final bool isFeatured;

  @override
  Widget build(BuildContext context) {
    final border = isFeatured ? AppColors.accentGold.withValues(alpha: 0.55) : AppColors.border;
    final shadowAlpha = isFeatured ? 0.07 : 0.05;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: shadowAlpha),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: tint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w500,
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

class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.isNarrow,
    required this.last7DaysNet,
  });

  final bool isNarrow;
  final List<num> last7DaysNet;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List<DateTime>.generate(7, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)));

    final values = last7DaysNet.length == 7 ? last7DaysNet : List<num>.filled(7, 0);
    final maxValue = values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);
    final maxY = maxValue <= 0 ? 1.0 : (maxValue * 1.20).toDouble();

    return Container(
      padding: EdgeInsets.all(isNarrow ? 18 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earnings Last 7 Days',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Daily net earnings (IQD)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 230,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.7),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      interval: maxY / 4,
                      getTitlesWidget: (v, meta) {
                        final label = _formatCompactIqd(v);
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Text(
                            label,
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
                        final label = DateFormat.E().format(days[idx]);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            label,
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.ink,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        _formatIqd(rod.toY),
                        GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (int i = 0; i < values.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: values[i].toDouble(),
                          width: 16,
                          borderRadius: BorderRadius.circular(6),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              AppColors.rosePrimary.withValues(alpha: 0.90),
                              AppColors.rose.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionsSection extends StatelessWidget {
  const _TransactionsSection({
    required this.isNarrow,
    required this.transactions,
  });

  final bool isNarrow;
  final List<_TransactionRow> transactions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isNarrow ? 18 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Transactions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Completed orders with a transparent 15% Rehan Rose cut.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 14),
          if (transactions.isEmpty)
            const _EmptyState(
              title: 'No completed transactions yet',
              subtitle: 'Once orders reach ready/delivered, they will appear here.',
            )
          else if (isNarrow)
            _TransactionsList(transactions: transactions)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _TransactionsTable(transactions: transactions),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  flex: 2,
                  child: _InsightsSidePanel(),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _InsightsSidePanel extends StatelessWidget {
  const _InsightsSidePanel();

  static const _roseGold = Color(0xFFC07C88);
  static const _deepPlum = Color(0xFF2A1640);
  static const _softGold = Color(0xFFD4AF37);

  static const _bouquetImageUrl =
      'https://images.unsplash.com/photo-1525310072745-f49212b5ac6d?auto=format&fit=crop&w=320&q=80';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insights & Performance',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A quick snapshot of what’s selling best.',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sales Breakdown',
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 14),
          _SalesBreakdownDonut(
            roseGold: _roseGold,
            deepPlum: _deepPlum,
            softGold: _softGold,
          ),
          const SizedBox(height: 16),
          Divider(color: AppColors.border.withValues(alpha: 0.8), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.star, size: 18, color: AppColors.accentGold),
              const SizedBox(width: 8),
              Text(
                'Top Performer',
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: _bouquetImageUrl,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 72,
                    height: 72,
                    color: AppColors.background.withValues(alpha: 0.35),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 72,
                    height: 72,
                    color: AppColors.background.withValues(alpha: 0.35),
                    child: Icon(Icons.local_florist, color: AppColors.inkMuted),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Royal Crimson Elegance',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '24 Sold this month',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Revenue: IQD 840,000',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _roseGold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalesBreakdownDonut extends StatelessWidget {
  const _SalesBreakdownDonut({
    required this.roseGold,
    required this.deepPlum,
    required this.softGold,
  });

  final Color roseGold;
  final Color deepPlum;
  final Color softGold;

  @override
  Widget build(BuildContext context) {
    const sections = [
      _SalesSlice(label: 'Anniversaries', percent: 55, colorSlot: 0),
      _SalesSlice(label: 'Birthdays', percent: 30, colorSlot: 1),
      _SalesSlice(label: 'Bridal', percent: 15, colorSlot: 2),
    ];

    Color colorFor(int slot) {
      return switch (slot) {
        0 => roseGold,
        1 => deepPlum,
        _ => softGold,
      };
    }

    return Column(
      children: [
        SizedBox(
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  centerSpaceRadius: 46,
                  sectionsSpace: 3,
                  startDegreeOffset: -90,
                  borderData: FlBorderData(show: false),
                  sections: [
                    for (final s in sections)
                      PieChartSectionData(
                        value: s.percent.toDouble(),
                        color: colorFor(s.colorSlot),
                        radius: 22,
                        showTitle: false,
                      ),
                  ],
                ),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
              ),
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
                ),
                alignment: Alignment.center,
                child: Text(
                  'This\nmonth',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkMuted,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final s in sections)
              _LegendIndicator(
                color: colorFor(s.colorSlot),
                label: '${s.percent}% ${s.label}',
              ),
          ],
        ),
      ],
    );
  }
}

class _LegendIndicator extends StatelessWidget {
  const _LegendIndicator({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.inkMuted,
          ),
        ),
      ],
    );
  }
}

class _SalesSlice {
  const _SalesSlice({
    required this.label,
    required this.percent,
    required this.colorSlot,
  });

  final String label;
  final int percent;
  final int colorSlot;
}

class _TransactionsTable extends StatelessWidget {
  const _TransactionsTable({required this.transactions});

  final List<_TransactionRow> transactions;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 44,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 56,
        headingTextStyle: GoogleFonts.montserrat(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: AppColors.inkMuted,
        ),
        dataTextStyle: GoogleFonts.montserrat(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: AppColors.ink,
        ),
        columns: const [
          DataColumn(label: Text('Order ID')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Total Price')),
          DataColumn(label: Text('Rehan Rose Cut (15%)')),
          DataColumn(label: Text('Vendor Earning (85%)')),
        ],
        rows: [
          for (final t in transactions)
            DataRow(
              cells: [
                DataCell(Text(t.orderId)),
                DataCell(Text(_formatDate(t.createdAt))),
                DataCell(Text(_formatIqd(t.totalPrice))),
                DataCell(Text(_formatIqd(t.rehanRoseCut))),
                DataCell(
                  Text(
                    _formatIqd(t.myEarning),
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: AppColors.forestGreen,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TransactionsList extends StatelessWidget {
  const _TransactionsList({required this.transactions});

  final List<_TransactionRow> transactions;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final t = transactions[idx];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.orderId,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  Text(
                    _formatDate(t.createdAt),
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _KeyValueRow(label: 'Total Price', value: _formatIqd(t.totalPrice)),
              const SizedBox(height: 6),
              _KeyValueRow(
                label: 'Rehan Rose Cut (15%)',
                value: _formatIqd(t.rehanRoseCut),
              ),
              const SizedBox(height: 6),
              _KeyValueRow(
                label: 'My Earning',
                value: _formatIqd(t.myEarning),
                valueColor: AppColors.forestGreen,
                valueBold: true,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueBold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool valueBold;

  @override
  Widget build(BuildContext context) {
    final valueStyle = GoogleFonts.montserrat(
      fontWeight: valueBold ? FontWeight.w800 : FontWeight.w700,
      fontSize: 12,
      color: valueColor ?? AppColors.ink,
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.inkMuted,
            ),
          ),
        ),
        Text(value, style: valueStyle),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
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

class _TransactionRow {
  const _TransactionRow({
    required this.orderId,
    required this.createdAt,
    required this.totalPrice,
    required this.rehanRoseCut,
    required this.myEarning,
    required this.status,
    required this.paidOut,
  });

  final String orderId;
  final DateTime? createdAt;
  final num totalPrice;
  final num rehanRoseCut;
  final num myEarning;
  final String status;
  final bool paidOut;

  bool get isCompleted => status == 'ready' || status == 'delivered';

  static _TransactionRow fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required double commissionRate,
  }) {
    final data = doc.data();
    final status = (data['status'] ?? '').toString().trim().toLowerCase();

    DateTime? createdAt;
    final ts = data['timestamp'] ?? data['createdAt'];
    if (ts is Timestamp) createdAt = ts.toDate();
    if (ts is DateTime) createdAt = ts;
    if (ts != null && createdAt == null) createdAt = DateTime.tryParse(ts.toString());

    final totalRaw = data['totalPrice'];
    final num total = totalRaw is num ? totalRaw : num.tryParse(totalRaw?.toString() ?? '') ?? 0;

    final paidOutRaw = data['paidOut'];
    final paidOut = paidOutRaw == true;

    final num cut = total * commissionRate;
    final num my = total * (1 - commissionRate);

    return _TransactionRow(
      orderId: (data['orderId']?.toString().isNotEmpty ?? false) ? data['orderId'].toString() : doc.id,
      createdAt: createdAt,
      totalPrice: total,
      rehanRoseCut: cut,
      myEarning: my,
      status: status,
      paidOut: paidOut,
    );
  }
}

List<num> _computeLast7DaysNetEarnings(List<_TransactionRow> transactions) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(const Duration(days: 6));
  final buckets = List<num>.filled(7, 0);

  for (final t in transactions) {
    final dt = t.createdAt;
    if (dt == null) continue;

    final day = DateTime(dt.year, dt.month, dt.day);
    if (day.isBefore(start) || day.isAfter(today)) continue;

    final idx = day.difference(start).inDays;
    if (idx < 0 || idx >= buckets.length) continue;
    buckets[idx] = buckets[idx] + t.myEarning;
  }

  return buckets;
}

String _formatIqd(num value) {
  final fmt = NumberFormat('#,##0', 'en_US');
  return 'IQD ${fmt.format(value.round())}';
}

String _formatCompactIqd(num value) {
  final v = value.abs();
  if (v >= 1000000) {
    final m = (value / 1000000).toStringAsFixed(1);
    return '${m}M';
  }
  if (v >= 1000) {
    final k = (value / 1000).toStringAsFixed(0);
    return '${k}k';
  }
  return value.toStringAsFixed(0);
}

String _formatInt(int value) {
  final fmt = NumberFormat('#,##0', 'en_US');
  return fmt.format(value);
}

String _formatDate(DateTime? dt) {
  if (dt == null) return '—';
  return DateFormat('yyyy-MM-dd').format(dt);
}
