import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/services/auth_service.dart';
import '../data/models/vendor_list_model.dart';
import '../data/repositories/auth_repository.dart';
import '../env/google_client_id.dart';
import '../firebase_options.dart';

/// Provides [AuthRepository] with Google Sign-In configured for Firebase Auth.
/// Web requires [clientId] (see [kGoogleWebClientId]) to avoid "Assertion failed" in google_sign_in_web.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final webClientId = DefaultFirebaseOptions.googleWebClientId;
  final effectiveWebClientId = webClientId.isNotEmpty ? webClientId : kGoogleWebClientId;
  final GoogleSignIn? googleSignIn = (webClientId.isEmpty && !kIsWeb)
      ? null
      : GoogleSignIn(
          serverClientId: webClientId.isNotEmpty ? webClientId : null,
          clientId: kIsWeb ? effectiveWebClientId : null,
        );
  return AuthRepository(googleSignIn: googleSignIn);
});

/// Provides [AuthService] for customer sign-in (Google, email/password).
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(authRepositoryProvider));
});

/// Stream of current user (null if signed out).
final authStateProvider = StreamProvider<fa.User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Cached admin check for a user (by uid). Used by admin dashboard to avoid
/// refetching and showing spinner on every rebuild.
final isAdminForUidProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, uid) async {
  return ref.read(authRepositoryProvider).isAdmin(uid);
});

/// Stream of pending vendor applications (for admin dashboard).
/// Not autoDispose so the stream is not restarted on rebuilds, avoiding
/// the approval cards flickering (appear/disappear) on the admin dashboard.
final pendingVendorApplicationsStreamProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
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

/// Vendor status for the given uid. Used on vendor dashboard to avoid showing
/// dashboard briefly before sign-out when the user just submitted an application.
final vendorStatusForUidProvider =
    FutureProvider.autoDispose.family<String, String>((ref, uid) {
  return ref.read(authRepositoryProvider).getVendorStatus(uid);
});

/// Customer profile from Firestore users collection (fullName, email, phone, city, photoURL).
/// Used on the account/dashboard page for authenticated customers.
final userProfileProvider =
    FutureProvider.autoDispose.family<Map<String, String>?, String>((ref, uid) {
  return ref.read(authRepositoryProvider).getUserProfile(uid);
});
