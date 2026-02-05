import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/firebase_init.dart';
import '../../controllers/controllers.dart';
import '../../presentation/pages/landing/landing_page.dart';
import '../../presentation/pages/admin/admin_dashboard_page.dart';
import '../../presentation/pages/product/product_detail_page.dart';
import '../../presentation/pages/vendor/vendor_dashboard_page.dart';
import '../../presentation/pages/vendor/vendor_orders_page.dart';
import '../../presentation/pages/vendor/vendor_bouquets_page.dart';
import '../../presentation/pages/vendor/vendor_add_bouquet_page.dart';
import '../../presentation/pages/vendor/vendor_earnings_page.dart';
import '../../presentation/pages/vendor/vendor_notifications_page.dart';
import '../../presentation/pages/vendor/vendor_shop_settings_page.dart';
import '../../presentation/pages/vendor/vendor_support_page.dart';
import '../../presentation/widgets/layout/vendor_shell_layout.dart';

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
      ShellRoute(
        builder: (context, state, child) {
          return Consumer(
            builder: (_, ref, __) {
              final user = ref.watch(authStateProvider).value;
              if (user == null) return child;
              return VendorShellLayout(child: child);
            },
          );
        },
        routes: [
          GoRoute(
            path: '/vendor',
            builder: (context, state) => const VendorDashboardPage(),
            routes: [
              GoRoute(
                path: 'orders',
                builder: (_, __) => const VendorOrdersPage(),
              ),
              GoRoute(
                path: 'bouquets',
                builder: (_, __) => const VendorBouquetsPage(),
              ),
              GoRoute(
                path: 'bouquets/add',
                builder: (_, __) => const VendorAddBouquetPage(),
              ),
              GoRoute(
                path: 'earnings',
                builder: (_, __) => const VendorEarningsPage(),
              ),
              GoRoute(
                path: 'notifications',
                builder: (_, __) => const VendorNotificationsPage(),
              ),
              GoRoute(
                path: 'shop-settings',
                builder: (_, __) => const VendorShopSettingsPage(),
              ),
              GoRoute(
                path: 'support',
                builder: (_, __) => const VendorSupportPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardPage(),
      ),
    ],
  );
}
