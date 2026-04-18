import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Top-level Firestore [notifications] documents:
/// `{ userId, title, body, isRead, createdAt }`.
class InAppNotificationRepository {
  InAppNotificationRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String collectionId = 'notifications';
  static const Duration _timeout = Duration(seconds: 25);

  /// Writes one notification for [userId].
  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
  }) async {
    if (userId.isEmpty) return;
    await _db.collection(collectionId).add({
      'userId': userId,
      'title': title,
      'body': body,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(_timeout);
  }

  /// Unread count for badge (listens to all matching docs).
  Stream<int> watchUnreadCount(String userId) {
    if (userId.isEmpty) return Stream.value(0);
    return _db
        .collection(collectionId)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  /// After admin broadcasts a custom request: notify every active vendor
  /// ([vendors] mirror first; if empty, approved vendor rows in [users]).
  Future<void> notifyActiveVendorsNewCustomTender() async {
    final vendorIds = <String>{};
    final mirror = await _db.collection('vendors').limit(500).get().timeout(_timeout);
    for (final d in mirror.docs) {
      if (d.id.isNotEmpty) vendorIds.add(d.id);
    }
    if (vendorIds.isEmpty) {
      final usersSnap = await _db
          .collection('users')
          .where('role', isEqualTo: 'vendor')
          .where('vendorStatus', isEqualTo: 'approved')
          .limit(200)
          .get()
          .timeout(_timeout);
      for (final d in usersSnap.docs) {
        if (d.id.isNotEmpty) vendorIds.add(d.id);
      }
    }
    const title = 'New Custom Request!';
    const body = 'A tender is open for bidding.';
    await _writeBatchedNotifications(
      recipientIds: vendorIds,
      title: title,
      body: body,
    );
  }

  /// When a vendor submits a bid: notify every super-admin recipient.
  Future<void> notifyAdminsNewBidOnCustomRequest({required String vendorId}) async {
    final adminIds = await _resolveAdminRecipientUserIds();
    if (adminIds.isEmpty) {
      debugPrint('InAppNotificationRepository: no admin recipients for new-bid alert.');
      return;
    }
    const title = 'New Bid!';
    final body =
        'Vendor has placed a bid on a custom request.${vendorId.isNotEmpty ? ' (Vendor ID: $vendorId)' : ''}';
    await _writeBatchedNotifications(
      recipientIds: adminIds,
      title: title,
      body: body,
    );
  }

  Future<List<String>> _resolveAdminRecipientUserIds() async {
    final out = <String>{};
    final adminsSnap = await _db.collection('admins').limit(100).get().timeout(_timeout);
    for (final d in adminsSnap.docs) {
      if (d.id.isNotEmpty) out.add(d.id);
    }
    final usersSnap = await _db
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .limit(50)
        .get()
        .timeout(_timeout);
    for (final d in usersSnap.docs) {
      if (d.id.isNotEmpty) out.add(d.id);
    }
    return out.toList();
  }

  Future<void> _writeBatchedNotifications({
    required Iterable<String> recipientIds,
    required String title,
    required String body,
  }) async {
    final unique = recipientIds.toSet()..removeWhere((e) => e.isEmpty);
    if (unique.isEmpty) return;

    var batch = _db.batch();
    var opCount = 0;
    for (final uid in unique) {
      final ref = _db.collection(collectionId).doc();
      batch.set(ref, {
        'userId': uid,
        'title': title,
        'body': body,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      opCount++;
      if (opCount >= 450) {
        await batch.commit().timeout(_timeout);
        batch = _db.batch();
        opCount = 0;
      }
    }
    if (opCount > 0) {
      await batch.commit().timeout(_timeout);
    }
  }
}
