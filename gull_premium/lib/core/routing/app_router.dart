import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/firebase_init.dart';
import '../../controllers/controllers.dart';
import '../../presentation/pages/landing/landing_page.dart';
import '../../presentation/pages/about/about_page.dart';
import '../../presentation/pages/designers/designers_list_page.dart';
import '../../presentation/pages/legal/legal_page.dart';
import '../../presentation/pages/florists/vendor_profile_page.dart';
import '../../presentation/pages/admin/admin_dashboard_page.dart';
import '../../presentation/pages/admin/analytics_overview_page.dart';
import '../../presentation/pages/admin/manage_add_ons_page.dart';
import '../../presentation/pages/product/order_customization_page.dart';
import '../../presentation/pages/product/product_detail_page.dart';
import '../../presentation/pages/product/product_listing_page.dart';
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
        path: '/offers',
        builder: (context, state) => const LandingPage(saleOnly: true),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutPage(),
      ),
      GoRoute(
        path: '/legal',
        builder: (context, state) => const LegalPage(),
      ),
      GoRoute(
        path: '/florists',
        builder: (context, state) => const DesignersListPage(),
      ),
      GoRoute(
        path: '/florist/:vendorId',
        builder: (context, state) {
          final vendorId = state.pathParameters['vendorId'] ?? '';
          return VendorProfilePage(vendorId: vendorId);
        },
      ),
      GoRoute(
        path: '/products',
        builder: (context, state) {
          final category = state.uri.queryParameters['category'];
          return ProductListingPage(filterByCategory: category);
        },
      ),
      GoRoute(
        path: '/flower/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ProductDetailPage(flowerId: id);
        },
        routes: [
          GoRoute(
            path: 'order',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return OrderCustomizationPage(flowerId: id);
            },
          ),
        ],
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
        routes: [
          GoRoute(
            path: 'add-ons',
            builder: (_, __) => const ManageAddOnsPage(),
          ),
          GoRoute(
            path: 'analytics',
            builder: (_, __) => const AnalyticsOverviewPage(),
          ),
        ],
      ),
    ],
  );
}
