import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack, kIsWeb;

import 'notification_service.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessagingSubscription;
  bool _initialized = false;
  bool _foregroundMessagingBound = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;
    await _messaging.requestPermission();
    _listenForTokenRefresh();
    _bindForegroundCustomTenderMessaging();
  }

  /// Listens for FCM data messages that signal a new open tender (server should set `type`).
  void _bindForegroundCustomTenderMessaging() {
    if (kIsWeb || _foregroundMessagingBound) return;
    _foregroundMessagingBound = true;
    _foregroundMessagingSubscription ??= FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) async {
        final data = message.data;
        final t = data['type']?.toString() ?? '';
        if (t != 'custom_request_broadcast' && t != 'custom_tender_broadcast') return;
        final title = message.notification?.title ??
            data['title']?.toString() ??
            'New custom request';
        final body = message.notification?.body ??
            data['body']?.toString() ??
            'Open Tender / Open Requests to place a bid.';
        await NotificationService.instance.showCustomTenderBroadcastNotification(title, body);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM onMessage error: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  /// Vendors should receive topic pushes when admins broadcast (configure server to target this topic).
  Future<void> subscribeVendorCustomTenderTopic() async {
    if (kIsWeb) return;
    await initialize();
    try {
      await _messaging.subscribeToTopic('custom_tender_vendors');
    } catch (e, st) {
      debugPrint('FCM subscribe custom_tender_vendors failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> syncTokenForCurrentUser(String? uid) async {
    if (kIsWeb || uid == null || uid.isEmpty) return;

    await initialize();
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    await _saveToken(uid, token);
  }

  void _listenForTokenRefresh() {
    _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen(
      (newToken) async {
        final uid = fa.FirebaseAuth.instance.currentUser?.uid;
        if (uid == null || uid.isEmpty || newToken.isEmpty) return;
        await _saveToken(uid, newToken);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM token refresh listener error: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  Future<void> _saveToken(String uid, String token) {
    return _firestore.collection('users').doc(uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }

  Future<void> dispose() async {
    await _foregroundMessagingSubscription?.cancel();
    _foregroundMessagingSubscription = null;
    _foregroundMessagingBound = false;
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _initialized = false;
  }
}
