import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../widgets/layout/section_container.dart';
import '../../widgets/notifications/in_app_notifications_list.dart';

/// In-app notifications from top-level Firestore [notifications] for the signed-in vendor.
class VendorNotificationsPage extends StatelessWidget {
  const VendorNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final listHeight = (MediaQuery.sizeOf(context).height - 220).clamp(280.0, 720.0);
    return SectionContainer(
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
            'Tap a row to mark it as read and clear the bell badge.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
          const SizedBox(height: 24),
          if (uid.isEmpty)
            Text(
              'Please sign in.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
            )
          else
            SizedBox(
              height: listHeight,
              child: InAppNotificationsList(userId: uid),
            ),
        ],
      ),
    );
  }
}
