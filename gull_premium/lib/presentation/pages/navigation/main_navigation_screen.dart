import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../auth/account_page.dart';
import '../cart/cart_screen.dart';
import '../landing/landing_page.dart';
import 'activity_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  static const double _desktopBreakpoint = 800;
  late int _currentIndex;
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3);
    _tabs = const [
      HomeScreen(),
      CartScreen(),
      ActivityScreen(),
      ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _desktopBreakpoint;
        final content = IndexedStack(index: _currentIndex, children: _tabs);

        if (!isDesktop) {
          return Scaffold(
            body: content,
            bottomNavigationBar: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
                type: BottomNavigationBarType.fixed,
                selectedItemColor: AppColors.rosePrimary,
                unselectedItemColor: AppColors.inkMuted,
                backgroundColor: AppColors.surface,
                elevation: 0,
                showUnselectedLabels: true,
                selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_filled),
                    activeIcon: Icon(Icons.home_filled),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.shopping_cart),
                    activeIcon: Icon(Icons.shopping_cart),
                    label: 'Cart',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.receipt_long_rounded),
                    activeIcon: Icon(Icons.receipt_long_rounded),
                    label: 'Activity',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person),
                    activeIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              Material(
                elevation: 6,
                shadowColor: Colors.black.withValues(alpha: 0.18),
                color: AppColors.footerBackground,
                child: NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _currentIndex = index),
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: 0.0,
                  backgroundColor: AppColors.footerBackground,
                  minWidth: 90,
                  minExtendedWidth: 220,
                  selectedIconTheme: const IconThemeData(
                    color: AppColors.accentGold,
                    size: 26,
                  ),
                  unselectedIconTheme: IconThemeData(
                    color: AppColors.footerTextMuted.withValues(alpha: 0.85),
                    size: 24,
                  ),
                  selectedLabelTextStyle: const TextStyle(
                    color: AppColors.accentGold,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.2,
                  ),
                  unselectedLabelTextStyle: TextStyle(
                    color: AppColors.footerTextMuted.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                  indicatorColor: AppColors.accentGold.withValues(alpha: 0.18),
                  useIndicator: true,
                  leading: const Padding(
                    padding: EdgeInsets.only(top: 14, bottom: 20),
                    child: Icon(
                      Icons.local_florist_rounded,
                      color: AppColors.accentGold,
                      size: 32,
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_filled),
                      selectedIcon: Icon(Icons.home_filled),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.shopping_cart),
                      selectedIcon: Icon(Icons.shopping_cart),
                      label: Text('Cart'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.receipt_long_rounded),
                      selectedIcon: Icon(Icons.receipt_long_rounded),
                      label: Text('Activity'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person),
                      selectedIcon: Icon(Icons.person),
                      label: Text('Profile'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: AppColors.background,
                  child: content,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const LandingPage();
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => const AccountPage();
}
