import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/emotion_categories.dart';
import '../data/models/flower_model.dart';
import '../data/repositories/bouquet_repository.dart';

/// Provides [BouquetRepository].
final bouquetRepositoryProvider = Provider<BouquetRepository>((ref) {
  return BouquetRepository();
});

/// Selected occasion for filtering bouquets on landing. 'All' or a specific occasion.
class SelectedOccasionNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  void setOccasion(String occasion) {
    state = occasion;
  }

  /// Set from emotion label (e.g. "Celebrate Them" → "birthday").
  void setFromEmotion(String emotionLabel) {
    state = emotionValueForLabel(emotionLabel) ?? 'All';
  }

  /// Set from dropdown emotion label (same labels as filter cards).
  void setFromDropdownEmotion(String displayLabel) {
    state = emotionValueForLabel(displayLabel) ?? 'All';
  }

  /// Set from search query; resolves emotion/feeling to occasion.
  void setFromSearch(String query) {
    final occasion = resolveQueryToOccasion(query);
    state = occasion ?? 'All';
  }
}

final selectedOccasionProvider =
    NotifierProvider<SelectedOccasionNotifier, String>(SelectedOccasionNotifier.new);

/// Legacy stream (Firestore .snapshots()). Not used for product/landing lists; use FutureProviders to save reads.
final bouquetsStreamProvider = StreamProvider<List<FlowerModel>>((ref) {
  final repo = ref.watch(bouquetRepositoryProvider);
  final occasion = ref.watch(selectedOccasionProvider);
  return repo.watchBouquets(occasion: occasion);
});

/// One-time read (Firestore .get()) for the landing page. Refetches when [selectedOccasionProvider] changes.
/// State is kept when navigating away (e.g. Home → Profile → Home) to avoid extra Firestore reads.
final landingBouquetsProvider = FutureProvider<List<FlowerModel>>((ref) {
  ref.keepAlive();
  final occasion = ref.watch(selectedOccasionProvider);
  return ref.read(bouquetRepositoryProvider).getBouquets(occasion: occasion);
});

/// One-time read (Firestore .get()) for ProductListingPage. Use pull-to-refresh to refresh. [category] null or 'All' = all.
final productsByCategoryProvider =
    FutureProvider.family<List<FlowerModel>, String?>((ref, category) {
  ref.keepAlive();
  final occasion = category == null || category.isEmpty || category == 'All'
      ? null
      : category;
  return ref.read(bouquetRepositoryProvider).getBouquets(occasion: occasion);
});

/// State for paginated product list (infinite scroll).
class PaginatedProductsState {
  const PaginatedProductsState({
    this.products = const [],
    this.lastDoc,
    this.hasMore = true,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.occasion,
  });

  final List<FlowerModel> products;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final String? occasion;
}

/// Paginated products notifier: fetches 10 initially, then [fetchMoreProducts] on scroll.
class PaginatedProductsNotifier extends Notifier<PaginatedProductsState> {
  @override
  PaginatedProductsState build() => const PaginatedProductsState();

  /// Load first page for [occasion]. Call when page opens or filter changes.
  Future<void> loadInitial(String? occasion) async {
    final repo = ref.read(bouquetRepositoryProvider);
    state = PaginatedProductsState(
      occasion: occasion,
      isLoading: true,
      error: null,
    );
    try {
      final result = await repo.getBouquetsPage(
        occasion: occasion,
        limit: BouquetRepository.pageSize,
      );
      state = PaginatedProductsState(
        occasion: occasion,
        products: result.items,
        lastDoc: result.lastDoc,
        hasMore: result.items.length >= BouquetRepository.pageSize,
        isLoading: false,
      );
    } catch (e) {
      state = PaginatedProductsState(
        occasion: occasion,
        isLoading: false,
        error: e,
      );
    }
  }

  /// Fetch next page. No-op if already loading more, no more data, or occasion mismatch.
  Future<void> fetchMoreProducts() async {
    if (state.isLoadingMore || !state.hasMore || state.lastDoc == null) return;
    final repo = ref.read(bouquetRepositoryProvider);
    state = PaginatedProductsState(
      occasion: state.occasion,
      products: state.products,
      lastDoc: state.lastDoc,
      hasMore: state.hasMore,
      isLoadingMore: true,
    );
    try {
      final result = await repo.getBouquetsPage(
        occasion: state.occasion,
        limit: BouquetRepository.pageSize,
        startAfter: state.lastDoc,
      );
      final newProducts = [...state.products, ...result.items];
      state = PaginatedProductsState(
        occasion: state.occasion,
        products: newProducts,
        lastDoc: result.lastDoc,
        hasMore: result.items.length >= BouquetRepository.pageSize,
        isLoadingMore: false,
      );
    } catch (e) {
      state = PaginatedProductsState(
        occasion: state.occasion,
        products: state.products,
        lastDoc: state.lastDoc,
        hasMore: state.hasMore,
        isLoadingMore: false,
        error: e,
      );
    }
  }
}

final paginatedProductsProvider =
    NotifierProvider<PaginatedProductsNotifier, PaginatedProductsState>(
  PaginatedProductsNotifier.new,
);

/// Single bouquet by id (e.g. for product detail page).
final bouquetDetailProvider =
    FutureProvider.family<FlowerModel?, String>((ref, id) async {
  return ref.read(bouquetRepositoryProvider).getById(id);
});

/// Stream of bouquets for a specific vendor (public vendor profile page).
/// Only approved products are shown to customers.
final vendorProfileBouquetsProvider =
    StreamProvider.autoDispose.family<List<FlowerModel>, String>((ref, vendorId) {
  return ref
      .watch(bouquetRepositoryProvider)
      .watchBouquetsByVendor(vendorId)
      .map((list) => list.where((b) => b.isApproved).toList());
});

/// One-time fetch of all bouquets for admin analytics (totals, top by viewCount/orderCount).
/// Invalidate to refresh: ref.invalidate(adminAnalyticsBouquetsProvider).
final adminAnalyticsBouquetsProvider = FutureProvider<List<FlowerModel>>((ref) {
  return ref.read(bouquetRepositoryProvider).getAllBouquetsForAnalytics();
});

/// Stream of bouquets pending super admin approval. Used on admin dashboard.
final pendingBouquetsStreamProvider = StreamProvider<List<FlowerModel>>((ref) {
  return ref.watch(bouquetRepositoryProvider).watchPendingBouquets();
});
