import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import '../presentation/widgets/notifications/in_app_notifications_list.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

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
            'Notifications',
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
              'Please sign in to view your notifications.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Notifications',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.inkCharcoal,
          ),
        ),
      ),
      body: InAppNotificationsList(userId: user.uid),
    );
  }
}
