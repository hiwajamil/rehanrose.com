import 'package:cloud_firestore/cloud_firestore.dart';

/// Order status for customer-facing tracking.
/// Values should match Firestore: received, preparing, on_the_way, delivered.
enum OrderTrackingStatus {
  received,
  preparing,
  onTheWay,
  delivered,
}

extension OrderTrackingStatusExtension on OrderTrackingStatus {
  /// Zero-based step index for timeline (0 = Received, 3 = Delivered).
  int get stepIndex {
    switch (this) {
      case OrderTrackingStatus.received:
        return 0;
      case OrderTrackingStatus.preparing:
        return 1;
      case OrderTrackingStatus.onTheWay:
        return 2;
      case OrderTrackingStatus.delivered:
        return 3;
    }
  }
}

/// Parses a status string from Firestore into [OrderTrackingStatus].
OrderTrackingStatus? orderStatusFromString(String? value) {
  if (value == null || value.isEmpty) return null;
  final normalized = value.trim().toLowerCase().replaceAll(' ', '_');
  switch (normalized) {
    case 'received':
    case 'new':
      return OrderTrackingStatus.received;
    case 'preparing':
      return OrderTrackingStatus.preparing;
    case 'on_the_way':
    case 'ontheway':
      return OrderTrackingStatus.onTheWay;
    case 'delivered':
      return OrderTrackingStatus.delivered;
    case 'ready':
      return OrderTrackingStatus.onTheWay;
    default:
      return null;
  }
}

/// Lightweight order model for track-order modal (id + status).
class OrderModel {
  final String id;
  final OrderTrackingStatus status;

  const OrderModel({required this.id, required this.status});

  /// Build from Firestore document. [docId] is the document ID (e.g. ORD-123).
  /// Expects a `status` field (string). Returns null if missing or invalid.
  static OrderModel? fromFirestore(
    String docId,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    final statusValue = data['status'];
    final status = statusValue is String
        ? orderStatusFromString(statusValue)
        : orderStatusFromString(statusValue?.toString());
    if (status == null) return null;
    return OrderModel(id: docId, status: status);
  }
}

/// User snapshot embedded in an order (denormalized for fewer reads).
/// Stored directly in the order document so admin can list orders without fetching users.
class OrderUserSnapshot {
  final String userId;
  final String userName;
  final String userPhone;
  final String userAddress;

  const OrderUserSnapshot({
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.userAddress,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'userPhone': userPhone,
        'userAddress': userAddress,
      };

  static OrderUserSnapshot? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final uid = map['userId']?.toString();
    if (uid == null || uid.isEmpty) return null;
    return OrderUserSnapshot(
      userId: uid,
      userName: map['userName']?.toString() ?? '',
      userPhone: map['userPhone']?.toString() ?? '',
      userAddress: map['userAddress']?.toString() ?? '',
    );
  }
}

/// Full order model for admin list view. Includes denormalized user snapshot.
/// Use this when listing orders so no separate user document reads are needed.
class AdminOrderModel {
  final String orderId;
  final String userId;
  final String userName;
  final String userPhone;
  final String userAddress;
  final OrderTrackingStatus status;
  final DateTime? createdAt;

  const AdminOrderModel({
    required this.orderId,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.userAddress,
    required this.status,
    this.createdAt,
  });

  /// Build from Firestore document. Includes denormalized user fields.
  static AdminOrderModel? fromFirestore(
    String docId,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    final status = orderStatusFromString(
      data['status']?.toString(),
    );
    if (status == null) return null;
    final userId = data['userId']?.toString() ?? '';
    DateTime? createdAt;
    final ts = data['createdAt'];
    if (ts is Timestamp) {
      createdAt = ts.toDate();
    } else if (ts is DateTime) {
      createdAt = ts;
    } else if (ts != null) {
      createdAt = DateTime.tryParse(ts.toString());
    }
    return AdminOrderModel(
      orderId: docId,
      userId: userId,
      userName: data['userName']?.toString() ?? '',
      userPhone: data['userPhone']?.toString() ?? '',
      userAddress: data['userAddress']?.toString() ?? '',
      status: status,
      createdAt: createdAt,
    );
  }
}

/// Data required to create a new order. User snapshot is denormalized at creation.
class CreateOrderData {
  final String userId;
  final String userName;
  final String userPhone;
  final String userAddress;
  final Map<String, dynamic>? extraFields;

  const CreateOrderData({
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.userAddress,
    this.extraFields,
  });
}

// --- OMS (Order Management System) for WhatsApp checkout flow ---

/// OMS order status: pending → preparing → ready → delivered.
enum OmsOrderStatus {
  pending,
  preparing,
  ready,
  delivered,
}

extension OmsOrderStatusExtension on OmsOrderStatus {
  String get value {
    switch (this) {
      case OmsOrderStatus.pending:
        return 'pending';
      case OmsOrderStatus.preparing:
        return 'preparing';
      case OmsOrderStatus.ready:
        return 'ready';
      case OmsOrderStatus.delivered:
        return 'delivered';
    }
  }
}

OmsOrderStatus? omsOrderStatusFromString(String? value) {
  if (value == null || value.isEmpty) return null;
  final normalized = value.trim().toLowerCase();
  switch (normalized) {
    case 'pending':
      return OmsOrderStatus.pending;
    case 'preparing':
      return OmsOrderStatus.preparing;
    case 'ready':
      return OmsOrderStatus.ready;
    case 'delivered':
      return OmsOrderStatus.delivered;
    default:
      return null;
  }
}

/// Full OMS order model for admin and vendor dashboards.
/// Stored in Firestore collection [oms_orders].
class OmsOrderModel {
  final String orderId;
  final String bouquetId;
  final String bouquetCode;
  final String vendorId;
  final String customerPhone;
  /// Add-ons or notes (stored as string; can be comma-separated or free text).
  final String addons;
  final num totalPrice;
  final OmsOrderStatus status;
  final DateTime? createdAt;
  /// Denormalized for list views (optional).
  final String? bouquetName;
  final String? vendorName;
  /// First image URL of the bouquet for cards (optional).
  final String? bouquetImageUrl;

  const OmsOrderModel({
    required this.orderId,
    required this.bouquetId,
    required this.bouquetCode,
    required this.vendorId,
    required this.customerPhone,
    required this.addons,
    required this.totalPrice,
    required this.status,
    this.createdAt,
    this.bouquetName,
    this.vendorName,
    this.bouquetImageUrl,
  });

  /// For local use only. Repository sets createdAt with serverTimestamp on create.
  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'bouquetId': bouquetId,
        'bouquetCode': bouquetCode,
        'vendorId': vendorId,
        'customerPhone': customerPhone,
        'addons': addons,
        'totalPrice': totalPrice,
        'status': status.value,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        if (bouquetName != null) 'bouquetName': bouquetName!,
        if (vendorName != null) 'vendorName': vendorName!,
        if (bouquetImageUrl != null) 'bouquetImageUrl': bouquetImageUrl!,
      };

  static OmsOrderModel? fromFirestore(
    String docId,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    final status = omsOrderStatusFromString(data['status']?.toString());
    if (status == null) return null;
    DateTime? createdAt;
    final ts = data['createdAt'];
    if (ts is Timestamp) {
      createdAt = ts.toDate();
    } else if (ts is DateTime) {
      createdAt = ts;
    } else if (ts != null) {
      createdAt = DateTime.tryParse(ts.toString());
    }
    final totalPrice = data['totalPrice'];
    num price = 0;
    if (totalPrice is num) price = totalPrice;
    if (totalPrice is int) price = totalPrice;
    return OmsOrderModel(
      orderId: docId,
      bouquetId: data['bouquetId']?.toString() ?? '',
      bouquetCode: data['bouquetCode']?.toString() ?? '',
      vendorId: data['vendorId']?.toString() ?? '',
      customerPhone: data['customerPhone']?.toString() ?? '',
      addons: data['addons']?.toString() ?? '',
      totalPrice: price,
      status: status,
      createdAt: createdAt,
      bouquetName: data['bouquetName']?.toString(),
      vendorName: data['vendorName']?.toString(),
      bouquetImageUrl: data['bouquetImageUrl']?.toString(),
    );
  }
}

/// Data required to create an OMS order (admin creates after WhatsApp request).
class CreateOmsOrderData {
  final String bouquetId;
  final String bouquetCode;
  final String vendorId;
  final String customerPhone;
  final String addons;
  final num totalPrice;
  final String bouquetName;
  final String vendorName;
  final String bouquetImageUrl;

  const CreateOmsOrderData({
    required this.bouquetId,
    required this.bouquetCode,
    required this.vendorId,
    required this.customerPhone,
    required this.addons,
    required this.totalPrice,
    required this.bouquetName,
    required this.vendorName,
    this.bouquetImageUrl = '',
  });
}
