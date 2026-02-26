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

  /// Lists orders for a specific customer (userId). Newest first.
  /// Returns [CustomerOrderItem] with optional bouquet fields for CRM order history.
  Future<List<CustomerOrderItem>> listOrdersByUserId(
    String userId, {
    int limit = 50,
  }) async {
    final snap = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get()
        .timeout(_timeout);
    final list = <CustomerOrderItem>[];
    for (final doc in snap.docs) {
      final model = CustomerOrderItem.fromFirestore(doc.id, doc.data());
      if (model != null) list.add(model);
    }
    return list;
  }

  /// Stream of order count for a customer (for "Total Orders" on member card).
  /// Uses a snapshot and returns docs.length; for exact count use listOrdersByUserId once.
  Future<int> countOrdersByUserId(String userId) async {
    final snap = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .get()
        .timeout(_timeout);
    return snap.docs.length;
  }
}

// --- OMS (Order Management System) for WhatsApp checkout ---

const String _omsCollection = 'oms_orders';

/// Repository for OMS orders (admin-created, vendor-assigned).
class OmsOrderRepository {
  OmsOrderRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const Duration _timeout = Duration(seconds: 15);

  /// Generates a unique OMS order ID (e.g. ORD-1730000000123).
  String generateOrderId() {
    return 'ORD-${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Creates an OMS order with status [pending]. Assigns to [vendorId].
  Future<String> createOmsOrder({
    required String orderId,
    required CreateOmsOrderData data,
  }) async {
    final ref = _firestore.collection(_omsCollection).doc(orderId);
    await ref.set({
      'orderId': orderId,
      'bouquetId': data.bouquetId,
      'bouquetCode': data.bouquetCode,
      'vendorId': data.vendorId,
      'customerPhone': data.customerPhone,
      'addons': data.addons,
      'totalPrice': data.totalPrice,
      'status': OmsOrderStatus.pending.value,
      'createdAt': FieldValue.serverTimestamp(),
      'bouquetName': data.bouquetName,
      'vendorName': data.vendorName,
      'bouquetImageUrl': data.bouquetImageUrl,
    }).timeout(_timeout);
    return orderId;
  }

  /// Stream of all OMS orders for admin (newest first).
  Stream<List<OmsOrderModel>> watchOmsOrdersForAdmin({int limit = 200}) {
    return _firestore
        .collection(_omsCollection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final list = <OmsOrderModel>[];
      for (final doc in snap.docs) {
        final model = OmsOrderModel.fromFirestore(doc.id, doc.data());
        if (model != null) list.add(model);
      }
      return list;
    });
  }

  /// Stream of OMS orders for a vendor, optionally filtered by [status].
  /// When [status] is set, filtering is done in Dart to avoid composite index.
  /// Skips malformed docs so one bad document doesn't break the stream.
  Stream<List<OmsOrderModel>> watchOmsOrdersForVendor({
    required String vendorId,
    OmsOrderStatus? status,
    int limit = 100,
  }) {
    final query = _firestore
        .collection(_omsCollection)
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    return query.snapshots().map((snap) {
      final list = <OmsOrderModel>[];
      for (final doc in snap.docs) {
        try {
          final model = OmsOrderModel.fromFirestore(doc.id, doc.data());
          if (model != null && (status == null || model.status == status)) {
            list.add(model);
          }
        } catch (_) {
          // Skip malformed doc; do not break the stream
        }
      }
      return list;
    });
  }

  /// Updates OMS order status (e.g. pending → preparing, preparing → ready).
  Future<void> updateOmsOrderStatus({
    required String orderId,
    required OmsOrderStatus status,
  }) async {
    final ref = _firestore.collection(_omsCollection).doc(orderId);
    await ref.update({'status': status.value}).timeout(_timeout);
  }
}
