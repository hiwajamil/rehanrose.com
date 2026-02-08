import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';

/// Returns a user-friendly message for any auth-related error.
/// Avoids leaking internal messages (e.g. Pigeon/platform strings) to users.
String authErrorMessage(Object error, {String fallback = 'Unable to sign in. Please try again.'}) {
  if (error is fa.FirebaseAuthException) {
    final msg = error.message;
    if (msg != null && msg.isNotEmpty && !_isInternalMessage(msg)) {
      return msg;
    }
    return _firebaseAuthCodeMessage(error.code) ?? fallback;
  }
  if (error is PlatformException) {
    final msg = error.message;
    if (msg != null && msg.isNotEmpty && !_isInternalMessage(msg)) {
      return msg;
    }
  }
  // Exception(message) from controller or elsewhere - use message if it looks user-facing.
  if (error is Exception) {
    final s = error.toString();
    if (s.startsWith('Exception: ') && s.length > 11) {
      final msg = s.substring(11).trim();
      if (msg.isNotEmpty && !_isInternalMessage(msg)) return msg;
    }
  }
  if (kDebugMode && error is Exception) {
    // In debug, you could log error.toString() here.
  }
  return fallback;
}

bool _isInternalMessage(String msg) {
  final lower = msg.toLowerCase();
  return lower.contains('pigeon') ||
      lower.contains('firebaseauthhostapi') ||
      lower.contains('platform_interface') ||
      lower.contains('dev.flutter');
}

String? _firebaseAuthCodeMessage(String? code) {
  switch (code) {
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Invalid email or password. Please try again.';
    case 'user-disabled':
      return 'This account has been disabled. Contact support.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    case 'invalid-email':
      return 'Please enter a valid email address.';
    case 'weak-password':
      return 'Password is too weak. Use at least 6 characters.';
    case 'email-already-in-use':
      return 'An account with this email already exists.';
    case 'network-request-failed':
      return 'Network error. Check your connection and try again.';
    default:
      return null;
  }
}
