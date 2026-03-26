import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_format_utils.dart';
import '../../widgets/layout/section_container.dart';

enum _RevenueTimeRange { today, thisWeek, thisMonth, allTime }

class RevenueAnalyticsScreen extends StatefulWidget {
  const RevenueAnalyticsScreen({super.key});

  @override
  State<RevenueAnalyticsScreen> createState() => _RevenueAnalyticsScreenState();
}

class _RevenueBucket {
  _RevenueBucket({
    required this.keyDate,
    required this.bouquetRevenue,
    required this.perfumeRevenue,
  });

  final DateTime keyDate; // Day (y/m/d) or month (y/m/1) bucket key.
  final double bouquetRevenue;
  final double perfumeRevenue;

  double get total => bouquetRevenue + perfumeRevenue;
}

class _RevenueAnalyticsScreenState extends State<RevenueAnalyticsScreen> {
  // Admin takes 10% from vendors.
  final double appCommissionRate = 0.10;

  bool _isLoading = true;
  String? _error;

  _RevenueTimeRange _range = _RevenueTimeRange.thisMonth;

  double totalGrossRevenue = 0; // Sum of completed order totalPrice.
  double bouquetRevenue = 0;
  double perfumeRevenue = 0;
  double totalExpenses = 0;

  double netProfit = 0; // (grossRevenue * commission) - expenses.

  List<_RevenueBucket> _buckets = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rangeDates = _rangeDates(_range);

      final ordersFuture = _fetchCompletedLegacyOrders(
        start: rangeDates?.$1,
        end: rangeDates?.$2,
      );
      final omsFuture = _fetchCompletedOmsOrders(
        start: rangeDates?.$1,
        end: rangeDates?.$2,
      );
      final expensesFuture = _fetchExpenses(
        start: rangeDates?.$1,
        end: rangeDates?.$2,
      );

      final results = await Future.wait([
        ordersFuture,
        omsFuture,
        expensesFuture,
      ]);

      final ordersDocs = results[0];
      final omsDocs = results[1];
      final expenseDocs = results[2];

      final buckets = _emptyBucketsForRange(_range);
      final keyToIndex = <DateTime, int>{
        for (int i = 0; i < buckets.length; i++) buckets[i].keyDate: i
      };

      // Mutable bucket totals; we finalize them into _RevenueBucket list.
      final mutableBouquet = List<double>.filled(buckets.length, 0);
      final mutablePerfume = List<double>.filled(buckets.length, 0);

      double gross = 0;
      double bouquet = 0;
      double perfume = 0;

      for (final doc in ordersDocs) {
        final data = doc.data();

        final totalPrice = _numFromDynamic(data['totalPrice'])?.toDouble() ?? 0;
        if (totalPrice <= 0) continue;

        final analyticsDate = _docDateTime(data['timestamp']) ?? _docDateTime(data['createdAt']);
        if (analyticsDate == null) continue;

        final isPerfume = _legacyOrderIsPerfume(data);

        gross += totalPrice;
        if (isPerfume) {
          perfume += totalPrice;
        } else {
          bouquet += totalPrice;
        }

        final key = _bucketKeyForRange(_range, analyticsDate);
        final idx = keyToIndex[key];
        if (idx != null) {
          if (isPerfume) {
            mutablePerfume[idx] += totalPrice;
          } else {
            mutableBouquet[idx] += totalPrice;
          }
        }
      }

      for (final doc in omsDocs) {
        final data = doc.data();
        final totalPriceRaw = data['totalPrice'];
        final totalPrice = _numFromDynamic(totalPriceRaw)?.toDouble() ?? 0;
        if (totalPrice <= 0) continue;

        final analyticsDate = _docDateTime(data['createdAt']);
        if (analyticsDate == null) continue;

        final isPerfume = _omsOrderIsPerfume(data);

        gross += totalPrice;
        if (isPerfume) {
          perfume += totalPrice;
        } else {
          bouquet += totalPrice;
        }

        final key = _bucketKeyForRange(_range, analyticsDate);
        final idx = keyToIndex[key];
        if (idx != null) {
          if (isPerfume) {
            mutablePerfume[idx] += totalPrice;
          } else {
            mutableBouquet[idx] += totalPrice;
          }
        }
      }

      double expensesSum = 0;
      for (final doc in expenseDocs) {
        final data = doc.data();
        expensesSum += _numFromDynamic(data['amount'])?.toDouble() ?? 0;
      }

      final adminEarnings = gross * appCommissionRate;
      final profit = adminEarnings - expensesSum;

      setState(() {
        totalGrossRevenue = gross;
        bouquetRevenue = bouquet;
        perfumeRevenue = perfume;
        totalExpenses = expensesSum;
        netProfit = profit;
        _buckets = List.generate(buckets.length, (i) {
          return _RevenueBucket(
            keyDate: buckets[i].keyDate,
            bouquetRevenue: mutableBouquet[i],
            perfumeRevenue: mutablePerfume[i],
          );
        });
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('RevenueAnalyticsScreen refresh error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Unable to load revenue analytics.';
      });
    }
  }

  (DateTime, DateTime)? _rangeDates(_RevenueTimeRange range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

    switch (range) {
      case _RevenueTimeRange.today:
        return (today, endOfDay(today));
      case _RevenueTimeRange.thisWeek:
        final start = today.subtract(const Duration(days: 6));
        return (start, endOfDay(today));
      case _RevenueTimeRange.thisMonth:
        final first = DateTime(now.year, now.month, 1);
        final last = DateTime(now.year, now.month + 1, 0);
        return (first, endOfDay(last));
      case _RevenueTimeRange.allTime:
        return null;
    }
  }

  List<_RevenueBucket> _emptyBucketsForRange(_RevenueTimeRange range) {
    final now = DateTime.now();
    DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
    DateTime monthKey(DateTime d) => DateTime(d.year, d.month, 1);

    if (range == _RevenueTimeRange.today) {
      final key = dayKey(now);
      return [
        _RevenueBucket(keyDate: key, bouquetRevenue: 0, perfumeRevenue: 0),
      ];
    }

    if (range == _RevenueTimeRange.thisWeek) {
      final start = dayKey(now.subtract(const Duration(days: 6)));
      return List.generate(7, (i) {
        final d = start.add(Duration(days: i));
        return _RevenueBucket(keyDate: dayKey(d), bouquetRevenue: 0, perfumeRevenue: 0);
      });
    }

    if (range == _RevenueTimeRange.thisMonth) {
      final last = DateTime(now.year, now.month + 1, 0);
      final totalDays = last.day;
      return List.generate(totalDays, (i) {
        final d = DateTime(now.year, now.month, 1 + i);
        return _RevenueBucket(keyDate: dayKey(d), bouquetRevenue: 0, perfumeRevenue: 0);
      });
    }

    // All time: chart last 12 months to avoid overflow.
    const maxMonths = 12;
    final thisMonthKey = monthKey(now);
    final start = DateTime(thisMonthKey.year, thisMonthKey.month - (maxMonths - 1), 1);
    return List.generate(maxMonths, (i) {
      final d = DateTime(start.year, start.month + i, 1);
      return _RevenueBucket(keyDate: monthKey(d), bouquetRevenue: 0, perfumeRevenue: 0);
    });
  }

  DateTime _bucketKeyForRange(_RevenueTimeRange range, DateTime d) {
    switch (range) {
      case _RevenueTimeRange.today:
      case _RevenueTimeRange.thisWeek:
      case _RevenueTimeRange.thisMonth:
        return DateTime(d.year, d.month, d.day);
      case _RevenueTimeRange.allTime:
        return DateTime(d.year, d.month, 1);
    }
  }

  String _formatIqd(double value) {
    final intValue = value.isFinite ? value.round() : 0;
    return 'IQD ${formatPriceIqd(intValue)}';
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchCompletedLegacyOrders({
    required DateTime? start,
    required DateTime? end,
  }) async {
    // Legacy "orders" collection uses these statuses in the app.
    const completedStatuses = ['ready', 'delivered', 'completed'];
    final firestore = FirebaseFirestore.instance;

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> all = [];
    for (final status in completedStatuses) {
      Query<Map<String, dynamic>> q = firestore
          .collection('orders')
          .where('status', isEqualTo: status);

      if (start != null && end != null) {
        final startTs = Timestamp.fromDate(start);
        final endTs = Timestamp.fromDate(end);
        q = q
            .where('timestamp', isGreaterThanOrEqualTo: startTs)
            .where('timestamp', isLessThanOrEqualTo: endTs)
            .orderBy('timestamp', descending: true);
      }

      final snap = await q.get();
      all.addAll(snap.docs);
    }
    return all;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchCompletedOmsOrders({
    required DateTime? start,
    required DateTime? end,
  }) async {
    // OMS orders for admin/vendors use status: pending → preparing → ready → delivered.
    const completedStatuses = ['ready', 'delivered'];
    final firestore = FirebaseFirestore.instance;

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> all = [];
    for (final status in completedStatuses) {
      Query<Map<String, dynamic>> q = firestore
          .collection('oms_orders')
          .where('status', isEqualTo: status);

      if (start != null && end != null) {
        final startTs = Timestamp.fromDate(start);
        final endTs = Timestamp.fromDate(end);
        q = q
            .where('createdAt', isGreaterThanOrEqualTo: startTs)
            .where('createdAt', isLessThanOrEqualTo: endTs)
            .orderBy('createdAt', descending: true);
      }

      final snap = await q.get();
      all.addAll(snap.docs);
    }
    return all;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchExpenses({
    required DateTime? start,
    required DateTime? end,
  }) async {
    final firestore = FirebaseFirestore.instance;
    Query<Map<String, dynamic>> q = firestore.collection('admin_expenses');

    if (start != null && end != null) {
      final startTs = Timestamp.fromDate(start);
      final endTs = Timestamp.fromDate(end);
      q = q
          .where('timestamp', isGreaterThanOrEqualTo: startTs)
          .where('timestamp', isLessThanOrEqualTo: endTs);
    }

    final snap = await q.get();
    return snap.docs;
  }

  bool _legacyOrderIsPerfume(Map<String, dynamic> data) {
    final codeRaw = (data['bouquetCode'] ?? data['perfumeCode'] ?? data['code'])?.toString() ?? '';
    final code = codeRaw.trim().toUpperCase();
    if (code.isNotEmpty && code.startsWith('PF')) return true;

    String? detailsRaw;
    for (final key in ['bouquetDetails', 'itemLabel', 'bouquetName', 'productType', 'storeCategory', 'itemType']) {
      final v = data[key];
      if (v is String && v.trim().isNotEmpty) {
        detailsRaw = v;
        break;
      }
    }
    if (detailsRaw != null) {
      final s = detailsRaw.toLowerCase();
      if (s.contains('perfume')) return true;
      if (s.contains('item: perfume')) return true;
      if (s.contains('pf-')) return true;
    }

    // Fallback: look for "PF" in bouquetCode-ish fields.
    final bouquetCodeFallback = (data['bouquetCode'] ?? '').toString().trim().toUpperCase();
    if (bouquetCodeFallback.startsWith('PF')) return true;
    return false;
  }

  bool _omsOrderIsPerfume(Map<String, dynamic> data) {
    final bouquetCode = (data['bouquetCode'] ?? '').toString().trim().toUpperCase();
    if (bouquetCode.isNotEmpty && bouquetCode.startsWith('PF')) return true;

    final details = (data['bouquetDetails'] ?? '').toString().toLowerCase();
    if (details.contains('perfume')) return true;
    if (details.contains('item: perfume')) return true;
    if (details.contains('pf-')) return true;
    return false;
  }

  DateTime? _docDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  num? _numFromDynamic(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    final s = value.toString().trim().replaceAll(',', '');
    return num.tryParse(s);
  }

  String _formatBucketTitle(DateTime d) {
    switch (_range) {
      case _RevenueTimeRange.today:
        return DateFormat('MMM d').format(d);
      case _RevenueTimeRange.thisWeek:
        return DateFormat('EEE').format(d);
      case _RevenueTimeRange.thisMonth:
        return DateFormat('d').format(d);
      case _RevenueTimeRange.allTime:
        return DateFormat('MMM').format(d);
    }
  }

  Future<void> _openAddExpenseSheet() async {
    if (!mounted) return;
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
          bool isSaving = false;
          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 12,
                bottom: bottomInset + 12,
              ),
              child: StatefulBuilder(
                builder: (context, setLocalState) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
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
                                      'Add Expense',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.ink,
                                          ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                                    icon: const Icon(Icons.close),
                                    tooltip: 'Close',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: titleController,
                                decoration: InputDecoration(
                                  labelText: 'Expense Title',
                                  prefixIcon: const Icon(Icons.edit_outlined, size: 18),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                ),
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: amountController,
                                decoration: InputDecoration(
                                  labelText: 'Amount (IQD)',
                                  prefixIcon: const Icon(Icons.attach_money_outlined, size: 18),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                                textInputAction: TextInputAction.done,
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: isSaving
                                          ? null
                                          : () async {
                                              final title = titleController.text.trim();
                                              final rawAmount = amountController.text.trim();
                                              final amount = double.tryParse(rawAmount);

                                              if (title.isEmpty) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Expense title is required.')),
                                                );
                                                return;
                                              }
                                              if (amount == null || amount <= 0) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Enter a valid expense amount.')),
                                                );
                                                return;
                                              }

                                              setLocalState(() => isSaving = true);
                                              try {
                                                await FirebaseFirestore.instance
                                                    .collection('admin_expenses')
                                                    .add({
                                                  'title': title,
                                                  'amount': amount,
                                                  'timestamp': FieldValue.serverTimestamp(),
                                                });
                                                if (sheetContext.mounted) {
                                                  Navigator.of(sheetContext).pop();
                                                }
                                                if (mounted) await _refresh();
                                              } catch (e) {
                                                setLocalState(() => isSaving = false);
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Failed to save expense: $e'),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                      icon: const Icon(Icons.check_circle_outline, size: 18),
                                      label: const Text('Save'),
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        backgroundColor: AppColors.forestGreen,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Expenses are stored in Firestore collection `admin_expenses`.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.inkMuted,
                                      fontStyle: FontStyle.italic,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
    } finally {
      titleController.dispose();
      amountController.dispose();
    }
  }

  Widget _buildSummaryCards() {
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < kAdminShellDrawerBreakpoint;

    return isNarrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SummaryMetricCard(
                icon: Icons.summarize_outlined,
                iconBg: AppColors.rosePrimary.withValues(alpha: 0.12),
                iconColor: AppColors.rosePrimary,
                title: 'Gross Revenue (Total)',
                value: _formatIqd(totalGrossRevenue),
                valueColor: AppColors.ink,
              ),
              const SizedBox(height: 14),
              _SummaryMetricCard(
                icon: Icons.category_outlined,
                iconBg: const Color(0xFF7B61FF).withValues(alpha: 0.12),
                iconColor: const Color(0xFF7B61FF),
                title: 'Bouquets vs Perfumes',
                value: 'Bouquets: ${_formatIqd(bouquetRevenue)}\nPerfumes: ${_formatIqd(perfumeRevenue)}',
                valueColor: AppColors.ink,
              ),
              const SizedBox(height: 14),
              _SummaryMetricCard(
                icon: Icons.trending_up_rounded,
                iconBg: AppColors.forestGreen.withValues(alpha: 0.12),
                iconColor: AppColors.forestGreen,
                title: 'Net Profit (App Earnings)',
                value: _formatIqd(netProfit),
                valueColor: AppColors.forestGreen,
              ),
            ],
          )
        : Row(
            children: [
              Expanded(
                child: _SummaryMetricCard(
                  icon: Icons.summarize_outlined,
                  iconBg: AppColors.rosePrimary.withValues(alpha: 0.12),
                  iconColor: AppColors.rosePrimary,
                  title: 'Gross Revenue (Total)',
                  value: _formatIqd(totalGrossRevenue),
                  valueColor: AppColors.ink,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SummaryMetricCard(
                  icon: Icons.category_outlined,
                  iconBg: const Color(0xFF7B61FF).withValues(alpha: 0.12),
                  iconColor: const Color(0xFF7B61FF),
                  title: 'Bouquets vs Perfumes',
                  value: 'Bouquets: ${_formatIqd(bouquetRevenue)}\nPerfumes: ${_formatIqd(perfumeRevenue)}',
                  valueColor: AppColors.ink,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SummaryMetricCard(
                  icon: Icons.trending_up_rounded,
                  iconBg: AppColors.forestGreen.withValues(alpha: 0.12),
                  iconColor: AppColors.forestGreen,
                  title: 'Net Profit (App Earnings)',
                  value: _formatIqd(netProfit),
                  valueColor: AppColors.forestGreen,
                ),
              ),
            ],
          );
  }

  Widget _buildRevenueChart() {
    if (_buckets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          'No completed orders in this period yet.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.inkMuted,
              ),
        ),
      );
    }

    final totals = _buckets.map((b) => b.total).toList();

    final maxTotal = totals.isEmpty ? 0 : totals.reduce((a, b) => a > b ? a : b);
    final maxY = (maxTotal <= 0 ? 1 : maxTotal) * 1.15;

    final bouquetColor = AppColors.rosePrimary;
    final perfumeColor = const Color(0xFF7B61FF);

    // Axis intervals.
    final intervalY = (maxY / 4).ceilToDouble();
    final groupCount = _buckets.length;

    final bottomInterval = switch (_range) {
      _RevenueTimeRange.today => 1,
      _RevenueTimeRange.thisWeek => 1,
      _RevenueTimeRange.thisMonth => groupCount > 20 ? 5 : 2,
      _RevenueTimeRange.allTime => 1,
    };

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < _buckets.length; i++) {
      final b = _buckets[i];
      barGroups.add(
        BarChartGroupData(
          x: i,
          barsSpace: 6,
          barRods: [
            BarChartRodData(
              toY: b.bouquetRevenue,
              color: bouquetColor,
              width: 10,
              borderRadius: BorderRadius.circular(6),
            ),
            BarChartRodData(
              toY: b.perfumeRevenue,
              color: perfumeColor,
              width: 10,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barGroups: barGroups,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.white,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                if (groupIndex < 0 || groupIndex >= _buckets.length) return null;
                final bucket = _buckets[groupIndex];
                final title = _formatBucketTitle(bucket.keyDate);

                final bouquetText = 'Bouquets: ${_formatIqd(bucket.bouquetRevenue)}';
                final perfumeText = 'Perfumes: ${_formatIqd(bucket.perfumeRevenue)}';
                final totalText = 'Total: ${_formatIqd(bucket.total)}';

                final isBouquet = rodIndex == 0;

                return BarTooltipItem(
                  '$title\n'
                  '${isBouquet ? 'Bouquet' : 'Perfume'} value: ${_formatIqd(rod.toY)}\n'
                  '$bouquetText\n'
                  '$perfumeText\n'
                  '$totalText',
                  TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: intervalY,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.border.withValues(alpha: 0.9),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: intervalY,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const Text('');
                  final intVal = value.toInt();
                  return Text(
                    formatPriceIqd(intVal),
                    style: TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: bottomInterval.toDouble(),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= _buckets.length) return const SizedBox.shrink();
                  // Reduce label density for month charts.
                  if (_range == _RevenueTimeRange.thisMonth && (idx % bottomInterval) != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _formatBucketTitle(_buckets[idx].keyDate),
                      style: TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildExpenseManager() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Expense Manager',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openAddExpenseSheet,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Expense'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rosePrimary.withValues(alpha: 0.12),
                  foregroundColor: AppColors.rosePrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Total Expenses: ${_formatIqd(totalExpenses)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkMuted,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Net Profit formula: (Gross Revenue * 10%) - Total Expenses',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < kAdminShellDrawerBreakpoint;

    return SectionContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revenue Analytics',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                          ),
                    ),
                    const SizedBox(height: 8),
                    _RangePicker(
                      value: _range,
                      onChanged: (v) {
                        setState(() => _range = v);
                        _refresh();
                      },
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Revenue Analytics',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                            ),
                      ),
                    ),
                    _RangePicker(
                      value: _range,
                      onChanged: (v) {
                        setState(() => _range = v);
                        _refresh();
                      },
                    ),
                  ],
                ),
          const SizedBox(height: 18),
          if (_isLoading) ...[
            const Center(child: CircularProgressIndicator()),
          ] else if (_error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ] else ...[
            _buildSummaryCards(),
            const SizedBox(height: 18),
            _buildRevenueChart(),
            const SizedBox(height: 18),
            _buildExpenseManager(),
          ],
        ],
      ),
    );
  }
}

class _RangePicker extends StatelessWidget {
  const _RangePicker({
    required this.value,
    required this.onChanged,
  });

  final _RevenueTimeRange value;
  final ValueChanged<_RevenueTimeRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = const <_RevenueTimeRange, String>{
      _RevenueTimeRange.today: 'Today',
      _RevenueTimeRange.thisWeek: 'This Week',
      _RevenueTimeRange.thisMonth: 'This Month',
      _RevenueTimeRange.allTime: 'All Time',
    }.entries;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButton<_RevenueTimeRange>(
        value: value,
        underline: const SizedBox.shrink(),
        isExpanded: true,
        items: [
          for (final e in items)
            DropdownMenuItem<_RevenueTimeRange>(
              value: e.key,
              child: Text(e.value),
            ),
        ],
        onChanged: (v) {
          if (v == null) return;
          onChanged(v);
        },
      ),
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  const _SummaryMetricCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.valueColor,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: valueColor,
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

