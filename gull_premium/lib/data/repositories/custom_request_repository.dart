import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/custom_request_model.dart';
import '../models/order_model.dart';
import 'in_app_notification_repository.dart';
import 'order_repository.dart';

/// Firestore-backed tender flow for custom bouquets.
///
/// Bids are stored in [customRequestBidsCollection] (one doc per offer) for
/// safe vendor writes; the product spec’s “array of bids” is represented here
/// as that collection, grouped by [requestId].
class CustomRequestRepository {
  CustomRequestRepository({
    FirebaseFirestore? firestore,
    InAppNotificationRepository? inAppNotifications,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _inApp = inAppNotifications ?? InAppNotificationRepository(firestore: firestore);

  final FirebaseFirestore _db;
  final InAppNotificationRepository _inApp;

  /// Customer + tender pipeline (PascalCase collection per product spec).
  static const String requestsCollection = 'CustomRequests';
  static const String bidsCollection = 'custom_request_bids';

  static const Duration _timeout = Duration(seconds: 20);

  /// Customer app: new custom request document (exact field set for security rules).
  Future<void> createCustomerCustomRequest({
    required String customerId,
    required String imagePath,
    required String description,
    required int budgetIqd,
  }) async {
    await _db.collection(requestsCollection).add({
      'customerId': customerId,
      'imagePath': imagePath,
      'description': description.trim(),
      'budget': budgetIqd,
      'status': 'pending_admin',
      'createdAt': FieldValue.serverTimestamp(),
      'bids': <Map<String, dynamic>>[],
    }).timeout(_timeout);
  }

  /// All custom requests (admin), newest first.
  Stream<List<CustomRequestModel>> watchAllRequests({int limit = 100}) {
    return _db
        .collection(requestsCollection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final out = <CustomRequestModel>[];
      for (final d in snap.docs) {
        final m = CustomRequestModel.fromFirestore(d.id, d.data());
        if (m != null) out.add(m);
      }
      return out;
    });
  }

  /// Open tenders visible to vendors.
  Stream<List<CustomRequestModel>> watchBroadcastingRequests({int limit = 50}) {
    return _db
        .collection(requestsCollection)
        .where('status', isEqualTo: CustomRequestStatus.broadcasting.value)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final out = <CustomRequestModel>[];
      for (final d in snap.docs) {
        final m = CustomRequestModel.fromFirestore(d.id, d.data());
        if (m != null) out.add(m);
      }
      return out;
    });
  }

  /// Recent bids (admin dashboard — single listener, group by [requestId] in UI).
  Stream<List<CustomRequestBidEntry>> watchRecentBids({int limit = 300}) {
    return _db
        .collection(bidsCollection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final out = <CustomRequestBidEntry>[];
      for (final d in snap.docs) {
        final m = CustomRequestBidEntry.fromFirestore(d.id, d.data());
        if (m != null) out.add(m);
      }
      return out;
    });
  }

  /// Real-time bids for one request (admin).
  Stream<List<CustomRequestBidEntry>> watchBidsForRequest(String requestId) {
    return _db
        .collection(bidsCollection)
        .where('requestId', isEqualTo: requestId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) {
      final out = <CustomRequestBidEntry>[];
      for (final d in snap.docs) {
        final m = CustomRequestBidEntry.fromFirestore(d.id, d.data());
        if (m != null) out.add(m);
      }
      out.sort((a, b) {
        final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return ta.compareTo(tb);
      });
      return out;
    });
  }

  Future<void> broadcastToVendors(String requestId) async {
    await _db.collection(requestsCollection).doc(requestId).update({
      'status': CustomRequestStatus.broadcasting.value,
    }).timeout(_timeout);
    try {
      await _inApp.notifyActiveVendorsNewCustomTender();
    } catch (e, st) {
      debugPrint('broadcastToVendors in-app notifications failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> markCompleted(String requestId) async {
    await _db.collection(requestsCollection).doc(requestId).update({
      'status': CustomRequestStatus.completed.value,
    }).timeout(_timeout);
  }

  /// Customer: [accept]=true → `customer_accepted`, false → `customer_declined`.
  Future<void> setCustomerOfferResponse({
    required String requestId,
    required bool accept,
  }) async {
    await _db.collection(requestsCollection).doc(requestId).update({
      'status': accept
          ? CustomRequestStatus.customerAccepted.value
          : CustomRequestStatus.customerDeclined.value,
    }).timeout(_timeout);
  }

  /// Customer Activity: open offers awaiting approval.
  Stream<List<CustomRequestModel>> watchPendingCustomerRequests({
    required String customerId,
    int limit = 20,
  }) {
    return _db
        .collection(requestsCollection)
        .where('customerId', isEqualTo: customerId)
        .where('status', isEqualTo: CustomRequestStatus.pendingCustomer.value)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final out = <CustomRequestModel>[];
      for (final d in snap.docs) {
        final m = CustomRequestModel.fromFirestore(d.id, d.data());
        if (m != null) out.add(m);
      }
      return out;
    });
  }

  /// Bouquet OMS: requests where the customer accepted and await dispatch to vendor.
  Stream<List<CustomRequestModel>> watchCustomerAcceptedRequests({int limit = 50}) {
    return _db
        .collection(requestsCollection)
        .where('status', isEqualTo: CustomRequestStatus.customerAccepted.value)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final out = <CustomRequestModel>[];
      for (final d in snap.docs) {
        final m = CustomRequestModel.fromFirestore(d.id, d.data());
        if (m != null) out.add(m);
      }
      return out;
    });
  }

  /// Vendor submits a price offer for a broadcasting request.
  Future<void> submitBid({
    required String requestId,
    required String vendorId,
    required num offeredPrice,
    required String vendorNote,
  }) async {
    await _db.collection(bidsCollection).add({
      'requestId': requestId,
      'vendorId': vendorId,
      'offeredPrice': offeredPrice,
      'vendorNote': vendorNote.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(_timeout);
    try {
      await _inApp.notifyAdminsNewBidOnCustomRequest(vendorId: vendorId);
    } catch (e, st) {
      debugPrint('submitBid in-app notifications failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  /// Super-admin accepts one bid: locks tender, stores winner and price, awaits customer.
  Future<void> acceptBidPendingCustomer({
    required String requestId,
    required String bidDocId,
  }) async {
    await _db.runTransaction<void>((transaction) async {
      final reqRef = _db.collection(requestsCollection).doc(requestId);
      final bidRef = _db.collection(bidsCollection).doc(bidDocId);

      final reqSnap = await transaction.get(reqRef);
      final bidSnap = await transaction.get(bidRef);
      if (!reqSnap.exists || !bidSnap.exists) {
        throw StateError('Request or bid not found.');
      }
      final reqData = reqSnap.data()!;
      final bidData = bidSnap.data()!;
      final status = CustomRequestStatus.fromString(reqData['status']?.toString());
      if (status != CustomRequestStatus.broadcasting) {
        throw StateError('This request is not accepting bids anymore.');
      }
      if (bidData['requestId']?.toString() != requestId) {
        throw StateError('Bid does not belong to this request.');
      }

      final customerId =
          reqData['customerId']?.toString() ?? reqData['userId']?.toString() ?? '';
      if (customerId.isEmpty) {
        throw StateError('Missing customer on request.');
      }

      final vendorId = bidData['vendorId']?.toString() ?? '';
      if (vendorId.isEmpty) throw StateError('Invalid bid vendor.');

      final priceRaw = bidData['offeredPrice'];
      final num offered = priceRaw is num
          ? priceRaw
          : num.tryParse(priceRaw?.toString() ?? '0') ??
              0;
      if (offered <= 0) throw StateError('Invalid offered price.');

      final bidMap = {
        'vendorId': vendorId,
        'offeredPrice': offered,
        'vendorNote': bidData['vendorNote']?.toString() ?? '',
        'timestamp': Timestamp.now(),
      };

      transaction.update(reqRef, {
        'status': CustomRequestStatus.pendingCustomer.value,
        'winningVendorId': vendorId,
        'acceptedBidPrice': offered,
        'winningOfferedPrice': offered,
        'acceptedBidId': bidDocId,
        'bids': FieldValue.arrayUnion([bidMap]),
        'linkedOrderId': FieldValue.delete(),
      });
    }).timeout(_timeout);

    try {
      final reqSnap = await _db.collection(requestsCollection).doc(requestId).get();
      final customerId = reqSnap.data()?['customerId']?.toString() ??
          reqSnap.data()?['userId']?.toString() ??
          '';
      if (customerId.isNotEmpty) {
        await _inApp.createNotification(
          userId: customerId,
          title: 'Offer Ready!',
          body: 'We have a price for your custom bouquet. Please review.',
        );
      }
    } catch (e, st) {
      debugPrint('acceptBidPendingCustomer in-app notification failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  /// After customer acceptance: create vendor OMS order and complete the tender.
  ///
  /// Uses [oms_orders] so the winning vendor sees the job under **New Requests**.
  Future<String> dispatchCustomerAcceptedToOms({
    required String requestId,
    required String orderId,
  }) async {
    return _db.runTransaction<String>((transaction) async {
      final reqRef = _db.collection(requestsCollection).doc(requestId);
      final reqSnap = await transaction.get(reqRef);
      if (!reqSnap.exists) throw StateError('Request not found.');
      final reqData = reqSnap.data()!;
      final status = CustomRequestStatus.fromString(reqData['status']?.toString());
      if (status != CustomRequestStatus.customerAccepted) {
        throw StateError('Request is not ready for dispatch.');
      }

      final customerId =
          reqData['customerId']?.toString() ?? reqData['userId']?.toString() ?? '';
      if (customerId.isEmpty) throw StateError('Missing customer on request.');

      final vendorId = reqData['winningVendorId']?.toString() ?? '';
      if (vendorId.isEmpty) throw StateError('Missing winning vendor.');

      final priceRaw = reqData['acceptedBidPrice'] ?? reqData['winningOfferedPrice'];
      final num offered = priceRaw is num
          ? priceRaw
          : num.tryParse(priceRaw?.toString() ?? '0') ?? 0;
      if (offered <= 0) throw StateError('Invalid accepted price.');

      final userRef = _db.collection('users').doc(customerId);
      final vendorRef = _db.collection('users').doc(vendorId);
      final userSnap = await transaction.get(userRef);
      final vendorSnap = await transaction.get(vendorRef);
      final u = userSnap.data() ?? {};
      final v = vendorSnap.data() ?? {};
      final userPhone = u['phoneNumber']?.toString().trim() ??
          reqData['customerPhone']?.toString() ??
          '';
      final vendorName = v['shopName']?.toString().trim().isNotEmpty == true
          ? v['shopName'].toString().trim()
          : (v['fullName']?.toString().trim() ?? 'Vendor');

      final description =
          reqData['description']?.toString() ?? reqData['notes']?.toString() ?? '';
      final imagePath =
          reqData['imagePath']?.toString() ?? reqData['referenceImageUrl']?.toString() ?? '';

      final omsRef = _db.collection(OmsOrderRepository.omsCollectionId).doc(orderId);
      final trimmedVoice = '';
      final trimmedDelivery = '';
      transaction.set(omsRef, {
        'orderId': orderId,
        'userId': customerId,
        'bouquetId': '',
        'bouquetCode': 'CUSTOM-${requestId.length > 10 ? requestId.substring(0, 10) : requestId}',
        'vendorId': vendorId,
        'customerPhone': userPhone,
        'addons': 'Custom bouquet tender — awaiting preparation.',
        'totalPrice': offered.round(),
        'status': OmsOrderStatus.pending.value,
        'createdAt': FieldValue.serverTimestamp(),
        'bouquetName': 'Custom bouquet (approved)',
        'vendorName': vendorName,
        'bouquetImageUrl': imagePath,
        'bouquetDetails': description,
        'voiceMessageLink': trimmedVoice.isEmpty ? null : trimmedVoice,
        'deliveryLocationLink': trimmedDelivery.isEmpty ? null : trimmedDelivery,
        'customRequestId': requestId,
        'orderSource': 'custom_tender',
      });

      transaction.update(reqRef, {
        'status': CustomRequestStatus.completed.value,
        'linkedOrderId': orderId,
      });

      return orderId;
    }).timeout(_timeout);
  }
}
