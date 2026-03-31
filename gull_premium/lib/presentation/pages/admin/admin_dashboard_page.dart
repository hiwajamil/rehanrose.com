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
    final onlineVendorsAsync = ref.watch(onlineVendorsStreamProvider);
    final isMobile = MediaQuery.sizeOf(context).width < kAdminShellDrawerBreakpoint;
    final verticalSpacing = isMobile ? 16.0 : 20.0;
    final sectionSpacing = isMobile ? 24.0 : 40.0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
        Text(
          l10n.adminPendingApplications,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
        ),
        SizedBox(height: verticalSpacing),
        applicationsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
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
          error: (_, __) => Text(
            l10n.adminUnableToLoadApplications,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.inkMuted),
          ),
          data: (snapshot) {
            final docs = snapshot.docs;
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  l10n.adminNoPendingApplications,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.inkMuted),
                ),
              );
            }
            return Column(
              children: docs.map((doc) {
                final data = doc.data();
                final isProcessing = _processingApplications.contains(doc.id);
                final isMobileCard = MediaQuery.sizeOf(context).width < kAdminShellDrawerBreakpoint;
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(isMobileCard ? 16 : 20),
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
                                      setState(() =>
                                          _processingApplications.add(doc.id));
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
                                          setState(() =>
                                              _processingApplications.remove(doc.id));
                                        }
                                      }
                                    },
                          );
                          final rejectBtn = PrimaryButton(
                            label: isProcessing ? l10n.adminWorking : l10n.adminReject,
                            onPressed: isProcessing
                                ? () {}
                                : () async {
                                      setState(() =>
                                          _processingApplications.add(doc.id));
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
                                          setState(() =>
                                              _processingApplications.remove(doc.id));
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
              }).toList(),
            );
          },
        ),
        SizedBox(height: sectionSpacing),
        _buildOnlineVendorsCard(context, l10n, onlineVendorsAsync),
        ],
      ),
    );
  }

  Widget _buildOnlineVendorsCard(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<QuerySnapshot<Map<String, dynamic>>> onlineVendorsAsync,
  ) {
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                l10n.adminOnlineVendors,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
              ),
              onlineVendorsAsync.when(
                loading: () => Text(
                  l10n.adminLoadingOnlineVendors,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                        fontStyle: FontStyle.italic,
                      ),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (snapshot) {
                  final count = snapshot.docs.length;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      l10n.adminOnlineVendorsCount(count),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF059669),
                          ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          onlineVendorsAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
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
                    l10n.adminLoadingOnlineVendors,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
            error: (_, __) => Text(
              l10n.adminNoOnlineVendors,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.inkMuted),
            ),
            data: (snapshot) {
              final docs = snapshot.docs;
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    l10n.adminNoOnlineVendors,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.inkMuted),
                  ),
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final shopName = data['shopName']?.toString().trim();
                    final displayName = data['displayName']?.toString().trim();
                    final email = data['email']?.toString().trim() ?? '';
                    final label = (shopName != null && shopName.isNotEmpty)
                        ? shopName
                        : (displayName != null && displayName.isNotEmpty)
                            ? displayName
                            : email.isNotEmpty
                                ? email
                                : 'Vendor';
                    return _OnlineVendorTile(label: label);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OnlineVendorTile extends StatelessWidget {
  const _OnlineVendorTile({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF22C55E),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w500,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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

