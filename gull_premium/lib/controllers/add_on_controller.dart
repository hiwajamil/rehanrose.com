import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/add_on_model.dart';
import '../data/repositories/add_on_repository.dart';

final addOnRepositoryProvider = Provider<AddOnRepository>((ref) {
  return AddOnRepository();
});

/// Add-ons available at checkout (global; optional vendorId for future vendor-specific).
final addOnsProvider =
    FutureProvider.family<List<AddOnModel>, String?>((ref, vendorId) async {
  return ref.read(addOnRepositoryProvider).getAddOns(vendorId: vendorId);
});

/// Stream of add-ons by type for admin Manage Add-ons page.
final adminAddOnsByTypeProvider = StreamProvider.family<List<AddOnModel>, AddOnType>(
  (ref, type) => ref.read(addOnRepositoryProvider).streamAddOnsByType(type),
);
