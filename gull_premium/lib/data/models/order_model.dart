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
