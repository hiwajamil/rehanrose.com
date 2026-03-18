import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../widgets/layout/app_scaffold.dart';

/// Shown while `applicationStatus == pending_driver` or before approval.
class WaitingForDriverApprovalScreen extends StatelessWidget {
  const WaitingForDriverApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = fa.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return AppScaffold(
        child: Center(
          child: Text(
            'Please sign in.',
            style: GoogleFonts.montserrat(),
          ),
        ),
      );
    }

    return AppScaffold(
      title: 'Rehan Rose',
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.rosePrimary),
            );
          }
          final d = snap.data?.data() ?? {};
          final role = d['role']?.toString() ?? '';
          final status = d['applicationStatus']?.toString() ?? '';

          final approvedDriver = role == 'driver' &&
              (status == 'approved' || status.isEmpty);
          if (approvedDriver) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/driver');
            });
            return const Center(
              child: CircularProgressIndicator(color: AppColors.rosePrimary),
            );
          }

          if (status == 'rejected') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/driver/application');
            });
            return const Center(
              child: CircularProgressIndicator(color: AppColors.rosePrimary),
            );
          }

          if (status != 'pending_driver' && status.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/driver/application');
            });
            return const Center(
              child: CircularProgressIndicator(color: AppColors.rosePrimary),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.rosePrimary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.rosePrimary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Icon(
                        Icons.verified_user_outlined,
                        size: 40,
                        color: AppColors.rosePrimary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Waiting for admin approval',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.inkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Your driver application is being reviewed. You will not '
                      'have access to the live dashboard or online status until '
                      'a super admin approves your request.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        height: 1.6,
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),
                    OutlinedButton(
                      onPressed: () => context.go('/'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.rosePrimary,
                        side: BorderSide(
                          color: AppColors.rosePrimary.withValues(alpha: 0.7),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Back to home',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
