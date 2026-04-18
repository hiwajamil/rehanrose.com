import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../firebase_options.dart';
import 'notification_service.dart';

/// Must be a top-level function for [FirebaseMessaging.onBackgroundMessage].
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
}
