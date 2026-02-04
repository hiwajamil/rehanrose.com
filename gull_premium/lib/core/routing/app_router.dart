import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:go_router/go_router.dart';

import '../services/firebase_init.dart';
import '../../presentation/pages/landing/landing_page.dart';
import '../../presentation/pages/admin/admin_dashboard_page.dart';
import '../../presentation/pages/product/product_detail_page.dart';
import '../../presentation/pages/vendor/vendor_dashboard_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    observers: isFirebaseInitialized
        ? [FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)]
        : [],
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LandingPage(),
      ),
      GoRoute(
        path: '/flower/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ProductDetailPage(flowerId: id);
        },
      ),
      GoRoute(
        path: '/vendor',
        builder: (context, state) => const VendorDashboardPage(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardPage(),
      ),
    ],
  );
}
