import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

class DriverPhoneAuthScreen extends StatefulWidget {
  const DriverPhoneAuthScreen({super.key});

  @override
  State<DriverPhoneAuthScreen> createState() => _DriverPhoneAuthScreenState();
}

class _DriverPhoneAuthScreenState extends State<DriverPhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _sendingCode = false;
  bool _verifyingCode = false;
  bool _otpSent = false;
  String? _verificationId;
  int? _resendToken;
  String? _statusMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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
          await _routeAfterAuth();
        } catch (e) {
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
      await _routeAfterAuth();
    } on fa.FirebaseAuthException catch (e) {
      _showError(e.message ?? 'OTP verification failed.');
    } finally {
      if (mounted) {
        setState(() => _verifyingCode = false);
      }
    }
  }

  Future<void> _routeAfterAuth() async {
    final user = fa.FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userDoc.data();
    final role = data?['role']?.toString().toLowerCase() ?? '';
    final applicationStatus =
        data?['applicationStatus']?.toString().toLowerCase() ?? '';

    if (!mounted) return;
    if (role == 'driver') {
      context.go('/driver');
      return;
    }
    if (applicationStatus == 'pending_driver') {
      context.go('/driver/waiting');
      return;
    }
    context.go('/driver/application');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.headerBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.inkCharcoal),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Driver Phone Login',
          style: GoogleFonts.montserrat(
            color: AppColors.inkCharcoal,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _otpSent ? 'Verify your phone' : 'Join as a driver',
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.inkCharcoal,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _otpSent
                        ? 'Enter the OTP sent to your number to continue.'
                        : 'Use your Iraqi phone number to continue to driver onboarding.',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 26),
                  if (!_otpSent) ...[
                    Text(
                      'Phone Number',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: AppColors.rosePrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        color: AppColors.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: '750 123 4567',
                        hintStyle: GoogleFonts.montserrat(
                          fontSize: 14,
                          color: AppColors.inkMuted.withValues(alpha: 0.7),
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsetsDirectional.only(start: 12, end: 10),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              '+964',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkCharcoal,
                              ),
                            ),
                          ),
                        ),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 64, minHeight: 24),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.rosePrimary,
                            width: 1.4,
                          ),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _sendingCode
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Send Code',
                                style: GoogleFonts.montserrat(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'One-Time Password',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: AppColors.rosePrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkCharcoal,
                      ),
                      decoration: InputDecoration(
                        hintText: '------',
                        counterText: '',
                        hintStyle: GoogleFonts.montserrat(
                          letterSpacing: 6,
                          color: AppColors.inkMuted.withValues(alpha: 0.6),
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.rosePrimary,
                            width: 1.4,
                          ),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _sendingCode ? null : _sendCode,
                      child: Text(
                        'Resend code',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w600,
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _verifyingCode
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Verify',
                                style: GoogleFonts.montserrat(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _statusMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
