import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_redirect_notifier.dart';
import '../services/firebase_init.dart';
import '../../controllers/controllers.dart';
import '../../presentation/pages/landing/landing_page.dart';
import '../../presentation/pages/about/about_us_screen.dart';
import '../../presentation/pages/designers/designers_list_page.dart';
import '../../presentation/pages/faq_screen.dart';
import '../../presentation/pages/legal/contact_us_screen.dart';
import '../../presentation/pages/legal/legal_page.dart';
import '../../presentation/pages/legal/terms_conditions_screen.dart';
import '../../presentation/pages/florists/vendor_profile_page.dart';
import '../../presentation/pages/admin/admin_dashboard_page.dart';
import '../../presentation/pages/admin/bouquet_approval_page.dart';
import '../../presentation/pages/admin/analytics_overview_page.dart';
import '../../presentation/pages/admin/add_on_category_inventory_page.dart';
import '../../presentation/pages/admin/admin_orders_page.dart';
import '../../presentation/pages/admin/manage_add_ons_landing_page.dart';
import '../../presentation/pages/admin/members/members_list_screen.dart';
import '../../presentation/pages/admin/admin_vendors_management_page.dart';
import '../../presentation/pages/admin/drivers_management_screen.dart';
import '../../presentation/pages/driver/driver_application_screen.dart';
import '../../presentation/pages/driver/driver_auth_screen.dart';
import '../../presentation/pages/driver/driver_dashboard_screen.dart';
import '../../presentation/pages/driver/driver_phone_auth_screen.dart';
import '../../presentation/pages/driver/waiting_for_driver_approval_screen.dart';
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
import '../../presentation/pages/vendor/vendor_auth_screen.dart';
import '../../presentation/widgets/layout/admin_shell_layout.dart';
import '../../presentation/widgets/layout/vendor_shell_layout.dart';
import '../../data/models/add_on_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../features/dashboard/dashboard_resolver_page.dart';
import '../../presentation/pages/voice/voice_playback_page.dart';
import '../../presentation/pages/auth/login_screen.dart';
import '../../presentation/pages/auth/registration_screen.dart';
import '../../presentation/pages/auth/account_page.dart';
import '../../presentation/pages/account/customer_orders_page.dart';
import '../../presentation/pages/account/customer_addresses_page.dart';

class AppRouter {
  /// Creates the app router with [authNotifier] so redirect waits for auth to
  /// be determined before redirecting. This preserves the current URL on web
  /// refresh (vendor/admin/member pages) instead of sending users to home.
  static GoRouter createRouter(AuthRedirectNotifier authNotifier) {
    return GoRouter(
      refreshListenable: authNotifier,
      observers: isFirebaseInitialized
          ? [FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)]
          : [],
      redirect: (context, state) async {
        final location = state.matchedLocation;

        // Wait for auth to be determined (Firebase restores session async on web).
        // While loading, stay on current URL so refresh keeps the user on the same page.
        if (authNotifier.isLoading) {
          return null;
        }

        final user = authNotifier.currentState.when(
              data: (u) => u,
              loading: () => null,
              error: (_, __) => null,
            ) ??
            fa.FirebaseAuth.instance.currentUser;

        // Vendor routes should never be accessible when signed out, except for
        // the public vendor onboarding/auth screen.
        final isVendorAuthPublic =
            location == '/vendor-auth' || location == '/vendor-auth/';
        if (location.startsWith('/vendor') && user == null && !isVendorAuthPublic) {
          return '/';
        }

        // Generic dashboard resolver requires auth; if signed out, go home.
        if (location == '/dashboard' && user == null) {
          return '/';
        }

        // If authenticated users hit public entry pages, route by role so they
        // land directly in their workspace and do not re-enter customer flow.
        if (user != null &&
            (location == '/' ||
                location == '/login' ||
                location == '/register' ||
                location == '/dashboard')) {
          final authRepo = AuthRepository();
          final role = await authRepo.getRoleForRouting(user.uid);
          if (role == 'admin') return '/admin';
          if (role == 'vendor') return '/vendor';
          if (role == 'driver') return '/driver';
        }

        // Admin routes: allow unauthenticated access so /admin shows its own admin
        // sign-in form; only allow access if user has admin role or is in admins list.
        if (location.startsWith('/admin')) {
          if (user == null) {
            return null; // Let AdminDashboardPage show admin sign-in screen
          }
          final authRepo = AuthRepository();
          final isAdmin = await authRepo.isAdmin(user.uid);
          final role = await authRepo.getUserRole(user.uid);
          final hasAdminAccess = isAdmin || role == 'admin';
          if (!hasAdminAccess) {
            return '/';
          }
          return null;
        }

        // Vendor routes: if user is admin, send them to admin dashboard.
        if (location.startsWith('/vendor')) {
          if (user != null) {
            final authRepo = AuthRepository();
            if (await authRepo.isAdmin(user.uid)) {
              return '/admin';
            }
          }
        }
        // Driver onboarding: dashboard only for approved drivers; application & waiting gated.
        if (location.startsWith('/driver')) {
          if (location == '/driver/phone-auth' || location == '/driver-auth') {
            return null;
          }
          if (user == null) return '/login';
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final d = doc.data() ?? {};
          final role = d['role']?.toString() ?? '';
          final appStatus = d['applicationStatus']?.toString() ?? '';
          final isApprovedDriver = role == 'driver' &&
              (appStatus == 'approved' || appStatus.isEmpty);

          if (location == '/driver' || location == '/driver/') {
            if (isApprovedDriver) return null;
            if (appStatus == 'pending_driver') return '/driver/waiting';
            return '/driver/application';
          }
          if (location.startsWith('/driver/waiting')) {
            if (isApprovedDriver) return '/driver';
            if (appStatus != 'pending_driver') {
              if (appStatus == 'rejected' || appStatus.isEmpty) {
                return '/driver/application';
              }
            }
            return null;
          }
          if (location.startsWith('/driver/application')) {
            if (isApprovedDriver) return '/driver';
            if (appStatus == 'pending_driver') return '/driver/waiting';
            return null;
          }
        }
        return null;
      },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LandingPage(),
      ),
      GoRoute(
        path: '/v',
        builder: (context, state) {
          final url = state.uri.queryParameters['url'] ?? '';
          return VoicePlaybackPage(audioUrl: url);
        },
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardResolverPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegistrationScreen(),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountPage(),
      ),
      GoRoute(
        path: '/vendor-auth',
        builder: (context, state) => const VendorAuthScreen(),
      ),
      GoRoute(
        path: '/driver',
        builder: (context, state) => const DriverDashboardScreen(),
      ),
      GoRoute(
        path: '/driver-auth',
        builder: (context, state) => const DriverAuthScreen(),
      ),
      GoRoute(
        path: '/driver/application',
        builder: (context, state) => const DriverApplicationScreen(),
      ),
      GoRoute(
        path: '/driver/phone-auth',
        builder: (context, state) => const DriverPhoneAuthScreen(),
      ),
      GoRoute(
        path: '/driver/waiting',
        builder: (context, state) => const WaitingForDriverApprovalScreen(),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const CustomerOrdersPage(),
      ),
      GoRoute(
        path: '/addresses',
        builder: (context, state) => const CustomerAddressesPage(),
      ),
      GoRoute(
        path: '/offers',
        builder: (context, state) => const LandingPage(saleOnly: true),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutUsScreen(),
      ),
      GoRoute(
        path: '/terms-conditions',
        builder: (context, state) => const TermsConditionsScreen(),
      ),
      GoRoute(
        path: '/faq',
        builder: (context, state) => const FaqScreen(),
      ),
      GoRoute(
        path: '/contact-us',
        builder: (context, state) => const ContactUsScreen(),
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
                path: 'profile',
                builder: (context, state) {
                  return Consumer(
                    builder: (_, ref, __) {
                      final uid = ref.watch(authStateProvider).value?.uid ?? '';
                      return VendorProfilePage(vendorId: uid);
                    },
                  );
                },
              ),
              GoRoute(
                path: 'support',
                builder: (_, __) => const VendorSupportPage(),
              ),
            ],
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShellLayout(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminDashboardPage(),
            routes: [
              GoRoute(
                path: 'add-ons',
                builder: (_, __) => const ManageAddOnsLandingPage(),
                routes: [
                  GoRoute(
                    path: 'vases',
                    builder: (_, __) => const AddOnCategoryInventoryPage(
                      categoryType: AddOnType.vase,
                    ),
                  ),
                  GoRoute(
                    path: 'chocolates',
                    builder: (_, __) => const AddOnCategoryInventoryPage(
                      categoryType: AddOnType.chocolate,
                    ),
                  ),
                  GoRoute(
                    path: 'cards',
                    builder: (_, __) => const AddOnCategoryInventoryPage(
                      categoryType: AddOnType.card,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'analytics',
                builder: (_, __) => const AnalyticsOverviewPage(),
              ),
              GoRoute(
                path: 'approvals',
                builder: (_, __) => const BouquetApprovalPage(),
              ),
              GoRoute(
                path: 'orders',
                builder: (_, __) => const AdminOrdersPage(),
              ),
              GoRoute(
                path: 'members',
                builder: (_, __) => const MembersListScreen(),
              ),
              GoRoute(
                path: 'vendors',
                builder: (_, __) => const AdminVendorsManagementPage(),
              ),
              GoRoute(
                path: 'drivers',
                builder: (_, __) => const DriversManagementScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    );
  }
}
