import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../widgets/layout/section_container.dart';

/// Earnings: today/weekly revenue, completed orders, next payout.
class VendorEarningsPage extends StatelessWidget {
  const VendorEarningsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SectionContainer(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Earnings',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Revenue and payout summary.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _EarningsCard(
                  title: "Today's revenue",
                  value: 'IQD 0',
                ),
                _EarningsCard(
                  title: 'Weekly revenue',
                  value: 'IQD 0',
                ),
                _EarningsCard(
                  title: 'Completed orders',
                  value: '0',
                ),
                _EarningsCard(
                  title: 'Next payout',
                  value: '—',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  final String title;
  final String value;

  const _EarningsCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
