import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';

/// Returns a user-friendly message for any auth-related error.
/// Avoids leaking internal messages (e.g. Pigeon/platform strings) to users.
/// In debug mode, appends the raw error so you can fix configuration.
String authErrorMessage(Object error, {String fallback = 'Unable to sign in. Please try again.'}) {
  if (error is fa.FirebaseAuthException) {
    final msg = error.message;
    if (msg != null && msg.isNotEmpty && !_isInternalMessage(msg)) {
      return _maybeAppendDebug(msg, error);
    }
    final codeMsg = _firebaseAuthCodeMessage(error.code);
    if (codeMsg != null) return _maybeAppendDebug(codeMsg, error);
    // Unknown Firebase code - still show code in debug
    return _maybeAppendDebug(fallback, error);
  }
  if (error is PlatformException) {
    final msg = error.message;
    final code = error.code;
    if (msg != null && msg.isNotEmpty && !_isInternalMessage(msg)) {
      return _maybeAppendDebug(msg, error);
    }
    // Use code for known Google Sign-In / auth failures
    if (code.isNotEmpty) {
      final codeLower = code.toLowerCase();
      if (codeLower.contains('sign_in_failed') ||
          codeLower.contains('12501') ||
          codeLower.contains('developer_error') ||
          codeLower.contains('10')) {
        return _maybeAppendDebug(
          'Google sign-in failed. Check that the app is configured with the Web client ID (Firebase Console → Authentication → Google).',
          error,
        );
      }
      if (codeLower.contains('network') || codeLower.contains('cancel')) {
        return codeLower.contains('cancel')
            ? 'Sign-in was cancelled.'
            : 'Network error. Check your connection and try again.';
      }
    }
  }
  // Google Sign-In cancelled by user or configuration errors.
  if (error is Exception) {
    final s = error.toString();
    if (s.contains('sign_in_cancelled') || s.contains('sign_in_canceled')) {
      return 'Sign-in was cancelled.';
    }
    if (s.contains('popup_closed_by_user') || s.contains('popup-blocked')) {
      return 'Sign-in was cancelled or blocked.';
    }
    if (s.contains('GOOGLE_WEB_CLIENT_ID') || s.contains('no credentials')) {
      return 'Google sign-in is not configured. Add the Web client ID (Firebase Console → Authentication → Google) and run with --dart-define=GOOGLE_WEB_CLIENT_ID=...';
    }
    if (s.contains('DEVELOPER_ERROR') || s.contains('10') || s.contains('12501')) {
      return _maybeAppendDebug(
        'Google sign-in setup error. Configure the Web client ID in Firebase Console → Authentication → Google.',
        error,
      );
    }
    if (s.contains('network')) {
      return 'Network error. Check your connection and try again.';
    }
    // Exception(message) from controller or elsewhere - use message if it looks user-facing.
    if (s.startsWith('Exception: ') && s.length > 11) {
      final msg = s.substring(11).trim();
      if (msg.isNotEmpty && !_isInternalMessage(msg)) {
        return _maybeAppendDebug(msg, error);
      }
    }
  }
  return _maybeAppendDebug(fallback, error);
}

String _maybeAppendDebug(String message, Object error) {
  if (!kDebugMode) return message;
  final raw = error.toString();
  if (raw.length > 120) return '$message\n(Debug: ${raw.substring(0, 120)}…)';
  return '$message\n(Debug: $raw)';
}

bool _isInternalMessage(String msg) {
  final lower = msg.toLowerCase();
  return lower.contains('pigeon') ||
      lower.contains('firebaseauthhostapi') ||
      lower.contains('platform_interface') ||
      lower.contains('dev.flutter');
}

String? _firebaseAuthCodeMessage(String? code) {
  if (code == null) return null;
  switch (code) {
    case 'user-not-found':
    case 'wrong-password':
      return 'Invalid email or password. Please try again.';
    case 'invalid-credential':
      return 'Sign-in failed. If using Google, ensure the Web client ID is set (Firebase Console → Authentication → Google).';
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
    case 'internal-error':
      return 'Sign-in failed. Check app configuration (e.g. Google Web client ID).';
    default:
      return null;
  }
}
