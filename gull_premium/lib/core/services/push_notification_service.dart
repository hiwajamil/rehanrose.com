import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack, kIsWeb;

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;
    await _messaging.requestPermission();
    _listenForTokenRefresh();
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
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _initialized = false;
  }
}
