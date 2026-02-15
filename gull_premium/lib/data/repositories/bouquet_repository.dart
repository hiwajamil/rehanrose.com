import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/constants/emotion_categories.dart';
import '../../core/constants/emotion_category.dart';
import '../models/flower_model.dart';

/// Repository for bouquet (flower) data. Abstracts Firestore and Storage.
class BouquetRepository {
  BouquetRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const String _collection = 'bouquets';
  static const String _countersCollection = 'counters';
  static const int _limit = 50;
  /// Page size for paginated product listing (infinite scroll).
  static const int pageSize = 10;
  static const int _analyticsLimit = 500;
  static const Duration _queryTimeout = Duration(seconds: 15);

  CollectionReference<Map<String, dynamic>> get _bouquets =>
      _firestore.collection(_collection);

  /// Fetches a single bouquet by id. Returns null if not found or parse fails.
  Future<FlowerModel?> getById(String id) async {
    final doc = await _bouquets.doc(id).get().timeout(_queryTimeout);
    final data = doc.data();
    if (data == null) return null;
    try {
      return FlowerModel.fromJson(doc.id, data);
    } catch (_) {
      return null;
    }
  }

  /// Fetches all bouquets for admin analytics (summary totals, top by viewCount/orderCount).
  /// Uses a higher limit than [getBouquets]. Does not filter by occasion.
  Future<List<FlowerModel>> getAllBouquetsForAnalytics() async {
    final snap = await _bouquets.limit(_analyticsLimit).get().timeout(_queryTimeout);
    return _parseBouquetDocs(snap.docs);
  }

  /// One-time fetch of bouquets for the public landing page. Prefer this over
  /// [watchBouquets] on web to avoid stream never emitting (e.g. custom domain).
  /// [occasion] null or 'All' = all bouquets; if valid emotion category ID, filter by emotionCategoryId.
  /// Only products with status == 'approved' are returned (customer-facing).
  Future<List<FlowerModel>> getBouquets({String? occasion}) async {
    Query<Map<String, dynamic>> query = _bouquets
        .where('approvalStatus', isEqualTo: 'approved')
        .limit(_limit * 2);

    if (occasion != null && occasion.isNotEmpty && occasion != 'All') {
      if (isValidEmotionCategoryId(occasion)) {
        query = _bouquets
            .where('approvalStatus', isEqualTo: 'approved')
            .where('emotionCategoryId', isEqualTo: occasion)
            .limit(_limit * 2);
      } else {
        final storedValues = storedValuesForFilter(occasion);
        if (storedValues.isNotEmpty) {
          query = _bouquets
              .where('approvalStatus', isEqualTo: 'approved')
              .where('occasion', whereIn: storedValues.length > 10 ? storedValues.take(10).toList() : storedValues)
              .limit(_limit * 2);
        }
      }
    }

    final snap = await query.get().timeout(_queryTimeout);
    final list = _parseBouquetDocs(snap.docs).take(_limit).toList();
    list.sort((a, b) {
      final aMs = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bMs = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bMs.compareTo(aMs);
    });
    return list;
  }

  /// Paginated fetch for infinite scroll. Returns [items] and [lastDoc] for the next page.
  /// Use [lastDoc] in [startAfter] for the next call. [occasion] same as [getBouquets].
  /// Only products with status == 'approved' are returned. Uses orderBy(createdAt, descending).
  Future<({List<FlowerModel> items, QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc})> getBouquetsPage({
    String? occasion,
    int limit = pageSize,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _bouquets
        .where('approvalStatus', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .limit(limit * 3);

    if (occasion != null && occasion.isNotEmpty && occasion != 'All') {
      if (isValidEmotionCategoryId(occasion)) {
        query = _bouquets
            .where('approvalStatus', isEqualTo: 'approved')
            .where('emotionCategoryId', isEqualTo: occasion)
            .orderBy('createdAt', descending: true)
            .limit(limit * 3);
      } else {
        final storedValues = storedValuesForFilter(occasion);
        if (storedValues.isNotEmpty) {
          query = _bouquets
              .where('approvalStatus', isEqualTo: 'approved')
              .where('occasion', whereIn: storedValues.length > 10 ? storedValues.take(10).toList() : storedValues)
              .orderBy('createdAt', descending: true)
              .limit(limit * 3);
        }
      }
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get().timeout(_queryTimeout);
    final list = _parseBouquetDocs(snap.docs).take(limit).toList();
    final lastDoc = snap.docs.isEmpty ? null : snap.docs.last;
    return (items: list, lastDoc: lastDoc);
  }

  /// Stream of bouquets, optionally filtered by emotion value.
  /// Only products with status == 'approved'. Sorts in Dart by createdAt descending.
  Stream<List<FlowerModel>> watchBouquets({String? occasion}) {
    Query<Map<String, dynamic>> query = _bouquets
        .where('approvalStatus', isEqualTo: 'approved')
        .limit(_limit * 2);

    if (occasion != null && occasion.isNotEmpty && occasion != 'All') {
      if (isValidEmotionCategoryId(occasion)) {
        query = _bouquets
            .where('approvalStatus', isEqualTo: 'approved')
            .where('emotionCategoryId', isEqualTo: occasion)
            .limit(_limit * 2);
      } else {
        final storedValues = storedValuesForFilter(occasion);
        if (storedValues.isNotEmpty) {
          query = _bouquets
              .where('approvalStatus', isEqualTo: 'approved')
              .where('occasion', whereIn: storedValues.length > 10 ? storedValues.take(10).toList() : storedValues)
              .limit(_limit * 2);
        }
      }
    }

    return query.snapshots().timeout(_queryTimeout).map((snap) {
      final list = _parseBouquetDocs(snap.docs).take(_limit).toList();
      list.sort((a, b) {
        final aMs = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bMs = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bMs.compareTo(aMs);
      });
      return list;
    });
  }

  /// Stream of bouquets pending super admin approval. For admin dashboard.
  Stream<List<FlowerModel>> watchPendingBouquets() {
    return _bouquets
        .where('approvalStatus', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .timeout(_queryTimeout)
        .map((snap) {
      final list = _parseBouquetDocs(snap.docs);
      list.sort((a, b) {
        final aMs = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bMs = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bMs.compareTo(aMs);
      });
      return list;
    });
  }

  /// Set bouquet approval status to 'approved' or 'rejected'. Admin only (enforced by rules).
  /// Uses .update() only; does NOT touch category, occasion, emotionCategoryId, or bouquetCode.
  /// Once approved, the bouquet appears in the user app under the occasion the vendor selected.
  Future<void> updateApprovalStatus(String bouquetId, String status) async {
    if (status != 'approved' && status != 'rejected') {
      throw ArgumentError('status must be approved or rejected');
    }
    await _bouquets.doc(bouquetId).update({'approvalStatus': status});
  }

  /// Stream of bouquets for a given vendor. No customer-side filters.
  /// Defensive parsing: skips docs that fail to parse so one bad doc doesn't break the stream.
  Stream<List<FlowerModel>> watchBouquetsByVendor(String vendorId) {
    return _bouquets
        .where('vendorId', isEqualTo: vendorId)
        .snapshots()
        .timeout(_queryTimeout)
        .map((snap) {
      final list = _parseBouquetDocs(snap.docs);
      list.sort((a, b) {
        final aMs = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bMs = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bMs.compareTo(aMs);
      });
      return list;
    });
  }

  /// Parses docs into [FlowerModel] list, skipping any doc that fails so the stream doesn't break.
  List<FlowerModel> _parseBouquetDocs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final result = <FlowerModel>[];
    for (final doc in docs) {
      try {
        result.add(FlowerModel.fromJson(doc.id, doc.data()));
      } catch (_) {
        // Skip malformed docs; do not fail the whole stream
      }
    }
    return result;
  }

  /// Creates a new bouquet and returns its id. Throws on failure.
  /// [imageUrls] must be download URLs (e.g. from Storage).
  /// [thumbnailUrls] optional; same order as [imageUrls] for listing grid.
  /// [bouquetCode] is the generated code (e.g. from controller using emotion prefix).
  /// [emotionCategoryId] must be a valid ID from [kEmotionCategoryIds].
  /// [initialStatus] when provided (e.g. 'approved' for admin-created) is used;
  /// otherwise defaults to 'pending' for vendor-created bouquets.
  Future<String> create({
    required String vendorId,
    required String name,
    required String description,
    required int priceIqd,
    required List<String> imageUrls,
    List<String>? thumbnailUrls,
    required String occasion,
    required String bouquetCode,
    required String emotionCategoryId,
    String? initialStatus,
  }) async {
    if (!isValidEmotionCategoryId(emotionCategoryId)) {
      throw ArgumentError('Invalid emotionCategoryId. Must be one of: $kEmotionCategoryIds');
    }
    final status = initialStatus ?? 'pending';
    if (status != 'pending' && status != 'approved' && status != 'rejected') {
      throw ArgumentError('initialStatus must be pending, approved, or rejected');
    }
    final data = <String, dynamic>{
      'vendorId': vendorId,
      'name': name,
      'description': description,
      'priceIqd': priceIqd,
      'imageUrls': imageUrls,
      'bouquetCode': bouquetCode,
      'occasion': occasion,
      'emotionCategoryId': emotionCategoryId,
      'approvalStatus': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (thumbnailUrls != null && thumbnailUrls.isNotEmpty) {
      data['thumbnailUrls'] = thumbnailUrls;
    }
    final bouquetRef = _bouquets.doc();
    await bouquetRef.set(data);
    return bouquetRef.id;
  }

  /// Reserves the next bouquet code for [prefix] and returns it (e.g. "TH-1").
  /// Call this before [create] and pass the result as [bouquetCode].
  Future<String> reserveNextBouquetCode(String prefix) async {
    if (prefix.isEmpty) {
      throw ArgumentError('Invalid occasion. Cannot generate bouquet code.');
    }
    final counterRef =
        _firestore.collection(_countersCollection).doc('bouquet_$prefix');
    String? generatedCode;
    await _firestore.runTransaction((transaction) async {
      final counterSnap = await transaction.get(counterRef);
      final lastNumber =
          (counterSnap.data()?['lastNumber'] as num?)?.toInt() ?? 0;
      final nextNumber = lastNumber + 1;
      generatedCode = '$prefix-$nextNumber';
      transaction.set(counterRef, {'lastNumber': nextNumber});
    }).timeout(const Duration(seconds: 15));
    return generatedCode!;
  }

  /// Updates bouquet price.
  Future<void> updatePrice(String bouquetId, int priceIqd) async {
    await _bouquets.doc(bouquetId).update({'priceIqd': priceIqd});
  }

  /// Updates bouquet image URLs and optional thumbnail URLs.
  Future<void> updateImageUrls(
    String bouquetId,
    List<String> imageUrls, {
    List<String>? thumbnailUrls,
  }) async {
    final data = <String, dynamic>{'imageUrls': imageUrls};
    if (thumbnailUrls != null) data['thumbnailUrls'] = thumbnailUrls;
    await _bouquets.doc(bouquetId).update(data);
  }

  /// Deletes a bouquet.
  Future<void> delete(String bouquetId) async {
    await _bouquets.doc(bouquetId).delete();
  }

  /// Increments viewCount by 1 in Firestore. Fire-and-forget (silent, no loading).
  /// Call when a user opens the product detail page.
  void incrementViewCount(String bouquetId) {
    _bouquets
        .doc(bouquetId)
        .update({'viewCount': FieldValue.increment(1)})
        .catchError((_) {});
  }

  /// Increments orderCount by 1 in Firestore. Fire-and-forget (silent, no loading).
  /// Call when a user clicks "Order via WhatsApp".
  void incrementOrderCount(String bouquetId) {
    _bouquets
        .doc(bouquetId)
        .update({'orderCount': FieldValue.increment(1)})
        .catchError((_) {});
  }

  /// Result of uploading one image (full-size and optional thumbnail).
  static const String webpContentType = 'image/webp';

  /// Uploads image bytes (WebP or JPEG) and optional thumbnail; returns full URL and optional thumb URL.
  /// Uses .webp path when [contentType] is [webpContentType].
  Future<({String fullUrl, String? thumbUrl})> uploadImage({
    required String vendorId,
    required int timestamp,
    required int index,
    required Uint8List bytes,
    String contentType = webpContentType,
    Uint8List? thumbBytes,
  }) async {
    final ext = contentType == webpContentType ? 'webp' : 'jpg';
    final fullRef = _storage.ref('bouquets/$vendorId/$timestamp-$index.$ext');
    await fullRef
        .putData(bytes, SettableMetadata(contentType: contentType))
        .timeout(const Duration(seconds: 45));
    final fullUrl = await fullRef.getDownloadURL();

    String? thumbUrl;
    if (thumbBytes != null && thumbBytes.isNotEmpty) {
      final thumbRef =
          _storage.ref('bouquets/$vendorId/$timestamp-${index}_thumb.$ext');
      await thumbRef
          .putData(thumbBytes, SettableMetadata(contentType: contentType))
          .timeout(const Duration(seconds: 30));
      thumbUrl = await thumbRef.getDownloadURL();
    }

    return (fullUrl: fullUrl, thumbUrl: thumbUrl);
  }
}
