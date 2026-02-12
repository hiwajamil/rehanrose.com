import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/analytics_service.dart';
import '../core/services/firebase_init.dart' as fb;

/// Provides [FirebaseAnalytics] when Firebase is initialized; otherwise null.
final firebaseAnalyticsProvider = Provider<FirebaseAnalytics?>((ref) {
  return fb.isFirebaseInitialized ? FirebaseAnalytics.instance : null;
});

/// Provides [AnalyticsService] for logging events. No-ops when Firebase init failed.
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final analytics = ref.watch(firebaseAnalyticsProvider);
  return AnalyticsService(analytics);
});
