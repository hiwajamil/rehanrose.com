import 'package:flutter/material.dart';

import 'vendor_dashboard_page.dart';

/// Placeholder "Vendor Auth" screen.
///
/// The real vendor sign-in / sign-up + onboarding UI already exists inside
/// [VendorDashboardPage] (it toggles between marketing sign-in and "start
/// application" based on auth state). This screen provides a dedicated
/// route so the Drawer can navigate to a stable auth entry point.
class VendorAuthScreen extends StatelessWidget {
  const VendorAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VendorDashboardPage();
  }
}

