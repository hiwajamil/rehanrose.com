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

/// Stream of bouquets for the landing page (legacy). Prefer [landingBouquetsProvider] on web.
final bouquetsStreamProvider = StreamProvider<List<FlowerModel>>((ref) {
  final repo = ref.watch(bouquetRepositoryProvider);
  final occasion = ref.watch(selectedOccasionProvider);
  return repo.watchBouquets(occasion: occasion);
});

/// One-time fetch of bouquets for the landing page. Avoids stream never emitting on web (e.g. rehanrose.com).
/// Refetches when [selectedOccasionProvider] changes.
final landingBouquetsProvider = FutureProvider<List<FlowerModel>>((ref) {
  final occasion = ref.watch(selectedOccasionProvider);
  return ref.read(bouquetRepositoryProvider).getBouquets(occasion: occasion);
});

/// Single bouquet by id (e.g. for product detail page).
final bouquetDetailProvider =
    FutureProvider.family<FlowerModel?, String>((ref, id) async {
  return ref.read(bouquetRepositoryProvider).getById(id);
});
