import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/in_app_notification_repository.dart';

final inAppNotificationRepositoryProvider = Provider<InAppNotificationRepository>((ref) {
  return InAppNotificationRepository();
});

/// Real-time unread count for the given Firebase Auth uid (customer, vendor, or admin).
final inAppUnreadNotificationsCountProvider =
    StreamProvider.autoDispose.family<int, String>((ref, userId) {
  if (userId.isEmpty) return Stream.value(0);
  return ref.watch(inAppNotificationRepositoryProvider).watchUnreadCount(userId);
});
