import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'env/google_client_id.dart';

/// App domain for Firebase Hosting and Auth authorized domains.
/// Ensure rehanrose.com is added in Firebase Console:
/// - Hosting → Add custom domain
/// - Authentication → Authorized domains
const String appDomain = 'rehanrose.com';
const String appBaseUrl = 'https://rehanrose.com';

class DefaultFirebaseOptions {
  /// Google OAuth 2.0 Web client ID (required for "Continue with Google").
  /// Uses [kGoogleWebClientId] from lib/env/google_client_id.dart if set,
  /// otherwise --dart-define=GOOGLE_WEB_CLIENT_ID=...
  static String get googleWebClientId =>
      kGoogleWebClientId.isNotEmpty
          ? kGoogleWebClientId
          : String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
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

  /// iOS config (from GoogleService-Info.plist after adding iOS app in Firebase Console).
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBN1pDGlcg05BqyrAfan6Ehuksys_I2Nag',
    appId: '1:1012920953592:ios:824784a0e434369cb8a90d',
    messagingSenderId: '1012920953592',
    projectId: 'gull-48040',
    authDomain: 'gull-48040.firebaseapp.com',
    storageBucket: 'gull-48040.firebasestorage.app',
    iosBundleId: 'com.example.rehanRose',
  );

  /// Android config. Run `dart run flutterfire_cli:flutterfire configure` to generate
  /// platform-specific keys after adding the Android app in Firebase Console.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDluGYifxWX1FRc9GnMwratL_mru1i9GH4',
    appId: '1:1012920953592:android:placeholder',
    messagingSenderId: '1012920953592',
    projectId: 'gull-48040',
    authDomain: 'gull-48040.firebaseapp.com',
    storageBucket: 'gull-48040.firebasestorage.app',
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
