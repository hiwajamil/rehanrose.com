import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// Same region as [gull_premium/functions/index.js] callable exports.
const String _functionsRegion = 'europe-west1';

/// Modal content: phone OTP then new password, for driver accounts that sign in
/// with phone + password (email is synthetic in Firebase Auth).
Future<void> showDriverResetPasswordSheet(BuildContext context) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: _DriverResetPasswordBody(
          onSuccess: () {
            Navigator.of(sheetContext).pop();
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Password updated. Sign in with your phone number and new password.',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                ),
                backgroundColor: AppColors.forestGreen,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      );
    },
  );
}

class _DriverResetPasswordBody extends StatefulWidget {
  const _DriverResetPasswordBody({required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  State<_DriverResetPasswordBody> createState() => _DriverResetPasswordBodyState();
}

class _DriverResetPasswordBodyState extends State<_DriverResetPasswordBody> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _sendingCode = false;
  bool _confirming = false;
  bool _otpStep = false;
  String? _verificationId;
  int? _resendToken;
  String? _statusMessage;
  fa.PhoneAuthCredential? _autoCredential;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
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
      _autoCredential = null;
      _otpController.clear();
      if (_otpStep) {
        _verificationId = null;
      }
    });

    await fa.FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: normalizedPhone,
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,
      verificationCompleted: (credential) {
        if (!mounted) return;
        setState(() {
          _sendingCode = false;
          _otpStep = true;
          _autoCredential = credential;
          _statusMessage = 'Phone verified. Enter a new password below.';
        });
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
          _otpStep = true;
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

  Future<void> _resetViaCallable(String newPassword) async {
    final functions = FirebaseFunctions.instanceFor(region: _functionsRegion);
    final callable = functions.httpsCallable('resetDriverPasswordWithPhoneOtp');
    await callable.call<Map<String, dynamic>>({'newPassword': newPassword});
  }

  Future<void> _applyNewPassword(String newPassword) async {
    try {
      final user = fa.FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw StateError('Not signed in');
      }

      final hasPasswordProvider =
          user.providerData.any((p) => p.providerId == 'password');

      try {
        if (hasPasswordProvider) {
          await user.updatePassword(newPassword);
        } else {
          await _resetViaCallable(newPassword);
        }
      } on fa.FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          await _resetViaCallable(newPassword);
        } else {
          rethrow;
        }
      }
    } finally {
      if (fa.FirebaseAuth.instance.currentUser != null) {
        await fa.FirebaseAuth.instance.signOut();
      }
    }
  }

  Future<void> _confirm() async {
    if (_confirming) return;

    final newPassword = _newPasswordController.text;
    if (newPassword.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }

    fa.AuthCredential credential;
    if (_autoCredential != null) {
      credential = _autoCredential!;
    } else {
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
      credential = fa.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
    }

    setState(() => _confirming = true);
    try {
      await fa.FirebaseAuth.instance.signInWithCredential(credential);
      await _applyNewPassword(newPassword);
      if (!mounted) return;
      widget.onSuccess();
    } on fa.FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Could not reset password. Try again.');
    } on FirebaseFunctionsException catch (e) {
      _showError(e.message ?? 'Could not reset password. Try again.');
    } on StateError {
      _showError('Session lost. Request a new code and try again.');
    } catch (_) {
      _showError('Could not reset password. Try again.');
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Reset password',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.inkCharcoal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We will text a code to your number. Then choose a new password for driver sign-in.',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              height: 1.5,
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 22),
          if (!_otpStep) ...[
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
                fillColor: AppColors.background,
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
                        style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ] else ...[
            if (_autoCredential == null) ...[
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
                  labelText: 'OTP Code',
                  counterText: '',
                  labelStyle: GoogleFonts.montserrat(
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
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
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _sendingCode ? null : _sendCode,
                  child: Text(
                    'Resend code',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      color: AppColors.rosePrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              style: GoogleFonts.montserrat(color: AppColors.ink),
              decoration: InputDecoration(
                labelText: 'New Password',
                labelStyle: GoogleFonts.montserrat(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: AppColors.background,
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
                onPressed: _confirming ? null : _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _confirming
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Confirm',
                        style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
          if (_statusMessage != null) ...[
            const SizedBox(height: 14),
            Text(
              _statusMessage!,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: AppColors.inkMuted,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
