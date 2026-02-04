import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// App domain for Firebase Hosting and Auth authorized domains.
/// Ensure rehanrose.com is added in Firebase Console:
/// - Hosting → Add custom domain
/// - Authentication → Authorized domains
const String appDomain = 'rehanrose.com';
const String appBaseUrl = 'https://rehanrose.com';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDluGYifxWX1FRc9GnMwratL_mru1i9GH4',
    appId: '1:1012920953592:web:e19b852f6f43987cb8a90d',
    messagingSenderId: '1012920953592',
    projectId: 'gull-48040',
    authDomain: 'gull-48040.firebaseapp.com',
    storageBucket: 'gull-48040.firebasestorage.app',
    measurementId: 'G-3FSH29H6XS',
  );

  /// Use when running on custom domain so Auth redirects match. Add rehanrose.com to
  /// Firebase Console → Authentication → Authorized domains.
  static FirebaseOptions get webCustomDomain => FirebaseOptions(
    apiKey: web.apiKey,
    appId: web.appId,
    messagingSenderId: web.messagingSenderId,
    projectId: web.projectId,
    authDomain: 'rehanrose.com',
    storageBucket: web.storageBucket,
    measurementId: web.measurementId,
  );
}
