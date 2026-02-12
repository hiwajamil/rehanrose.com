import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/vendor_list_model.dart';
import '../data/repositories/auth_repository.dart';

/// Provides [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Stream of current user (null if signed out).
final authStateProvider = StreamProvider<fa.User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Stream of pending vendor applications (for admin dashboard).
final pendingVendorApplicationsStreamProvider = StreamProvider.autoDispose<
    QuerySnapshot<Map<String, dynamic>>>((ref) {
  return ref.watch(authRepositoryProvider).watchVendorApplications();
});

/// One-time fetch of all approved vendors (designers/florists) for the public list page.
final vendorsListProvider = FutureProvider.autoDispose<List<VendorListModel>>((ref) {
  return ref.read(authRepositoryProvider).getVendors();
});

/// Single vendor by id (e.g. for vendor profile page header).
final vendorByIdProvider =
    FutureProvider.autoDispose.family<VendorListModel?, String>((ref, vendorId) {
  return ref.read(authRepositoryProvider).getVendorById(vendorId);
});
