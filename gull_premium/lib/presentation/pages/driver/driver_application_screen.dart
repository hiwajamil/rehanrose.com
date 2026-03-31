import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/layout/app_scaffold.dart';

/// Firestore keys for driver application (read by admin approval UI).
abstract class DriverApplicationFields {
  static const fullName = 'driverFullName';
  static const phone = 'driverPhone';
  static const vehicleModel = 'driverVehicleModel';
  static const vehiclePlate = 'driverVehiclePlate';
}

/// Elegant driver application form — Rehan Rose branding, Montserrat.
class DriverApplicationScreen extends ConsumerStatefulWidget {
  const DriverApplicationScreen({super.key});

  @override
  ConsumerState<DriverApplicationScreen> createState() =>
      _DriverApplicationScreenState();
}

class _DriverApplicationScreenState extends ConsumerState<DriverApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _plateController = TextEditingController();
  final _accountEmailController = TextEditingController();
  final _accountPasswordController = TextEditingController();
  final _accountPasswordConfirmController = TextEditingController();

  bool _loadingProfile = true;
  bool _guestMode = false;
  bool _submitting = false;
  bool _justSubmitted = false;
  String? _loadError;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleController.dispose();
    _plateController.dispose();
    _accountEmailController.dispose();
    _accountPasswordController.dispose();
    _accountPasswordConfirmController.dispose();
    super.dispose();
  }

  String _normalizePhoneForIraq(String rawInput) {
    final digitsOnly = rawInput.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return '';

    if (digitsOnly.startsWith('964')) return '+$digitsOnly';
    if (digitsOnly.startsWith('0')) return '+964${digitsOnly.substring(1)}';
    return '+964$digitsOnly';
  }

  Future<void> _loadUserAndPrefill() async {
    final user = fa.FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loadingProfile = false;
        _guestMode = true;
      });
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final d = doc.data() ?? {};
      final role = d['role']?.toString() ?? '';
      final status = d['applicationStatus']?.toString() ?? '';

      if (!mounted) return;
      if (role == 'driver' &&
          (status == 'approved' || status.isEmpty)) {
        context.go('/driver');
        return;
      }
      if (status == 'pending_driver') {
        setState(() {
          _loadingProfile = false;
          _justSubmitted = true;
          _nameController.text =
              d[DriverApplicationFields.fullName]?.toString() ?? '';
          _phoneController.text =
              d[DriverApplicationFields.phone]?.toString() ?? '';
          _vehicleController.text =
              d[DriverApplicationFields.vehicleModel]?.toString() ?? '';
          _plateController.text =
              d[DriverApplicationFields.vehiclePlate]?.toString() ?? '';
        });
        return;
      }

      final display = d['displayName']?.toString() ?? '';
      final full = d['fullName']?.toString() ?? '';
      final phone = d['phoneNumber']?.toString() ?? '';
      final email = d['email']?.toString() ?? user.email ?? '';

      setState(() {
        _loadingProfile = false;
        _nameController.text = full.isNotEmpty
            ? full
            : (user.displayName ?? display);
        _phoneController.text = phone;
        _accountEmailController.text = email;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingProfile = false;
          _loadError = 'Could not load your profile. Try again.';
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserAndPrefill());
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_guestMode &&
        _accountPasswordController.text !=
            _accountPasswordConfirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Passwords do not match.',
            style: GoogleFonts.montserrat(),
          ),
          backgroundColor: AppColors.rosePrimary,
        ),
      );
      return;
    }

    final user = fa.FirebaseAuth.instance.currentUser;
    if (user == null && !_guestMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please sign in to apply.',
            style: GoogleFonts.montserrat(),
          ),
          backgroundColor: AppColors.rosePrimary,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      fa.User? effectiveUser = user;
      if (_guestMode) {
        final cred = await fa.FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _accountEmailController.text.trim(),
          password: _accountPasswordController.text,
        );
        effectiveUser = cred.user;
      }
      if (effectiveUser == null) {
        if (mounted) setState(() => _submitting = false);
        return;
      }

      final normalizedPhone = _normalizePhoneForIraq(_phoneController.text);
      final emailForDoc =
          _guestMode ? _accountEmailController.text.trim() : (effectiveUser.email ?? '');

      await FirebaseFirestore.instance.collection('users').doc(effectiveUser.uid).set(
        {
          'fullName': _nameController.text.trim(),
          'email': emailForDoc,
          'phoneNumber': normalizedPhone,
          DriverApplicationFields.fullName: _nameController.text.trim(),
          DriverApplicationFields.phone: _phoneController.text.trim(),
          DriverApplicationFields.vehicleModel: _vehicleController.text.trim(),
          DriverApplicationFields.vehiclePlate: _plateController.text.trim(),
          'applicationStatus': 'pending_driver',
          'driverAppliedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (mounted) {
        setState(() {
          _submitting = false;
          _justSubmitted = true;
        });
      }
    } on fa.FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message ?? 'Could not create account. Try again.',
              style: GoogleFonts.montserrat(fontSize: 14),
            ),
            backgroundColor: AppColors.rosePrimary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not submit application. Check connection and try again.',
              style: GoogleFonts.montserrat(fontSize: 14),
            ),
            backgroundColor: AppColors.rosePrimary,
          ),
        );
      }
    }
  }

  InputDecoration _decoration(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.montserrat(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.inkMuted,
      ),
      hintStyle: GoogleFonts.montserrat(
        fontSize: 14,
        color: AppColors.inkMuted.withValues(alpha: 0.7),
      ),
      prefixIcon: icon != null
          ? Icon(icon, color: AppColors.rosePrimary, size: 22)
          : null,
      filled: true,
      fillColor: AppColors.surface,
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
        borderSide: const BorderSide(color: AppColors.rosePrimary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loadingProfile) {
      return AppScaffold(
        title: l10n.driveWithRehanRose,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.rosePrimary),
        ),
      );
    }

    if (_loadError != null) {
      return AppScaffold(
        title: l10n.driveWithRehanRose,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_loadError!, style: GoogleFonts.montserrat()),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rosePrimary,
                ),
                child: const Text('Home'),
              ),
            ],
          ),
        ),
      );
    }

    if (_justSubmitted) {
      return AppScaffold(
        title: 'Rehan Rose',
        child: _PendingApprovalBody(
          name: _nameController.text.trim(),
          onGoHome: () => context.go('/'),
        ),
      );
    }

    return AppScaffold(
      title: l10n.driveWithRehanRose,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.rosePrimary.withValues(alpha: 0.12),
                          AppColors.sage.withValues(alpha: 0.1),
                          AppColors.creamBackground,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.rosePrimary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.rosePrimary.withValues(
                                    alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.local_shipping_outlined,
                                color: AppColors.rosePrimary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Join our delivery fleet',
                                style: GoogleFonts.montserrat(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.inkCharcoal,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Complete the form below. After admin approval you’ll access the live driver dashboard.',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.inkMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_guestMode) ...[
                    Text(
                      'Account',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppColors.rosePrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _accountEmailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        color: AppColors.ink,
                      ),
                      decoration: _decoration(
                        'Email',
                        hint: 'you@example.com',
                        icon: Icons.email_outlined,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter your email';
                        }
                        if (!v.contains('@')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _accountPasswordController,
                      obscureText: true,
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        color: AppColors.ink,
                      ),
                      decoration: _decoration(
                        'Password',
                        hint: 'At least 6 characters',
                        icon: Icons.lock_outline_rounded,
                      ),
                      validator: (v) {
                        if (v == null || v.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _accountPasswordConfirmController,
                      obscureText: true,
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        color: AppColors.ink,
                      ),
                      decoration: _decoration(
                        'Confirm password',
                        hint: 'Repeat password',
                        icon: Icons.lock_outline_rounded,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Confirm your password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                  ],
                  Text(
                    'Application details',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.rosePrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      color: AppColors.ink,
                    ),
                    decoration: _decoration(
                      'Full name',
                      hint: 'As on your ID',
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 2) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      color: AppColors.ink,
                    ),
                    decoration: _decoration(
                      'Phone number',
                      hint: 'e.g. 0750 123 4567',
                      icon: Icons.phone_outlined,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 8) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _vehicleController,
                    textCapitalization: TextCapitalization.words,
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      color: AppColors.ink,
                    ),
                    decoration: _decoration(
                      'Vehicle type / model',
                      hint: 'e.g. Toyota Corolla',
                      icon: Icons.directions_car_outlined,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 2) {
                        return 'Please describe your vehicle';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _plateController,
                    textCapitalization: TextCapitalization.characters,
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      color: AppColors.ink,
                    ),
                    decoration: _decoration(
                      'Vehicle plate number',
                      hint: 'Registration plate',
                      icon: Icons.pin_outlined,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter plate number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forestGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.forestGreen.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Submit application',
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'By submitting, you confirm the information is accurate. '
                    'We’ll email or call you if we need anything else.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: AppColors.inkMuted,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingApprovalBody extends StatelessWidget {
  const _PendingApprovalBody({
    required this.name,
    required this.onGoHome,
  });

  final String name;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accentGold.withValues(alpha: 0.45),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.hourglass_top_rounded,
                  size: 44,
                  color: const Color(0xFFB8963D),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Application received',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkCharcoal,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name.isNotEmpty
                    ? 'Thank you, $name.'
                    : 'Thank you.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your driver application is pending admin approval. '
                'You cannot access the live dashboard until you are approved. '
                'We’ll notify you when your fleet access is ready.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  height: 1.6,
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 36),
              OutlinedButton(
                onPressed: onGoHome,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.rosePrimary,
                  side: BorderSide(
                    color: AppColors.rosePrimary.withValues(alpha: 0.7),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Back to home',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
