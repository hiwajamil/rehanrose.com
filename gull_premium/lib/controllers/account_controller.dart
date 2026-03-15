import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/user_occasion_model.dart';
import '../data/repositories/user_occasions_repository.dart';

final userOccasionsRepositoryProvider = Provider<UserOccasionsRepository>((ref) {
  return UserOccasionsRepository();
});

/// Stream of occasions for the given user (users/{uid}/occasions).
final userOccasionsStreamProvider =
    StreamProvider.autoDispose.family<List<UserOccasionModel>, String>((ref, uid) {
  return ref.read(userOccasionsRepositoryProvider).watchOccasions(uid);
});
