import 'package:cloud_firestore/cloud_firestore.dart';

/// Lifecycle for custom bouquet tender flow (Firestore `CustomRequests`).
enum CustomRequestStatus {
  pendingAdmin('pending_admin'),
  broadcasting('broadcasting'),
  /// Legacy: admin accepted bid before customer-approval step existed.
  bidAccepted('bid_accepted'),
  pendingCustomer('pending_customer'),
  customerAccepted('customer_accepted'),
  customerDeclined('customer_declined'),
  completed('completed');

  const CustomRequestStatus(this.value);
  final String value;

  static CustomRequestStatus? fromString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final s = raw.trim().toLowerCase();
    if (s == 'pending') return CustomRequestStatus.pendingAdmin;
    for (final e in CustomRequestStatus.values) {
      if (e.value == s) return e;
    }
    return null;
  }
}

/// Vendor bid stored in `custom_request_bids` (linked by [requestId]).
/// Mirrors the spec’s bid shape: vendorId, offeredPrice, vendorNote, timestamp.
class CustomRequestBidEntry {
  final String id;
  final String requestId;
  final String vendorId;
  final num offeredPrice;
  final String vendorNote;
  final DateTime? createdAt;

  const CustomRequestBidEntry({
    required this.id,
    required this.requestId,
    required this.vendorId,
    required this.offeredPrice,
    required this.vendorNote,
    this.createdAt,
  });

  static CustomRequestBidEntry? fromFirestore(
    String docId,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    final requestId = data['requestId']?.toString() ?? '';
    final vendorId = data['vendorId']?.toString() ?? '';
    if (requestId.isEmpty || vendorId.isEmpty) return null;
    final price = data['offeredPrice'];
    final num offered = price is num ? price : num.tryParse(price?.toString() ?? '') ?? 0;
    DateTime? createdAt;
    final ts = data['createdAt'];
    if (ts is Timestamp) createdAt = ts.toDate();
    return CustomRequestBidEntry(
      id: docId,
      requestId: requestId,
      vendorId: vendorId,
      offeredPrice: offered,
      vendorNote: data['vendorNote']?.toString() ?? '',
      createdAt: createdAt,
    );
  }
}

/// Custom bouquet request (`custom_requests` collection).
/// Canonical fields per product spec: [requestId], [customerId], [imagePath],
/// [description], [budget], [status], plus tender outcome fields.
class CustomRequestModel {
  final String requestId;
  final String customerId;
  final String customerPhone;
  final String imagePath;
  final String description;
  final String budget;
  final CustomRequestStatus? status;
  final DateTime? createdAt;
  final String? winningVendorId;
  final num? winningOfferedPrice;
  /// Set when admin accepts a vendor bid (same numeric value as [winningOfferedPrice]).
  final num? acceptedBidPrice;
  final String? acceptedBidId;
  final String? linkedOrderId;
  final List<Map<String, dynamic>> bids;

  const CustomRequestModel({
    required this.requestId,
    required this.customerId,
    required this.customerPhone,
    required this.imagePath,
    required this.description,
    required this.budget,
    this.status,
    this.createdAt,
    this.winningVendorId,
    this.winningOfferedPrice,
    this.acceptedBidPrice,
    this.acceptedBidId,
    this.linkedOrderId,
    this.bids = const [],
  });

  /// Price the customer must approve (prefers explicit [acceptedBidPrice]).
  num? get effectiveAcceptedPrice =>
      acceptedBidPrice ?? winningOfferedPrice;

  static CustomRequestModel? fromFirestore(
    String docId,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    final customerId =
        data['customerId']?.toString() ?? data['userId']?.toString() ?? '';
    if (customerId.isEmpty) return null;
    final description =
        data['description']?.toString() ?? data['notes']?.toString() ?? '';
    final budgetRaw = data['budget'];
    final budget = budgetRaw is num
        ? budgetRaw.toString()
        : (budgetRaw?.toString() ?? data['budgetText']?.toString() ?? '');
    final imagePath = data['imagePath']?.toString() ??
        data['referenceImageUrl']?.toString() ??
        '';
    final status = CustomRequestStatus.fromString(data['status']?.toString());
    DateTime? createdAt;
    final ts = data['createdAt'];
    if (ts is Timestamp) createdAt = ts.toDate();
    final bidsRaw = data['bids'];
    final bids = <Map<String, dynamic>>[];
    if (bidsRaw is List) {
      for (final e in bidsRaw) {
        if (e is Map<String, dynamic>) bids.add(e);
        if (e is Map) bids.add(Map<String, dynamic>.from(e));
      }
    }
    return CustomRequestModel(
      requestId: docId,
      customerId: customerId,
      customerPhone: data['customerPhone']?.toString() ?? '',
      imagePath: imagePath,
      description: description,
      budget: budget,
      status: status,
      createdAt: createdAt,
      winningVendorId: data['winningVendorId']?.toString(),
      winningOfferedPrice: data['winningOfferedPrice'] is num
          ? data['winningOfferedPrice'] as num
          : num.tryParse(data['winningOfferedPrice']?.toString() ?? ''),
      acceptedBidPrice: data['acceptedBidPrice'] is num
          ? data['acceptedBidPrice'] as num
          : num.tryParse(data['acceptedBidPrice']?.toString() ?? ''),
      acceptedBidId: data['acceptedBidId']?.toString(),
      linkedOrderId: data['linkedOrderId']?.toString(),
      bids: bids,
    );
  }
}
