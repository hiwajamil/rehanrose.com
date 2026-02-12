import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order_model.dart';

/// Repository for order lookup and creation.
/// Reads/writes Firestore collection [orders]; document ID = order ID (e.g. ORD-123).
///
/// Orders store a denormalized user snapshot (userName, userPhone, userAddress)
/// so the admin order list can be displayed without fetching user documents.
class OrderRepository {
  OrderRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _collection = 'orders';
  static const Duration _timeout = Duration(seconds: 15);

  /// Normalizes user input: trim and remove leading #.
  static String normalizeOrderId(String input) {
    return input.trim().replaceFirst(RegExp(r'^#\s*'), '');
  }

  /// Fetches an order by ID. Document ID in Firestore = order ID (e.g. ORD-123).
  /// Returns null if not found or document has no valid status.
  Future<OrderModel?> getByOrderId(String orderId) async {
    final id = normalizeOrderId(orderId);
    if (id.isEmpty) return null;
    final ref = _firestore.collection(_collection).doc(id);
    final snap = await ref.get().timeout(_timeout);
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return OrderModel.fromFirestore(snap.id, data);
  }

  /// Creates a new order with denormalized user snapshot.
  /// Stores userName, userPhone, userAddress in the order document so the
  /// admin order list requires no additional user document reads.
  ///
  /// [orderId] - unique order ID (e.g. ORD-123).
  /// [userData] - snapshot of user's essential info to embed in the order.
  /// [status] - initial status (default: received).
  /// [extraFields] - optional additional fields (e.g. items, total, bouquetId).
  Future<String> createOrder({
    required String orderId,
    required CreateOrderData userData,
    String status = 'received',
    Map<String, dynamic>? extraFields,
  }) async {
    final ref = _firestore.collection(_collection).doc(orderId);
    final data = <String, dynamic>{
      'userId': userData.userId,
      'userName': userData.userName,
      'userPhone': userData.userPhone,
      'userAddress': userData.userAddress,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      ...?userData.extraFields,
      ...?extraFields,
    };
    await ref.set(data).timeout(_timeout);
    return orderId;
  }

  /// Lists all orders for admin (newest first).
  /// Returns [AdminOrderModel] with denormalized user fields — no user
  /// document reads are needed. Reduces read costs by ~50% vs join pattern.
  Future<List<AdminOrderModel>> listOrdersForAdmin({
    int limit = 100,
  }) async {
    final snap = await _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get()
        .timeout(_timeout);

    final list = <AdminOrderModel>[];
    for (final doc in snap.docs) {
      final model = AdminOrderModel.fromFirestore(doc.id, doc.data());
      if (model != null) list.add(model);
    }
    return list;
  }

  /// Stream of orders for admin (e.g. real-time order list).
  Stream<List<AdminOrderModel>> watchOrdersForAdmin({
    int limit = 100,
  }) {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final list = <AdminOrderModel>[];
      for (final doc in snap.docs) {
        final model = AdminOrderModel.fromFirestore(doc.id, doc.data());
        if (model != null) list.add(model);
      }
      return list;
    });
  }
}
