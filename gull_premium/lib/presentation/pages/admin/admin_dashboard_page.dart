import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env/app_env.dart';
import '../../../core/constants/breakpoints.dart';
import '../../../core/utils/auth_error_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../controllers/controllers.dart';
import '../../widgets/common/primary_button.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final Set<String> _processingApplications = {};
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!mounted) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showMessage(AppLocalizations.of(context)!.adminEnterEmailPassword);
      return;
    }
    if (!mounted) return;
    setState(() => _isSigningIn = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      try {
        await authRepo.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on fa.FirebaseAuthException catch (e) {
        final superEmail = AppEnv.superAdminEmail.trim();
        if (e.code == 'user-not-found' &&
            superEmail.isNotEmpty &&
            email.toLowerCase() == superEmail.toLowerCase()) {
          await authRepo.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } else {
          rethrow;
        }
      }
      if (!mounted) return;
      final user = authRepo.currentUser;
      final superEmail = AppEnv.superAdminEmail.trim();
      if (user != null &&
          superEmail.isNotEmpty &&
          user.email?.trim().toLowerCase() == superEmail.toLowerCase()) {
        await authRepo.ensureSuperAdminUserDoc(user.uid);
      }
    } on fa.FirebaseAuthException catch (e) {
      if (mounted) {
        _showMessage(authErrorMessage(e, fallback: AppLocalizations.of(context)!.adminUnableToSignIn));
      }
    } catch (e, _) {
      if (mounted) {
        _showMessage(authErrorMessage(e, fallback: AppLocalizations.of(context)!.adminUnableToSignIn));
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    return authAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _buildFullScreenWrapper(context, _buildAdminSignIn(context)),
      data: (user) {
        if (user == null) return _buildFullScreenWrapper(context, _buildAdminSignIn(context));
        final isAdminAsync = ref.watch(isAdminForUidProvider(user.uid));
        return isAdminAsync.when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => _buildFullScreenWrapper(context, _buildAdminSignIn(context)),
          data: (isAdmin) {
            if (!isAdmin) return _buildFullScreenWrapper(context, _buildNotAuthorized(context, user));
            return _buildAdminDashboard(context, user.uid);
          },
        );
      },
    );
  }

  Widget _buildFullScreenWrapper(BuildContext context, Widget child) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        color: const Color(0xFFF4F5F7),
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width <= kMobileBreakpoint ? 16 : 48,
          vertical: MediaQuery.sizeOf(context).width <= kMobileBreakpoint ? 24 : 56,
        ),
        child: Center(child: SingleChildScrollView(child: child)),
      ),
    );
  }

  Widget _buildAdminSignIn(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 26,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminSuperAdminDashboard,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.adminSignInPrompt,
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: 20),
          _AdminField(
            label: l10n.adminEmailLabel,
            controller: _emailController,
            hintText: l10n.adminEmailHint,
            icon: Icons.mail_outline,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _AdminField(
            label: l10n.adminPasswordLabel,
            controller: _passwordController,
            hintText: l10n.adminPasswordHint,
            icon: Icons.lock_outline,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: _isSigningIn ? null : _signIn,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSigningIn ? null : _signIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.rose,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              child: Text(
                _isSigningIn ? l10n.adminSigningIn : l10n.signIn,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotAuthorized(BuildContext context, fa.User user) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.adminAccessRestricted,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.adminNotRegisteredPrompt,
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: 12),
          SelectableText(
            l10n.adminFirestoreInstructions(user.uid),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: AppColors.inkMuted,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.adminFirestoreSteps,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: l10n.adminSignOut,
            onPressed: () async {
              try {
                await ref.read(authRepositoryProvider).signOut();
              } finally {
                await fa.FirebaseAuth.instance.signOut();
              }
              if (context.mounted) context.go('/');
            },
            variant: PrimaryButtonVariant.outline,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminDashboard(BuildContext context, String adminId) {
    final l10n = AppLocalizations.of(context)!;
    final applicationsAsync = ref.watch(pendingVendorApplicationsStreamProvider);
    final isMobile = MediaQuery.sizeOf(context).width < kAdminShellDrawerBreakpoint;
    final verticalSpacing = isMobile ? 16.0 : 20.0;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _AdminMetricsRow(),
              SizedBox(height: verticalSpacing),
              Text(
                l10n.adminPendingApplications,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
              ),
              SizedBox(height: verticalSpacing),
              _buildPendingApplicationsSection(
                context: context,
                adminId: adminId,
                applicationsAsync: applicationsAsync,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingApplicationsSection({
    required BuildContext context,
    required String adminId,
    required AsyncValue<QuerySnapshot<Map<String, dynamic>>> applicationsAsync,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: applicationsAsync.when(
        loading: () => Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.adminLoadingApplications,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
        error: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              l10n.adminUnableToLoadApplications,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.inkMuted),
            ),
          ),
        ),
        data: (snapshot) {
          final docs = snapshot.docs;
          if (docs.isEmpty) {
            return SizedBox(
              height: 220,
              child: Center(
                child: Text(
                  l10n.adminNoPendingApplications,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppColors.inkMuted),
                ),
              ),
            );
          }
          return Column(
            children: docs
                .map((doc) => _buildApplicationCard(
                      context: context,
                      doc: doc,
                      adminId: adminId,
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildApplicationCard({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required String adminId,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final data = doc.data();
    final isProcessing = _processingApplications.contains(doc.id);
    final isMobileCard =
        MediaQuery.sizeOf(context).width < kAdminShellDrawerBreakpoint;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(isMobileCard ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['studioName']?.toString() ?? l10n.adminStudio,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _DetailRow(
            label: l10n.adminOwner,
            value: data['ownerName']?.toString() ?? '--',
          ),
          _DetailRow(
            label: l10n.adminEmail,
            value: data['email']?.toString() ?? '--',
          ),
          _DetailRow(
            label: l10n.adminPhone,
            value: data['phone']?.toString() ?? '--',
          ),
          _DetailRow(
            label: l10n.adminLocation,
            value: data['location']?.toString() ?? '--',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < kAdminShellDrawerBreakpoint;
              final approveBtn = PrimaryButton(
                label: isProcessing ? l10n.adminWorking : l10n.adminApprove,
                onPressed: isProcessing
                    ? () {}
                    : () async {
                        setState(() => _processingApplications.add(doc.id));
                        try {
                          await ref
                              .read(authRepositoryProvider)
                              .approveVendorApplication(
                                doc.id,
                                data,
                                adminId,
                              );
                          if (mounted) {
                            _showMessage(l10n.adminApplicationApproved);
                          }
                        } catch (_) {
                          if (mounted) {
                            _showMessage(l10n.adminUnableToApprove);
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _processingApplications.remove(doc.id));
                          }
                        }
                      },
              );
              final rejectBtn = PrimaryButton(
                label: isProcessing ? l10n.adminWorking : l10n.adminReject,
                onPressed: isProcessing
                    ? () {}
                    : () async {
                        setState(() => _processingApplications.add(doc.id));
                        try {
                          await ref
                              .read(authRepositoryProvider)
                              .rejectVendorApplication(doc.id, adminId);
                          if (mounted) {
                            _showMessage(l10n.adminApplicationRejected);
                          }
                        } catch (_) {
                          if (mounted) {
                            _showMessage(l10n.adminUnableToReject);
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _processingApplications.remove(doc.id));
                          }
                        }
                      },
                variant: PrimaryButtonVariant.outline,
              );
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    approveBtn,
                    const SizedBox(height: 12),
                    rejectBtn,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: approveBtn),
                  const SizedBox(width: 12),
                  Expanded(child: rejectBtn),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdminMetricsRow extends StatefulWidget {
  const _AdminMetricsRow();

  @override
  State<_AdminMetricsRow> createState() => _AdminMetricsRowState();
}

class _AdminMetricsRowState extends State<_AdminMetricsRow> {
  late final Stream<int> _membersStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _vendorsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _onlineVendorsStream;

  @override
  void initState() {
    super.initState();
    _membersStream = ProviderScope.containerOf(
      context,
    ).read(membersRepositoryProvider).watchCustomerCount();
    _vendorsStream = ProviderScope.containerOf(
      context,
    ).read(authRepositoryProvider).watchVendorApplications();
    _onlineVendorsStream = ProviderScope.containerOf(
      context,
    ).read(authRepositoryProvider).watchOnlineVendors();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isNarrow =
        MediaQuery.sizeOf(context).width < kAdminShellDrawerBreakpoint;

    final membersCard = StreamBuilder<int>(
      stream: _membersStream,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final value = snapshot.hasData ? '${snapshot.data}' : '—';
        return _MetricCard(
          icon: Icons.people_outline,
          title: l10n.adminTotalMembers,
          value: value,
          isLoading: isLoading,
          onTap: () => context.push('/admin/members'),
        );
      },
    );

    final vendorsCard = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _vendorsStream,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final value = snapshot.hasData ? '${snapshot.data!.docs.length}' : '—';
        return _MetricCard(
          icon: Icons.pending_actions_outlined,
          title: l10n.adminPendingApplications,
          value: value,
          isLoading: isLoading,
          onTap: () => context.go('/admin'),
        );
      },
    );

    final onlineVendorsCard =
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _onlineVendorsStream,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final value = snapshot.hasData ? '${snapshot.data!.docs.length}' : '—';
        return _MetricCard(
          icon: Icons.storefront_outlined,
          title: l10n.adminOnlineVendors,
          value: value,
          isLoading: isLoading,
          onTap: () => context.go('/admin'),
        );
      },
    );

    return isNarrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              membersCard,
              const SizedBox(height: 12),
              vendorsCard,
              const SizedBox(height: 12),
              onlineVendorsCard,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: membersCard),
              const SizedBox(width: 16),
              Expanded(child: vendorsCard),
              const SizedBox(width: 16),
              Expanded(child: onlineVendorsCard),
            ],
          );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.isLoading,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isNarrow =
        MediaQuery.sizeOf(context).width < kAdminShellDrawerBreakpoint;
    final padding = isNarrow ? 16.0 : 20.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.rosePrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: AppColors.rosePrimary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Fixed-height placeholder to prevent card height jump during loading.
                    SizedBox(
                      height: 28,
                      child: isLoading
                          ? Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.rose,
                                ),
                              ),
                            )
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                value,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.rosePrimary,
                                    ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: AppColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminField extends StatelessWidget {
  final String label;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextEditingController controller;
  final VoidCallback? onSubmitted;
  final TextInputAction? textInputAction;

  const _AdminField({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.onSubmitted,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted != null ? (_) => onSubmitted!() : null,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: AppColors.inkMuted),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.rose),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final labelWidth = MediaQuery.sizeOf(context).width < kAdminShellDrawerBreakpoint ? 64.0 : 72.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

