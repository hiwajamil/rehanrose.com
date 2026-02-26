import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../controllers/controllers.dart';
import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/auth_error_utils.dart';
import '../../../firebase_options.dart';
import '../../../l10n/app_localizations.dart';

/// City options for the registration form.
const List<String> kRegistrationCities = [
  'Sulaimaniyah',
  'Erbil',
  'Duhok',
  'Zakho',
  'Baghdad',
  'Kirkuk',
  'Karbala',
  'Najaf',
  'Basrah',
  'Other',
];

// Premium input styling: soft fill, no heavy outline, rounded corners.
final _inputBorderRadius = BorderRadius.circular(12);
const _inputFillColor = Color(0xFFF5F5F4); // soft light grey
final _inputEnabledBorder = OutlineInputBorder(
  borderRadius: _inputBorderRadius,
  borderSide: BorderSide(color: Colors.grey.shade200),
);
final _inputFocusedBorder = OutlineInputBorder(
  borderRadius: _inputBorderRadius,
  borderSide: const BorderSide(color: AppColors.rose, width: 1.2),
);
final _inputErrorBorder = OutlineInputBorder(
  borderRadius: _inputBorderRadius,
  borderSide: BorderSide(color: Colors.red.shade300),
);

/// Registration screen with email/password and phone OTP verification.
class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  String? _selectedCity;
  String? _verificationId;
  bool _codeSent = false;
  bool _isSendingCode = false;
  bool _isRegistering = false;
  bool _isGoogleLoading = false;

  @override
  void initState() {
    super.initState();
    // Clear any SnackBars from the login screen (e.g. "Unable to sign in. Please try again.")
    // so they don't appear or repeat on the create-account screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : AppColors.rose,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnackBar('Please enter your phone number.', isError: true);
      return;
    }
    // Ensure country code format (e.g. +964)
    final normalizedPhone = phone.startsWith('+') ? phone : '+$phone';
    if (_isSendingCode) return;
    setState(() => _isSendingCode = true);
    try {
      await fa.FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: normalizedPhone,
        verificationCompleted: (_) {},
        verificationFailed: (e) {
          if (!mounted) return;
          setState(() => _isSendingCode = false);
          _showSnackBar(
            e.message ?? 'Verification failed. Please try again.',
            isError: true,
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _isSendingCode = false;
          });
          _showSnackBar('Code sent!');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!mounted) return;
          setState(() => _isSendingCode = false);
        },
        timeout: const Duration(seconds: 120),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingCode = false);
        _showSnackBar(
          e.toString().contains('invalid') ? 'Invalid phone number.' : 'Failed to send code. Try again.',
          isError: true,
        );
      }
    }
  }

  Future<void> _register() async {
    if (_isRegistering) return;
    if (!_formKey.currentState!.validate()) return;

    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final city = _selectedCity;
    final phoneNumber = _phoneController.text.trim();
    final otp = _otpController.text.trim();

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill in all fields.', isError: true);
      return;
    }
    if (city == null || city.isEmpty) {
      _showSnackBar('Please select a city.', isError: true);
      return;
    }
    if (phoneNumber.isEmpty) {
      _showSnackBar('Please enter your phone number.', isError: true);
      return;
    }
    if (!_codeSent || _verificationId == null) {
      _showSnackBar('Please send the verification code first.', isError: true);
      return;
    }
    if (otp.isEmpty) {
      _showSnackBar('Please enter the verification code.', isError: true);
      return;
    }

    await _registerWithForm();
  }

  Future<void> _signUpWithGoogle() async {
    if (_isGoogleLoading) return;
    if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
    if (DefaultFirebaseOptions.googleWebClientId.isEmpty) {
      _showSnackBar(
        'Google sign-in is not set up. Add the Web client ID from Firebase Console (Authentication → Google) or use email/password below.',
        isError: true,
      );
      return;
    }
    setState(() => _isGoogleLoading = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      if (!mounted) return;
      _showSnackBar('Account created successfully!');
      context.pop();
    } catch (e, st) {
      debugPrint('Google sign-up error: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) {
        _showSnackBar(
          authErrorMessage(e, fallback: 'Sign up failed. Please try again.'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _registerWithForm() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final city = _selectedCity!;
    final phoneNumber = _phoneController.text.trim();
    final normalizedPhone = phoneNumber.startsWith('+') ? phoneNumber : '+$phoneNumber';
    final otp = _otpController.text.trim();

    setState(() => _isRegistering = true);
    try {
      final credential = fa.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      try {
        await fa.FirebaseAuth.instance.signInWithCredential(credential);
      } on fa.FirebaseAuthException catch (e) {
        if (e.code == 'invalid-verification-code' ||
            e.code == 'invalid-verification-id' ||
            e.code == 'session-expired') {
          _showSnackBar('The code is invalid', isError: true);
          setState(() => _isRegistering = false);
          return;
        }
        rethrow;
      }
      // Sign out so we can create the email/password account
      await fa.FirebaseAuth.instance.signOut();

      final cred = await ref.read(authServiceProvider).createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
      final user = cred.user;
      if (user == null) {
        _showSnackBar('Account creation failed. Please try again.', isError: true);
        setState(() => _isRegistering = false);
        return;
      }
      await ref.read(authRepositoryProvider).setUserDoc(user.uid, {
        'fullName': fullName,
        'email': email,
        'city': city,
        'phoneNumber': normalizedPhone,
        'role': 'customer',
      });
      if (!mounted) return;
      _showSnackBar('Account created successfully!');
      context.pop();
    } catch (e) {
      if (mounted) {
        _showSnackBar(authErrorMessage(e, fallback: 'Registration failed. Please try again.'), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  static InputDecoration _inputDecoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      hintStyle: TextStyle(
        color: Colors.grey.shade500,
        fontSize: 14,
      ),
      filled: true,
      fillColor: _inputFillColor,
      prefixIcon: prefixIcon != null
          ? Padding(
              padding: const EdgeInsets.only(left: 14, right: 12),
              child: IconTheme.merge(
                data: IconThemeData(
                  size: 20,
                  color: Colors.grey.shade600,
                ),
                child: prefixIcon,
              ),
            )
          : null,
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 24),
      border: OutlineInputBorder(borderRadius: _inputBorderRadius),
      enabledBorder: _inputEnabledBorder,
      focusedBorder: _inputFocusedBorder,
      errorBorder: _inputErrorBorder,
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: _inputBorderRadius,
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  static String? _validateRequired(String? v, String fieldName) {
    if (v == null || v.trim().isEmpty) return 'Please enter $fieldName';
    return null;
  }

  static String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter your email';
    if (!v.contains('@') || !v.contains('.')) return 'Please enter a valid email';
    return null;
  }

  static String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Please enter a password';
    if (v.length < 6) return 'Use at least 6 characters';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    const maxWidth = 420.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.headerBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.inkCharcoal),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 28 : 48,
          vertical: isMobile ? 28 : 48,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Create account',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkCharcoal,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sign up with your details and verify your phone.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: 15,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 32),
                  _SignUpWithGmailButton(
                    label: AppLocalizations.of(context)!.signUpWithGmail,
                    onPressed: (_isRegistering || _isSendingCode) ? null : _signUpWithGoogle,
                    isLoading: _isGoogleLoading,
                  ),
                  const SizedBox(height: 28),
                  _OrDivider(
                    label: AppLocalizations.of(context)!.orSignUpWithDetails,
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _fullNameController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration(
                      label: 'Full Name',
                      hint: 'e.g. Ahmed Hassan',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) => _validateRequired(v, 'your full name'),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: _inputDecoration(
                      label: 'Email',
                      hint: 'you@example.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: _inputDecoration(
                      label: 'Password',
                      hint: 'At least 6 characters',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCity,
                    decoration: _inputDecoration(
                      label: 'City',
                      hint: 'Select city',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                    borderRadius: _inputBorderRadius,
                    items: kRegistrationCities
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCity = v),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please select a city';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration(
                      label: 'Phone Number',
                      hint: '+964 7XX XXX XXXX',
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                    validator: (v) => _validateRequired(v, 'your phone number'),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSendingCode ? null : _sendCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.rose,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.rose.withValues(alpha: 0.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27),
                        ),
                      ),
                      child: _isSendingCode
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Send the Code',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                letterSpacing: 0.2,
                              ),
                            ),
                    ),
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      maxLength: 6,
                      decoration: _inputDecoration(
                        label: 'Verification Code',
                        hint: 'Enter 6-digit code',
                        prefixIcon: const Icon(Icons.pin_outlined),
                      ),
                      validator: (v) {
                        if (!_codeSent) return null;
                        if (v == null || v.trim().isEmpty) return 'Enter the verification code';
                        if (v.trim().length < 6) return 'Enter the full 6-digit code';
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isRegistering ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.rose,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.rose.withValues(alpha: 0.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27),
                        ),
                      ),
                      child: _isRegistering
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Register',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                letterSpacing: 0.2,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                              fontSize: 15,
                            ),
                      ),
                      TextButton(
                        onPressed: _isRegistering ? null : () => context.pop(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Sign in',
                          style: TextStyle(
                            color: AppColors.rose,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
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

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.grey.shade300,
            height: 1,
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.grey.shade300,
            height: 1,
            thickness: 1,
          ),
        ),
      ],
    );
  }
}

class _SignUpWithGmailButton extends StatefulWidget {
  const _SignUpWithGmailButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  State<_SignUpWithGmailButton> createState() => _SignUpWithGmailButtonState();
}

class _SignUpWithGmailButtonState extends State<_SignUpWithGmailButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    final enabled = widget.onPressed != null && !widget.isLoading;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? widget.onPressed : null,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              vertical: isMobile ? 18 : 20,
              horizontal: isMobile ? 24 : 28,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hovered && enabled
                    ? Colors.grey.shade400
                    : Colors.grey.shade300,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading)
                  const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Image.network(
                    'https://img.icons8.com/color/48/000000/google-logo.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.g_mobiledata_rounded,
                      size: 24,
                      color: Colors.grey.shade700,
                    ),
                  ),
                const SizedBox(width: 14),
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: enabled
                            ? const Color(0xFF1A1A1A)
                            : AppColors.inkMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
