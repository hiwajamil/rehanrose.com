import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final Set<String> _processingApplications = {};
  bool _isSigningIn = false;
  bool? _cachedIsAdmin;
  String? _cachedAdminUserId;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showMessage('Enter your admin email and password.');
      return;
    }

    setState(() => _isSigningIn = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (error) {
      _showMessage(error.message ?? 'Unable to sign in.');
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  Future<bool> _isAdmin(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('admins')
        .doc(user.uid)
        .get();
    return doc.exists;
  }

  Future<void> _approveApplication(
    String applicationId,
    Map<String, dynamic> data,
    String adminId,
  ) async {
    setState(() => _processingApplications.add(applicationId));
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('vendor_applications').doc(applicationId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': adminId,
      });
      await firestore.collection('users').doc(applicationId).set({
        'vendorStatus': 'approved',
      }, SetOptions(merge: true));
      await firestore.collection('vendors').doc(applicationId).set({
        'studioName': data['studioName'],
        'ownerName': data['ownerName'],
        'email': data['email'],
        'phone': data['phone'],
        'location': data['location'],
        'approvedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _showMessage('Application approved.');
    } catch (_) {
      _showMessage('Unable to approve application.');
    } finally {
      if (mounted) {
        setState(() => _processingApplications.remove(applicationId));
      }
    }
  }

  Future<void> _rejectApplication(String applicationId, String adminId) async {
    setState(() => _processingApplications.add(applicationId));
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('vendor_applications').doc(applicationId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': adminId,
      });
      await firestore.collection('users').doc(applicationId).set({
        'vendorStatus': 'rejected',
      }, SetOptions(merge: true));
      _showMessage('Application rejected.');
    } catch (_) {
      _showMessage('Unable to reject application.');
    } finally {
      if (mounted) {
        setState(() => _processingApplications.remove(applicationId));
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: SectionContainer(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            final user = snapshot.data;
            if (user == null) {
              return _buildAdminSignIn(context);
            }

            if (_cachedAdminUserId == user.uid && _cachedIsAdmin != null) {
              if (_cachedIsAdmin!) {
                return _buildAdminDashboard(context, user.uid);
              }
              return _buildNotAuthorized(context);
            }
            return FutureBuilder<bool>(
              future: _isAdmin(user),
              builder: (context, adminSnapshot) {
                if (adminSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final isAdmin = adminSnapshot.data ?? false;
                if (adminSnapshot.hasData) {
                  _cachedIsAdmin = isAdmin;
                  _cachedAdminUserId = user.uid;
                }
                if (!isAdmin) {
                  return _buildNotAuthorized(context);
                }
                return _buildAdminDashboard(context, user.uid);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildAdminSignIn(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
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
            'Sign in to review vendor applications.',
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

  Widget _buildNotAuthorized(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Access restricted',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'This account is not registered as a super admin.',
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
            variant: PrimaryButtonVariant.outline,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminDashboard(BuildContext context, String adminId) {
    final applicationsStream = FirebaseFirestore.instance
        .collection('vendor_applications')
        .where('status', isEqualTo: 'pending')
        .snapshots();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Pending vendor applications',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Sign out',
              onPressed: () => FirebaseAuth.instance.signOut(),
              variant: PrimaryButtonVariant.outline,
            ),
          ],
        ),
        const SizedBox(height: 20),
        StreamBuilder<QuerySnapshot>(
          stream: applicationsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Text(
                'No pending applications.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.inkMuted),
              );
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final isProcessing = _processingApplications.contains(doc.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
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
                                  : () => _approveApplication(
                                        doc.id,
                                        data,
                                        adminId,
                                      ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PrimaryButton(
                              label: isProcessing ? 'Working...' : 'Reject',
                              onPressed: isProcessing
                                  ? () {}
                                  : () => _rejectApplication(doc.id, adminId),
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
