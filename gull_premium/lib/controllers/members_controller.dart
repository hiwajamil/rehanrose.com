import 'package:cloud_firestore/cloud_firestore.dart';
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

/// Paginated customers state for MembersListScreen (cursor-based, 20 per page).
class PaginatedCustomersState {
  final List<CustomerMemberModel> list;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final DocumentSnapshot? lastDocument;

  const PaginatedCustomersState({
    this.list = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.lastDocument,
  });

  PaginatedCustomersState copyWith({
    List<CustomerMemberModel>? list,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    Object? lastDocument = _unchanged,
  }) {
    return PaginatedCustomersState(
      list: list ?? this.list,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      lastDocument: identical(lastDocument, _unchanged) ? this.lastDocument : lastDocument as DocumentSnapshot?,
    );
  }
}

const _unchanged = Object();

class PaginatedCustomersNotifier extends Notifier<PaginatedCustomersState> {
  @override
  PaginatedCustomersState build() => const PaginatedCustomersState();

  Future<void> loadInitial() async {
    state = const PaginatedCustomersState(isLoading: true);
    try {
      final result = await ref.read(membersRepositoryProvider).getCustomersPage();
      state = state.copyWith(
        list: result.items,
        hasMore: result.hasMore,
        isLoading: false,
        lastDocument: result.lastDocument,
        error: null,
      );
    } catch (e, _) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.lastDocument == null) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await ref.read(membersRepositoryProvider).getCustomersPage(
            startAfter: state.lastDocument,
          );
      state = state.copyWith(
        list: [...state.list, ...result.items],
        hasMore: result.hasMore,
        isLoadingMore: false,
        lastDocument: result.lastDocument,
        error: null,
      );
    } catch (e, _) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Removes one member from the in-memory list after a successful delete.
  void removeMemberByUid(String uid) {
    state = state.copyWith(
      list: state.list.where((m) => m.uid != uid).toList(),
    );
  }
}

final paginatedCustomersProvider =
    NotifierProvider.autoDispose<PaginatedCustomersNotifier, PaginatedCustomersState>(
  PaginatedCustomersNotifier.new,
);

/// One-time fetch of order count for a customer (for member card "Total Orders").
/// Not autoDispose so that when the list rebuilds (e.g. stream emission), cards
/// get the cached count immediately and don't flicker loading → data.
final orderCountForUserProvider =
    FutureProvider.family<int, String>((ref, userId) async {
  return ref.read(orderRepositoryProvider).countOrdersByUserId(userId);
});

/// One-time fetch of orders for a customer (for Order History modal).
final ordersForUserProvider =
    FutureProvider.autoDispose.family<List<CustomerOrderItem>, String>((ref, userId) async {
  return ref.read(orderRepositoryProvider).listOrdersByUserId(userId);
});
