import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/emotion_category.dart';
import '../core/utils/auth_error_utils.dart';
import '../core/utils/image_compression_service.dart';
import '../data/models/flower_model.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/bouquet_repository.dart';
import 'auth_controller.dart';
import 'bouquets_controller.dart';

/// Vendor status for UI.
enum VendorStatus { pending, approved, rejected }

/// Stream of bouquets for the current vendor (when signed in).
final vendorBouquetsStreamProvider = StreamProvider<List<FlowerModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return ref
      .watch(bouquetRepositoryProvider)
      .watchBouquetsByVendor(user.uid);
});

/// Controller for vendor actions: application, sign-in, bouquet CRUD.
class VendorController extends AsyncNotifier<void> {
  AuthRepository get _authRepo => ref.read(authRepositoryProvider);
  BouquetRepository get _bouquetRepo => ref.read(bouquetRepositoryProvider);

  @override
  Future<void> build() async {}

  static Object? _unwrapError(Object? error) {
    try {
      final dynamic d = error;
      if (d != null && d.error != null) return d.error as Object?;
    } catch (_) {}
    return error;
  }

  /// Submit vendor application (creates user, sets docs, signs out).
  Future<void> submitApplication({
    required String studioName,
    required String ownerName,
    required String email,
    required String phone,
    required String location,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final credential = await _authRepo.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;
      await _authRepo.setUserDoc(uid, {
        'role': 'vendor',
        'vendorStatus': 'pending',
        'email': email.trim(),
      });
      await _authRepo.setVendorApplication(uid, {
        'studioName': studioName.trim(),
        'ownerName': ownerName.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'location': location.trim(),
        'status': 'pending',
      });
      await _authRepo.signOut();
      state = const AsyncValue.data(null);
    } on fa.FirebaseAuthException catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    } on FirebaseException catch (e, st) {
      state = AsyncValue.error(e, st);
      throw Exception(
        e.message ?? 'Could not save application. Please check your connection and try again.',
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Sign in vendor; throws if not approved. Throws [Exception] with user-friendly message on auth failure.
  Future<VendorStatus> signInVendor({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      await _authRepo.signInWithEmailAndPassword(email: email, password: password);
      final user = _authRepo.currentUser;
      if (user == null) {
        state = const AsyncValue.data(null);
        return VendorStatus.rejected;
      }
      final statusStr = await _authRepo.getVendorStatus(user.uid);
      if (statusStr != 'approved') {
        await _authRepo.signOut();
        state = const AsyncValue.data(null);
        if (statusStr == 'rejected') return VendorStatus.rejected;
        return VendorStatus.pending;
      }
      state = const AsyncValue.data(null);
      return VendorStatus.approved;
    } on fa.FirebaseAuthException catch (e) {
      final msg = e.message ?? authErrorMessage(e);
      state = AsyncValue.error(Exception(msg), StackTrace.current);
      throw Exception(msg);
    } catch (e, st) {
      final msg = authErrorMessage(e, fallback: 'Could not sign in. Please try again.');
      state = AsyncValue.error(Exception(msg), st);
      throw Exception(msg);
    }
  }

  /// Upload images and create bouquet. Returns generated code on success.
  /// [occasion] is saved to Firestore exactly as provided (e.g. "I'm Sorry") for User App queries.
  /// [emotionCategoryId] must be one of [kEmotionCategoryIds] (love, apology, gratitude, etc.).
  /// [productCodePrefix] when provided is used for the bouquet code (e.g. IS, BD); otherwise prefix is derived from [emotionCategoryId].
  Future<String?> publishBouquet({
    required fa.User user,
    required String name,
    required String description,
    required int priceIqd,
    required List<XFile> imageFiles,
    required String occasion,
    required String emotionCategoryId,
    String? productCodePrefix,
  }) async {
    if (!isValidEmotionCategoryId(emotionCategoryId)) {
      throw ArgumentError('Invalid emotionCategoryId. Must be one of: $kEmotionCategoryIds');
    }
    state = const AsyncValue.loading();
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imageUrls = <String>[];
      final thumbnailUrls = <String>[];
      for (var i = 0; i < imageFiles.length; i++) {
        final bytes = await imageFiles[i]
            .readAsBytes()
            .timeout(const Duration(seconds: 15));
        final fullBytes = await ImageCompressionService.compressToWebP(bytes);
        final thumbBytes =
            await ImageCompressionService.compressThumbnail(bytes);
        final result = await _bouquetRepo.uploadImage(
          vendorId: user.uid,
          timestamp: timestamp,
          index: i,
          bytes: fullBytes,
          thumbBytes: thumbBytes,
        );
        imageUrls.add(result.fullUrl);
        if (result.thumbUrl != null) thumbnailUrls.add(result.thumbUrl!);
      }
      final prefix = (productCodePrefix != null && productCodePrefix.isNotEmpty)
          ? productCodePrefix
          : codePrefixForEmotionCategoryId(emotionCategoryId);
      if (prefix.isEmpty) throw ArgumentError('Invalid emotion. Cannot generate bouquet code.');
      final bouquetCode = await _bouquetRepo.reserveNextBouquetCode(prefix);
      await _bouquetRepo.create(
        vendorId: user.uid,
        name: name,
        description: description,
        priceIqd: priceIqd,
        imageUrls: imageUrls,
        thumbnailUrls:
            thumbnailUrls.isEmpty ? null : thumbnailUrls,
        occasion: occasion,
        bouquetCode: bouquetCode,
        emotionCategoryId: emotionCategoryId,
      );
      state = const AsyncValue.data(null);
      return bouquetCode;
    } on TimeoutException catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    } on fa.FirebaseException catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    } catch (e, st) {
      state = AsyncValue.error(_unwrapError(e) ?? e, st);
      rethrow;
    }
  }

  Future<void> updateBouquetPrice(String bouquetId, int priceIqd) async {
    state = const AsyncValue.loading();
    try {
      await _bouquetRepo.updatePrice(bouquetId, priceIqd);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> replaceBouquetPhotos({
    required fa.User user,
    required String bouquetId,
    required List<XFile> imageFiles,
  }) async {
    state = const AsyncValue.loading();
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imageUrls = <String>[];
      final thumbnailUrls = <String>[];
      for (var i = 0; i < imageFiles.length; i++) {
        final bytes = await imageFiles[i]
            .readAsBytes()
            .timeout(const Duration(seconds: 15));
        final fullBytes = await ImageCompressionService.compressToWebP(bytes);
        final thumbBytes =
            await ImageCompressionService.compressThumbnail(bytes);
        final result = await _bouquetRepo.uploadImage(
          vendorId: user.uid,
          timestamp: timestamp,
          index: i,
          bytes: fullBytes,
          thumbBytes: thumbBytes,
        );
        imageUrls.add(result.fullUrl);
        if (result.thumbUrl != null) thumbnailUrls.add(result.thumbUrl!);
      }
      await _bouquetRepo.updateImageUrls(
        bouquetId,
        imageUrls,
        thumbnailUrls:
            thumbnailUrls.isEmpty ? null : thumbnailUrls,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteBouquet(String bouquetId) async {
    state = const AsyncValue.loading();
    try {
      await _bouquetRepo.delete(bouquetId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final vendorControllerProvider =
    AsyncNotifierProvider<VendorController, void>(VendorController.new);
