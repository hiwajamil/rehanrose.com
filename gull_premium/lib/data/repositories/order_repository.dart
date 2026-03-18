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

/// Result of a paginated OMS orders fetch (cursor-based).
class PaginatedOmsOrdersResult {
  final List<OmsOrderModel> items;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  const PaginatedOmsOrdersResult({
    required this.items,
    this.lastDocument,
    this.hasMore = false,
  });
}

/// Repository for OMS orders (admin-created, vendor-assigned).
class OmsOrderRepository {
  OmsOrderRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const Duration _timeout = Duration(seconds: 15);
  static const double _defaultCommissionRate = 0.15;

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
      if (data.bouquetDetails.isNotEmpty) 'bouquetDetails': data.bouquetDetails,
      if (data.voiceMessageLink.isNotEmpty) 'voiceMessageLink': data.voiceMessageLink,
      if (data.deliveryLocationLink.isNotEmpty) 'deliveryLocationLink': data.deliveryLocationLink,
      if (data.orderDate.isNotEmpty) 'orderDate': data.orderDate,
    }).timeout(_timeout);
    return orderId;
  }

  /// Fetches a page of OMS orders for admin (newest first). Use [startAfter] for the next page.
  static const int _adminOrdersPageSize = 20;

  Future<PaginatedOmsOrdersResult> getOmsOrdersPage({
    DocumentSnapshot? startAfter,
    int limit = _adminOrdersPageSize,
  }) async {
    var query = _firestore
        .collection(_omsCollection)
        .orderBy('createdAt', descending: true)
        .limit(limit + 1);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get().timeout(_timeout);
    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;
    final lastDoc = pageDocs.isNotEmpty ? pageDocs.last : null;

    final list = <OmsOrderModel>[];
    for (final doc in pageDocs) {
      final model = OmsOrderModel.fromFirestore(doc.id, doc.data());
      if (model != null) list.add(model);
    }

    return PaginatedOmsOrdersResult(
      items: list,
      lastDocument: lastDoc,
      hasMore: hasMore,
    );
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

  /// Fetches delivered order count and total revenue for a vendor. Used by admin.
  Future<({int count, num totalRevenue})> getVendorDeliveredStats(
    String vendorId,
  ) async {
    final snap = await _firestore
        .collection(_omsCollection)
        .where('vendorId', isEqualTo: vendorId)
        .limit(500)
        .get()
        .timeout(_timeout);
    int count = 0;
    num total = 0;
    for (final doc in snap.docs) {
      final model = OmsOrderModel.fromFirestore(doc.id, doc.data());
      if (model != null && model.status == OmsOrderStatus.delivered) {
        count++;
        total += model.totalPrice;
      }
    }
    return (count: count, totalRevenue: total);
  }

  /// Updates OMS order status (e.g. pending → preparing, preparing → ready).
  Future<void> updateOmsOrderStatus({
    required String orderId,
    required OmsOrderStatus status,
  }) async {
    final orderRef = _firestore.collection(_omsCollection).doc(orderId);

    await _firestore.runTransaction((tx) async {
      final orderSnap = await tx.get(orderRef);
      final orderData = orderSnap.data();
      if (!orderSnap.exists || orderData == null) {
        throw StateError('OMS order not found: $orderId');
      }

      final previousStatus = (orderData['status'] ?? '').toString();
      if (previousStatus == status.value) return;

      final bool wasFinancialsApplied = orderData['financialsApplied'] == true;

      final bool newStatusIsCompletion =
          status == OmsOrderStatus.ready || status == OmsOrderStatus.delivered;
      final bool previousStatusWasCompletion =
          previousStatus == OmsOrderStatus.ready.value ||
              previousStatus == OmsOrderStatus.delivered.value;

      // Always update status, but only apply financials once on first transition into "ready/delivered".
      final shouldApplyFinancials =
          newStatusIsCompletion && !previousStatusWasCompletion && !wasFinancialsApplied;

      if (!shouldApplyFinancials) {
        tx.update(orderRef, {'status': status.value});
        return;
      }

      final vendorId = (orderData['vendorId'] ?? '').toString();
      final totalPriceRaw = orderData['totalPrice'];
      final num totalPrice = totalPriceRaw is num ? totalPriceRaw : 0;
      if (vendorId.isEmpty || totalPrice <= 0) {
        tx.update(orderRef, {'status': status.value});
        return;
      }

      final vendorRef = _firestore.collection('users').doc(vendorId);
      final vendorSnap = await tx.get(vendorRef);
      final vendorData = vendorSnap.data();

      final commissionRateRaw = vendorData?['commissionRate'];
      final double commissionRate = (commissionRateRaw is num &&
              commissionRateRaw.toDouble() >= 0 &&
              commissionRateRaw.toDouble() <= 1)
          ? commissionRateRaw.toDouble()
          : _defaultCommissionRate;

      final num rehanRoseCut = totalPrice * commissionRate;
      final num vendorEarning = totalPrice - rehanRoseCut;

      tx.set(
        vendorRef,
        {
          'totalGrossSales': FieldValue.increment(totalPrice),
          'rehanRoseCommission': FieldValue.increment(rehanRoseCut),
          'vendorEarnings': FieldValue.increment(vendorEarning),
          'completedOrders': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.update(orderRef, {
        'status': status.value,
        'financialsApplied': true,
        'financialsAppliedAt': FieldValue.serverTimestamp(),
        'commissionRateApplied': commissionRate,
        'rehanRoseCut': rehanRoseCut,
        'vendorEarning': vendorEarning,
      });
    }).timeout(_timeout);
  }

  /// Deletes an OMS order document (admin-only use; intended for pending orders).
  Future<void> deleteOmsOrder({
    required String orderId,
  }) async {
    final ref = _firestore.collection(_omsCollection).doc(orderId);
    await ref.delete().timeout(_timeout);
  }
}
