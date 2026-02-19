import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/utils/image_compression_service.dart';
import '../models/add_on_model.dart';

/// Default add-ons shown when Firestore has none (vase = crucial, chocolate/card = emotional).
List<AddOnModel> get defaultAddOns => [
      const AddOnModel(
        id: 'default_vase',
        nameEn: 'Vase',
        nameKu: 'گوڵدان',
        nameAr: 'مزهرية',
        priceIqd: 5000,
        imageUrl:
            'https://images.unsplash.com/photo-1578500494198-246f612d3b3d?auto=format&fit=crop&w=400&q=80',
        type: AddOnType.vase,
        isGlobal: true,
      ),
      const AddOnModel(
        id: 'default_chocolate',
        nameEn: 'Chocolates',
        nameKu: 'چۆکلێت',
        nameAr: 'شوكولاتة',
        priceIqd: 7500,
        imageUrl:
            'https://images.unsplash.com/photo-1511381939415-e44015466834?auto=format&fit=crop&w=400&q=80',
        type: AddOnType.chocolate,
        isGlobal: true,
      ),
      const AddOnModel(
        id: 'default_card',
        nameEn: 'Premium Card',
        nameKu: 'کارتی تایبەت',
        nameAr: 'بطاقة مميزة',
        priceIqd: 2500,
        imageUrl:
            'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?auto=format&fit=crop&w=400&q=80',
        type: AddOnType.card,
        isGlobal: true,
      ),
    ];

/// Repository for add-on (complementary product) data.
class AddOnRepository {
  AddOnRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  static const String _collection = 'addOns';
  static const String _storagePath = 'addons';
  static const Duration _queryTimeout = Duration(seconds: 10);

  CollectionReference<Map<String, dynamic>> get _addOns =>
      _firestore.collection(_collection);

  /// Fetches add-ons offered at checkout. [vendorId] optional for vendor-specific add-ons.
  /// Returns global add-ons (isGlobal == true) plus any for [vendorId].
  /// If Firestore returns none, returns [defaultAddOns] so the UI always has vase/chocolate/card.
  Future<List<AddOnModel>> getAddOns({String? vendorId}) async {
    try {
      final globalSnap = await _addOns
          .where('isGlobal', isEqualTo: true)
          .get()
          .timeout(_queryTimeout);

      final list = <AddOnModel>[];
      for (final doc in globalSnap.docs) {
        try {
          final model = AddOnModel.fromJson(doc.id, doc.data());
          if (model.isActive) list.add(model);
        } catch (_) {}
      }

      if (vendorId != null && vendorId.isNotEmpty) {
        final vendorSnap = await _addOns
            .where('vendorId', isEqualTo: vendorId)
            .get()
            .timeout(_queryTimeout);
        for (final doc in vendorSnap.docs) {
          try {
            final model = AddOnModel.fromJson(doc.id, doc.data());
            if (model.isActive) list.add(model);
          } catch (_) {}
        }
      }

      // Ensure vase is first (crucial item), then emotional (chocolate, card).
      list.sort((a, b) {
        int order(AddOnType t) {
          switch (t) {
            case AddOnType.vase:
              return 0;
            case AddOnType.chocolate:
              return 1;
            case AddOnType.card:
              return 2;
            case AddOnType.teddyBear:
              return 3;
          }
        }
        return order(a.type).compareTo(order(b.type));
      });

      return list.isEmpty ? defaultAddOns : list;
    } catch (_) {
      return defaultAddOns;
    }
  }

  /// Stream of add-ons for admin by type (vase, chocolate, card). Includes inactive.
  Stream<List<AddOnModel>> streamAddOnsByType(AddOnType type) {
    final typeStr = type.firestoreValue;
    return _addOns
        .where('type', isEqualTo: typeStr)
        .snapshots()
        .map((snap) {
          final list = <AddOnModel>[];
          for (final doc in snap.docs) {
            try {
              list.add(AddOnModel.fromJson(doc.id, doc.data()));
            } catch (_) {}
          }
          list.sort((a, b) => a.nameEn.compareTo(b.nameEn));
          return list;
        });
  }

  /// Creates a new add-on. Id can be auto-generated via [FirebaseFirestore.collection].add().
  Future<String> create(AddOnModel addOn) async {
    final ref = await _addOns.add(addOn.toJson());
    return ref.id;
  }

  /// Updates an existing add-on by id.
  Future<void> update(AddOnModel addOn) async {
    await _addOns.doc(addOn.id).set(addOn.toJson(), SetOptions(merge: true));
  }

  /// Deletes an add-on by id.
  Future<void> delete(String id) async {
    await _addOns.doc(id).delete();
  }

  /// Uploads image for an add-on; compresses to WebP (quality 85%, max 500 KB) then returns download URL.
  /// Use before or after creating the doc.
  Future<String> uploadImage({
    required String addOnId,
    required Uint8List bytes,
  }) async {
    final compressed = await ImageCompressionService.compressToWebPForAddOn(bytes);
    final ref = _storage.ref('$_storagePath/$addOnId.webp');
    await ref
        .putData(
          compressed,
          SettableMetadata(contentType: 'image/webp'),
        )
        .timeout(const Duration(seconds: 45));
    return ref.getDownloadURL();
  }
}
