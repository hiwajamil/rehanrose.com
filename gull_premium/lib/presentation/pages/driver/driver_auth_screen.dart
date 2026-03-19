import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import 'driver_application_screen.dart';
import 'driver_dashboard_screen.dart';
import 'waiting_for_driver_approval_screen.dart';

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

  // Phone login
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _sendingCode = false;
  bool _verifyingCode = false;
  bool _otpSent = false;
  String? _verificationId;
  int? _resendToken;
  String? _statusMessage;

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
    _otpController.dispose();
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
    final applicationStatus = data['applicationStatus']?.toString().toLowerCase() ?? '';

    final hasDriverFields = await _hasDriverFields(data);

    if (!mounted) return;

    if (role == 'driver') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const DriverDashboardScreen(),
        ),
      );
      return;
    }

    if (applicationStatus == 'pending_driver') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const WaitingForDriverApprovalScreen(),
        ),
      );
      return;
    }

    if (!hasDriverFields) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const DriverApplicationScreen(),
        ),
      );
      return;
    }

    // Fallback: if they already have some driver data but are not a
    // dashboard-approved driver, guide them to complete/repair the form.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const DriverApplicationScreen(),
      ),
    );
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
      _statusMessage = null;
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

  Future<void> _sendCode() async {
    if (_sendingCode) return;

    final normalizedPhone = _normalizePhoneForIraq(_phoneController.text);
    if (normalizedPhone.length < 13) {
      _showError('Please enter a valid Iraqi phone number.');
      return;
    }

    setState(() {
      _sendingCode = true;
      _statusMessage = null;
    });

    // Reminder: enable "Phone" sign-in provider in Firebase Console -> Authentication -> Sign-in method.
    await fa.FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: normalizedPhone,
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,
      verificationCompleted: (credential) async {
        try {
          await fa.FirebaseAuth.instance.signInWithCredential(credential);
          await _postLoginRouting();
        } catch (_) {
          _showError('Auto verification failed. Please enter the OTP manually.');
        }
      },
      verificationFailed: (exception) {
        if (!mounted) return;
        setState(() {
          _sendingCode = false;
          _statusMessage = null;
        });
        _showError(exception.message ?? 'Failed to send OTP. Please try again.');
      },
      codeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() {
          _sendingCode = false;
          _otpSent = true;
          _verificationId = verificationId;
          _resendToken = resendToken;
          _statusMessage = 'A 6-digit code was sent to $normalizedPhone';
        });
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
        });
      },
    );
  }

  Future<void> _verifyOtpAndContinue() async {
    if (_verifyingCode) return;

    final verificationId = _verificationId;
    final code = _otpController.text.trim();

    if (verificationId == null || verificationId.isEmpty) {
      _showError('Verification session expired. Please request a new code.');
      return;
    }

    if (code.length != 6) {
      _showError('Please enter the 6-digit OTP.');
      return;
    }

    setState(() => _verifyingCode = true);
    try {
      final credential = fa.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
      await fa.FirebaseAuth.instance.signInWithCredential(credential);
      await _postLoginRouting();
    } on fa.FirebaseAuthException catch (e) {
      _showError(e.message ?? 'OTP verification failed.');
    } finally {
      if (mounted) setState(() => _verifyingCode = false);
    }
  }

  Future<void> _applyToBeDriver() async {
    final user = fa.FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Prompt the user to sign up first (email or phone). Registration will
      // pop back to this screen on success.
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Sign up required',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                color: AppColors.inkCharcoal,
              ),
            ),
            content: Text(
              'To apply, create your account first.',
              style: GoogleFonts.montserrat(
                color: AppColors.inkMuted,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.push('/register');
                },
                child: Text(
                  'Sign up with Email',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    color: AppColors.rosePrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.push('/register');
                },
                child: Text(
                  'Sign up with Phone',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    color: AppColors.rosePrimary,
                  ),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    // Authenticated: if they are not a driver yet, route to the application form.
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userDoc.data() ?? {};

    final role = data['role']?.toString().toLowerCase() ?? '';

    if (!mounted) return;
    if (role.isEmpty || role != 'driver') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const DriverApplicationScreen(),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const DriverDashboardScreen(),
      ),
    );
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
          _otpSent ? 'Verify your phone' : 'Sign in with Phone',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.inkCharcoal,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _otpSent
              ? 'Enter the OTP sent to your number to continue.'
              : 'Use your Iraqi phone number to continue to driver onboarding.',
          style: GoogleFonts.montserrat(
            color: AppColors.inkMuted,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        if (!_otpSent) ...[
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
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _sendingCode ? null : _sendCode,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.rosePrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _sendingCode
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Send Code',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ] else ...[
          Text(
            'One-Time Password',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: AppColors.rosePrimary,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 20,
              letterSpacing: 8,
              fontWeight: FontWeight.w900,
              color: AppColors.inkCharcoal,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '------',
              hintStyle: GoogleFonts.montserrat(
                letterSpacing: 6,
                color: AppColors.inkMuted.withValues(alpha: 0.6),
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
          const SizedBox(height: 8),
          TextButton(
            onPressed: _sendingCode ? null : _sendCode,
            child: Text(
              'Resend code',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                color: AppColors.rosePrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _verifyingCode ? null : _verifyOtpAndContinue,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _verifyingCode
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Verify',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
        if (_statusMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _statusMessage!,
            style: GoogleFonts.montserrat(
              color: AppColors.inkMuted,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
            // Create Account tab
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.rosePrimary.withValues(alpha: 0.12),
                                AppColors.accentGold.withValues(alpha: 0.1),
                                AppColors.creamBackground,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.rosePrimary.withValues(alpha: 0.25)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.rosePrimary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.local_shipping_outlined,
                                      color: AppColors.rosePrimary,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      'Join our elite delivery fleet.',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.inkCharcoal,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Apply to become a Driver and start your onboarding.',
                                style: GoogleFonts.montserrat(
                                  color: AppColors.inkMuted,
                                  height: 1.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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

