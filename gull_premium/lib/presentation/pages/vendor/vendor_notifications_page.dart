import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../widgets/layout/section_container.dart';

/// Notifications list; mark as read clears badge.
class VendorNotificationsPage extends StatelessWidget {
  const VendorNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SectionContainer(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Mark as read to clear the unread badge.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.notifications_none,
                        size: 48, color: AppColors.inkMuted),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
