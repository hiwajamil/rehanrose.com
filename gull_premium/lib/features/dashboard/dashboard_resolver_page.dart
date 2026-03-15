import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/env/app_env.dart';
import '../../controllers/controllers.dart';

/// Resolves the current user's role from Firestore and redirects to the correct
/// dashboard (Admin or Vendor). Use this as the single "Dashboard" destination
/// so that every navigation re-checks the role and routes correctly.
class DashboardResolverPage extends ConsumerWidget {
  const DashboardResolverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/');
          });
          return const _LoadingView();
        }
        return _RoleResolver(uid: user.uid);
      },
      loading: () => const _LoadingView(),
      error: (_, __) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go('/');
        });
        return const _LoadingView();
      },
    );
  }
}

class _RoleResolver extends ConsumerStatefulWidget {
  final String uid;

  const _RoleResolver({required this.uid});

  @override
  ConsumerState<_RoleResolver> createState() => _RoleResolverState();
}

class _RoleResolverState extends ConsumerState<_RoleResolver> {
  bool _redirectScheduled = false;

  Future<String?> _resolveRole() async {
    final authRepo = ref.read(authRepositoryProvider);
    // Super admin / admin must go to admin dashboard; check isAdmin first.
    final isAdmin = await authRepo.isAdmin(widget.uid);
    if (isAdmin) {
      final user = authRepo.currentUser;
      final superEmail = AppEnv.superAdminEmail.trim();
      if (superEmail.isNotEmpty &&
          user?.email?.trim().toLowerCase() == superEmail.toLowerCase()) {
        await authRepo.ensureSuperAdminUserDoc(user!.uid);
      }
      return 'admin';
    }
    final role = await authRepo.getUserRole(widget.uid);
    if (role != null && role.isNotEmpty) return role;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _resolveRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingView();
        }

        final role = snapshot.data;
        if (role == 'admin') {
          if (!_redirectScheduled) {
            _redirectScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/admin');
            });
          }
          return const _LoadingView();
        }
        if (role == 'vendor') {
          if (!_redirectScheduled) {
            _redirectScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/vendor');
            });
          }
          return const _LoadingView();
        }
        // Customer or unknown role: go to home (member/customer experience).
        if (!_redirectScheduled) {
          _redirectScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/');
          });
        }
        return const _LoadingView();
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

