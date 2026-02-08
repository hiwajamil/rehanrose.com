import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/constants/emotion_categories.dart';
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

  /// One-time fetch of bouquets for the public landing page. Prefer this over
  /// [watchBouquets] on web to avoid stream never emitting (e.g. custom domain).
  /// [occasion] null or 'All' = all bouquets; otherwise filter by emotion value (with backward compat).
  Future<List<FlowerModel>> getBouquets({String? occasion}) async {
    Query<Map<String, dynamic>> query = _bouquets.limit(_limit);

    if (occasion != null && occasion.isNotEmpty && occasion != 'All') {
      final storedValues = storedValuesForFilter(occasion);
      if (storedValues.isNotEmpty) {
        query = _bouquets
            .where('occasion', whereIn: storedValues.length > 10 ? storedValues.take(10).toList() : storedValues)
            .limit(_limit);
      }
    }

    final snap = await query.get().timeout(_queryTimeout);
    final list = _parseBouquetDocs(snap.docs);
    list.sort((a, b) {
      final aMs = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bMs = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bMs.compareTo(aMs);
    });
    return list;
  }

  /// Stream of bouquets, optionally filtered by emotion value.
  /// [occasion] null or 'All' = all bouquets; otherwise filter by emotion (with backward compat).
  /// Does NOT use orderBy(createdAt) so documents without createdAt (e.g. older data) are included.
  /// Sorts in Dart by createdAt descending (null createdAt treated as oldest).
  Stream<List<FlowerModel>> watchBouquets({String? occasion}) {
    Query<Map<String, dynamic>> query = _bouquets.limit(_limit);

    if (occasion != null && occasion.isNotEmpty && occasion != 'All') {
      final storedValues = storedValuesForFilter(occasion);
      if (storedValues.isNotEmpty) {
        query = _bouquets
            .where('occasion', whereIn: storedValues.length > 10 ? storedValues.take(10).toList() : storedValues)
            .limit(_limit);
      }
    }

    return query.snapshots().timeout(_queryTimeout).map((snap) {
      final list = _parseBouquetDocs(snap.docs);
      list.sort((a, b) {
        final aMs = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bMs = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bMs.compareTo(aMs);
      });
      return list;
    });
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
  /// [bouquetCode] is the generated code (e.g. from controller using occasion prefix).
  Future<String> create({
    required String vendorId,
    required String name,
    required String description,
    required int priceIqd,
    required List<String> imageUrls,
    required String occasion,
    required String bouquetCode,
  }) async {
    final bouquetRef = _bouquets.doc();
    await bouquetRef.set({
      'vendorId': vendorId,
      'name': name,
      'description': description,
      'priceIqd': priceIqd,
      'imageUrls': imageUrls,
      'bouquetCode': bouquetCode,
      'occasion': occasion,
      'createdAt': FieldValue.serverTimestamp(),
    });
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

  /// Updates bouquet image URLs.
  Future<void> updateImageUrls(String bouquetId, List<String> imageUrls) async {
    await _bouquets.doc(bouquetId).update({'imageUrls': imageUrls});
  }

  /// Deletes a bouquet.
  Future<void> delete(String bouquetId) async {
    await _bouquets.doc(bouquetId).delete();
  }

  /// Uploads image bytes and returns the download URL.
  Future<String> uploadImage({
    required String vendorId,
    required int timestamp,
    required int index,
    required Uint8List bytes,
  }) async {
    final ref = _storage.ref('bouquets/$vendorId/$timestamp-$index.jpg');
    await ref
        .putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        )
        .timeout(const Duration(seconds: 45));
    return ref.getDownloadURL();
  }
}
