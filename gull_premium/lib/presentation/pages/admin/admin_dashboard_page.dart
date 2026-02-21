import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';

import '../../../core/constants/breakpoints.dart';
import '../../../data/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../controllers/controllers.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';

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
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Enter your admin email and password.');
      return;
    }
    setState(() => _isSigningIn = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      try {
        await authRepo.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on fa.FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' &&
            email.toLowerCase() == kSuperAdminEmail.toLowerCase()) {
          await authRepo.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } else {
          rethrow;
        }
      }
      final user = authRepo.currentUser;
      if (user != null &&
          user.email?.trim().toLowerCase() == kSuperAdminEmail.toLowerCase()) {
        await authRepo.ensureSuperAdminUserDoc(user.uid);
      }
    } on fa.FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Unable to sign in.');
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
    return AppScaffold(
      child: SectionContainer(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width <= kMobileBreakpoint ? 16 : 48,
          vertical: MediaQuery.sizeOf(context).width <= kMobileBreakpoint ? 24 : 56,
        ),
        child: authAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _buildAdminSignIn(context),
          data: (user) {
            if (user == null) return _buildAdminSignIn(context);
            final isAdminAsync = ref.watch(isAdminForUidProvider(user.uid));
            return isAdminAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _buildAdminSignIn(context),
              data: (isAdmin) {
                if (!isAdmin) return _buildNotAuthorized(context, user);
                return _buildAdminDashboard(context, user.uid);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildAdminSignIn(BuildContext context) {
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
            'Super Admin Dashboard',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to review vendor applications. If you see "Access restricted", add your UID to the admins collection in Firestore (instructions shown there).',
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: 20),
          _AdminField(
            label: 'Admin email',
            controller: _emailController,
            hintText: 'admin@email.com',
            icon: Icons.mail_outline,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _AdminField(
            label: 'Password',
            controller: _passwordController,
            hintText: 'Enter your password',
            icon: Icons.lock_outline,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: _isSigningIn ? null : _signIn,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: _isSigningIn ? 'Signing in...' : 'Sign in',
            onPressed: _isSigningIn ? () {} : _signIn,
          ),
        ],
      ),
    );
  }

  Widget _buildNotAuthorized(BuildContext context, fa.User user) {
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
            'Access restricted',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'This account is not registered as a super admin. To grant access, add a document in Firestore:',
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: 12),
          SelectableText(
            'Collection: admins\nDocument ID: ${user.uid}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: AppColors.inkMuted,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'You can create an empty document in Firebase Console (Firestore → admins → Add document with the ID above). Then sign out and sign in again.',
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Sign out',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            variant: PrimaryButtonVariant.outline,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminDashboard(BuildContext context, String adminId) {
    final applicationsAsync = ref.watch(pendingVendorApplicationsStreamProvider);
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            Text(
              'Pending vendor applications',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PrimaryButton(
                  label: 'Analytics',
                  onPressed: () => context.go('/admin/analytics'),
                  variant: PrimaryButtonVariant.outline,
                ),
                PrimaryButton(
                  label: 'Bouquet Approval',
                  onPressed: () => context.go('/admin/approvals'),
                  variant: PrimaryButtonVariant.outline,
                ),
                PrimaryButton(
                  label: 'Manage Add-ons',
                  onPressed: () => context.push('/admin/add-ons'),
                  variant: PrimaryButtonVariant.outline,
                ),
                PrimaryButton(
                  label: 'Sign out',
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  variant: PrimaryButtonVariant.outline,
                ),
              ],
            ),
          ] else
            Row(
              children: [
                Text(
                  'Pending vendor applications',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'Analytics',
                  onPressed: () => context.go('/admin/analytics'),
                  variant: PrimaryButtonVariant.outline,
                ),
                const SizedBox(width: 12),
                PrimaryButton(
                  label: 'Bouquet Approval',
                  onPressed: () => context.go('/admin/approvals'),
                  variant: PrimaryButtonVariant.outline,
                ),
                const SizedBox(width: 12),
                PrimaryButton(
                  label: 'Manage Add-ons',
                  onPressed: () => context.push('/admin/add-ons'),
                  variant: PrimaryButtonVariant.outline,
                ),
                const SizedBox(width: 12),
                PrimaryButton(
                  label: 'Sign out',
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  variant: PrimaryButtonVariant.outline,
                ),
              ],
            ),
          const SizedBox(height: 20),
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
                  'Loading applications…',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          error: (_, __) => Text(
            'Unable to load applications.',
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
                  'No pending applications.',
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
                final isMobileCard = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(isMobileCard ? 16 : 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['studioName']?.toString() ?? 'Studio',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      _DetailRow(
                        label: 'Owner',
                        value: data['ownerName']?.toString() ?? '--',
                      ),
                      _DetailRow(
                        label: 'Email',
                        value: data['email']?.toString() ?? '--',
                      ),
                      _DetailRow(
                        label: 'Phone',
                        value: data['phone']?.toString() ?? '--',
                      ),
                      _DetailRow(
                        label: 'Location',
                        value: data['location']?.toString() ?? '--',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: isProcessing ? 'Working...' : 'Approve',
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
                                            _showMessage('Application approved.');
                                          }
                                        } catch (_) {
                                          if (mounted) {
                                            _showMessage('Unable to approve application.');
                                          }
                                        } finally {
                                          if (mounted) {
                                            setState(() =>
                                                _processingApplications.remove(doc.id));
                                          }
                                        }
                                      },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PrimaryButton(
                              label: isProcessing ? 'Working...' : 'Reject',
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
                                            _showMessage('Application rejected.');
                                          }
                                        } catch (_) {
                                          if (mounted) {
                                            _showMessage('Unable to reject application.');
                                          }
                                        } finally {
                                          if (mounted) {
                                            setState(() =>
                                                _processingApplications.remove(doc.id));
                                          }
                                        }
                                      },
                              variant: PrimaryButtonVariant.outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
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
