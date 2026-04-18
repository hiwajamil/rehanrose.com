import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/in_app_notification_repository.dart';

/// Lists top-level [InAppNotificationRepository.collectionId] for [userId], newest first.
class InAppNotificationsList extends StatelessWidget {
  const InAppNotificationsList({
    super.key,
    required this.userId,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 28),
    this.scrollPhysics,
  });

  final String userId;
  final EdgeInsets padding;
  final ScrollPhysics? scrollPhysics;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection(InAppNotificationRepository.collectionId)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(100)
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
                'Could not load notifications.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 64,
                    color: AppColors.inkMuted.withValues(alpha: 0.75),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No notifications yet',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkCharcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Updates about your orders and offers will appear here.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: padding,
          physics: scrollPhysics,
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final isRead = data['isRead'] == true;
            final title = (data['title'] ?? 'Notification').toString();
            final body = (data['body'] ?? '').toString();
            final type = (data['type'] ?? '').toString();
            final createdAt = data['createdAt'];
            final createdAtDate = createdAt is Timestamp ? createdAt.toDate() : null;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () async {
                  if (!isRead) {
                    await FirebaseFirestore.instance
                        .collection(InAppNotificationRepository.collectionId)
                        .doc(doc.id)
                        .update({'isRead': true});
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isRead
                        ? AppColors.surface
                        : AppColors.badgeGoldBackground.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isRead ? AppColors.border : AppColors.accentGold.withValues(alpha: 0.45),
                    ),
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
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.rose.withValues(alpha: 0.12),
                        ),
                        child: const Icon(
                          Icons.notifications_active_outlined,
                          color: AppColors.rosePrimary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.inkCharcoal,
                                    ),
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsetsDirectional.only(start: 10),
                                    decoration: const BoxDecoration(
                                      color: AppColors.rosePrimary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              body,
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                color: AppColors.inkMuted,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: [
                                if (type.isNotEmpty)
                                  _MetaChip(label: type.replaceAll('_', ' ')),
                                _MetaChip(
                                  label: createdAtDate != null
                                      ? MaterialLocalizations.of(context).formatShortDate(createdAtDate)
                                      : '—',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.inkMuted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.inkMuted,
        ),
      ),
    );
  }
}
