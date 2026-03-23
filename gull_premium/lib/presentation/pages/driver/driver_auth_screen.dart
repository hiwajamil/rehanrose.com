import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import 'driver_application_screen.dart';

enum _DriverAuthMethod {
  phone,
  email,
}

class DriverAuthScreen extends StatefulWidget {
  const DriverAuthScreen({super.key});

  @override
  State<DriverAuthScreen> createState() => _DriverAuthScreenState();
}

class _DriverAuthScreenState extends State<DriverAuthScreen> {
  _DriverAuthMethod _method = _DriverAuthMethod.phone;

  // Email login
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _emailLoggingIn = false;

  // Phone login (password via linked email in Firestore)
  final _phoneController = TextEditingController();
  final _phonePasswordController = TextEditingController();
  bool _phoneLoggingIn = false;

  @override
  void initState() {
    super.initState();
    // If the user is already signed in (e.g. from the drawer CTA), route
    // them to the correct onboarding/dashboard screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _routeIfAlreadySignedIn());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _phonePasswordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.rosePrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _normalizePhoneForIraq(String rawInput) {
    final digitsOnly = rawInput.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return '';

    // Accept local formats like 0750..., 750..., or already prefixed 964...
    if (digitsOnly.startsWith('964')) return '+$digitsOnly';
    if (digitsOnly.startsWith('0')) return '+964${digitsOnly.substring(1)}';
    return '+964$digitsOnly';
  }

  Future<bool> _hasDriverFields(Map<String, dynamic> data) async {
    // "Driver fields" live under the same keys as DriverApplicationScreen.
    final fullName = data[DriverApplicationFields.fullName]?.toString().trim();
    final phone = data[DriverApplicationFields.phone]?.toString().trim();
    final vehicleModel =
        data[DriverApplicationFields.vehicleModel]?.toString().trim();
    final vehiclePlate =
        data[DriverApplicationFields.vehiclePlate]?.toString().trim();

    return (fullName != null && fullName.isNotEmpty) ||
        (phone != null && phone.isNotEmpty) ||
        (vehicleModel != null && vehicleModel.isNotEmpty) ||
        (vehiclePlate != null && vehiclePlate.isNotEmpty);
  }

  Future<void> _routeIfAlreadySignedIn() async {
    final user = fa.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _postLoginRouting();
  }

  Future<void> _postLoginRouting() async {
    final user = fa.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userDoc.data() ?? {};

    final role = data['role']?.toString().toLowerCase() ?? '';
    final applicationStatus =
        data['applicationStatus']?.toString().toLowerCase() ?? '';

    final hasDriverFields = await _hasDriverFields(data);

    // Align with app_router: approved drivers have role driver and approved/empty status.
    final isApprovedDriver = role == 'driver' &&
        (applicationStatus == 'approved' || applicationStatus.isEmpty);

    if (!mounted) return;

    if (applicationStatus == 'pending_driver') {
      context.go('/driver/waiting');
      return;
    }

    if (isApprovedDriver) {
      context.go('/driver');
      return;
    }

    if (!hasDriverFields) {
      context.go('/driver/application');
      return;
    }

    context.go('/driver/application');
  }

  Future<void> _signInWithEmail() async {
    if (_emailLoggingIn) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter your email and password.');
      return;
    }

    setState(() {
      _emailLoggingIn = true;
    });

    try {
      await fa.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _postLoginRouting();
    } on fa.FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Unable to sign in. Please try again.');
    } catch (_) {
      _showError('Unable to sign in. Please try again.');
    } finally {
      if (mounted) setState(() => _emailLoggingIn = false);
    }
  }

  Future<void> _signInWithPhonePassword() async {
    if (_phoneLoggingIn) return;

    final normalizedPhone = _normalizePhoneForIraq(_phoneController.text);
    if (normalizedPhone.length < 13) {
      _showError('Please enter a valid Iraqi phone number.');
      return;
    }

    final password = _phonePasswordController.text;
    if (password.isEmpty) {
      _showError('Please enter your password.');
      return;
    }

    setState(() {
      _phoneLoggingIn = true;
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: normalizedPhone)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        _showError(
          'No account found for this phone number. Apply as a driver first or sign in with email.',
        );
        return;
      }

      final doc = snap.docs.first.data();
      final email = doc['email']?.toString().trim() ?? '';
      if (email.isEmpty) {
        _showError(
          'This profile has no email on file. Please contact support or use email sign-in.',
        );
        return;
      }

      await fa.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _postLoginRouting();
    } on fa.FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Unable to sign in. Check your password.');
    } catch (_) {
      _showError('Unable to sign in. Please try again.');
    } finally {
      if (mounted) setState(() => _phoneLoggingIn = false);
    }
  }

  void _applyToBeDriver() {
    if (!mounted) return;
    context.push('/driver/application');
  }

  Widget _buildAuthMethodCard({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.rosePrimary.withValues(alpha: 0.14) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.rosePrimary : AppColors.border,
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? AppColors.rosePrimary : AppColors.inkMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkCharcoal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailSignIn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sign in with Email',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.inkCharcoal,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Enter your email and password to continue.',
          style: GoogleFonts.montserrat(
            color: AppColors.inkMuted,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          style: GoogleFonts.montserrat(color: AppColors.ink),
          decoration: InputDecoration(
            labelText: 'Email',
            labelStyle: GoogleFonts.montserrat(
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.rosePrimary, width: 1.4),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: GoogleFonts.montserrat(color: AppColors.ink),
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: GoogleFonts.montserrat(
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.rosePrimary, width: 1.4),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _emailLoggingIn ? null : _signInWithEmail,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rosePrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _emailLoggingIn
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    'Login',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneSignIn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sign in with Phone',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.inkCharcoal,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Enter your Iraqi number and password. We match your phone to your account email.',
          style: GoogleFonts.montserrat(
            color: AppColors.inkMuted,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: GoogleFonts.montserrat(color: AppColors.ink),
          decoration: InputDecoration(
            prefixText: '+964 ',
            prefixStyle: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.inkCharcoal,
            ),
            labelText: 'Phone Number',
            labelStyle: GoogleFonts.montserrat(
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.rosePrimary, width: 1.4),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phonePasswordController,
          obscureText: true,
          style: GoogleFonts.montserrat(color: AppColors.ink),
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: GoogleFonts.montserrat(
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.rosePrimary, width: 1.4),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _phoneLoggingIn ? null : _signInWithPhonePassword,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rosePrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _phoneLoggingIn
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    'Login',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.rosePrimary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.rosePrimary.withValues(alpha: 0.45)),
                ),
                child: Icon(Icons.local_shipping_rounded, color: AppColors.rosePrimary, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Rehan Rose',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w900,
                  color: AppColors.inkCharcoal,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          bottom: TabBar(
            indicatorColor: AppColors.rosePrimary,
            labelColor: AppColors.inkCharcoal,
            unselectedLabelColor: AppColors.inkMuted,
            tabs: [
              Tab(
                child: Text(
                  'Sign In',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w900),
                ),
              ),
              Tab(
                child: Text(
                  'Create Account',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Sign In tab
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          runSpacing: 12,
                          spacing: 12,
                          children: [
                            SizedBox(
                              width: 260,
                              child: _buildAuthMethodCard(
                                title: 'Sign in with Phone',
                                icon: Icons.phone_android_rounded,
                                selected: _method == _DriverAuthMethod.phone,
                                onTap: () => setState(() => _method = _DriverAuthMethod.phone),
                              ),
                            ),
                            SizedBox(
                              width: 260,
                              child: _buildAuthMethodCard(
                                title: 'Sign in with Email',
                                icon: Icons.email_outlined,
                                selected: _method == _DriverAuthMethod.email,
                                onTap: () => setState(() => _method = _DriverAuthMethod.email),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _method == _DriverAuthMethod.phone
                              ? _buildPhoneSignIn()
                              : _buildEmailSignIn(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Create Account tab — driver onboarding only (no customer registration)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Join our elite delivery fleet.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.inkCharcoal,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed: _applyToBeDriver,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.forestGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Apply to be a Driver',
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

