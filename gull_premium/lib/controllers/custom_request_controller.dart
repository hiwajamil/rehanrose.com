import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/custom_request_model.dart';
import '../data/repositories/custom_request_repository.dart';
import 'in_app_notification_controller.dart';

final customRequestRepositoryProvider = Provider<CustomRequestRepository>((ref) {
  return CustomRequestRepository(
    inAppNotifications: ref.read(inAppNotificationRepositoryProvider),
  );
});

final adminCustomRequestsStreamProvider =
    StreamProvider.autoDispose<List<CustomRequestModel>>((ref) {
  return ref.watch(customRequestRepositoryProvider).watchAllRequests();
});

final vendorBroadcastingRequestsStreamProvider =
    StreamProvider.autoDispose<List<CustomRequestModel>>((ref) {
  return ref.watch(customRequestRepositoryProvider).watchBroadcastingRequests();
});

final adminCustomBidsStreamProvider =
    StreamProvider.autoDispose<List<CustomRequestBidEntry>>((ref) {
  return ref.watch(customRequestRepositoryProvider).watchRecentBids();
});

final adminCustomerAcceptedCustomRequestsStreamProvider =
    StreamProvider.autoDispose<List<CustomRequestModel>>((ref) {
  return ref.watch(customRequestRepositoryProvider).watchCustomerAcceptedRequests();
});

final customerPendingCustomOffersStreamProvider =
    StreamProvider.autoDispose.family<List<CustomRequestModel>, String>((ref, customerId) {
  if (customerId.isEmpty) return Stream.value(<CustomRequestModel>[]);
  return ref.watch(customRequestRepositoryProvider).watchPendingCustomerRequests(
        customerId: customerId,
      );
});
