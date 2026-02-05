import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}

final selectedOccasionProvider =
    NotifierProvider<SelectedOccasionNotifier, String>(SelectedOccasionNotifier.new);

/// Stream of bouquets for the landing page, filtered by [selectedOccasionProvider].
final bouquetsStreamProvider = StreamProvider<List<FlowerModel>>((ref) {
  final repo = ref.watch(bouquetRepositoryProvider);
  final occasion = ref.watch(selectedOccasionProvider);
  return repo.watchBouquets(occasion: occasion);
});

/// Single bouquet by id (e.g. for product detail page).
final bouquetDetailProvider =
    FutureProvider.family<FlowerModel?, String>((ref, id) async {
  return ref.read(bouquetRepositoryProvider).getById(id);
});
