import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/customer_member_model.dart';
import '../data/models/order_model.dart';
import '../data/repositories/members_repository.dart';
import 'order_controller.dart';

final membersRepositoryProvider = Provider<MembersRepository>((ref) {
  return MembersRepository();
});

/// Live count of customers (users with role == 'customer').
final customerCountStreamProvider =
    StreamProvider.autoDispose<int>((ref) {
  return ref.read(membersRepositoryProvider).watchCustomerCount();
});

/// Stream of all customers for MembersListScreen, ordered by createdAt (newest first).
final customersStreamProvider =
    StreamProvider.autoDispose<List<CustomerMemberModel>>((ref) {
  return ref.read(membersRepositoryProvider).watchCustomers();
});

/// One-time fetch of order count for a customer (for member card "Total Orders").
final orderCountForUserProvider =
    FutureProvider.autoDispose.family<int, String>((ref, userId) async {
  return ref.read(orderRepositoryProvider).countOrdersByUserId(userId);
});

/// One-time fetch of orders for a customer (for Order History modal).
final ordersForUserProvider =
    FutureProvider.autoDispose.family<List<CustomerOrderItem>, String>((ref, userId) async {
  return ref.read(orderRepositoryProvider).listOrdersByUserId(userId);
});
