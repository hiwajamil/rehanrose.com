import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../controllers/controllers.dart';
import '../../../core/constants/breakpoints.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/auth_error_utils.dart';
import '../../../firebase_options.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/common/app_cached_image.dart';

// Premium input styling: soft fill, no heavy outline, rounded corners (matches Registration).
final _inputBorderRadius = BorderRadius.circular(12);
const _inputFillColor = Color(0xFFF5F5F4);
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

/// Elegant login screen for customers. Primary CTA: Continue with Google.
/// Secondary: email/password sign-in and create account.
/// Can be used as a full route or shown in a modal.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.onSuccess,
    this.showAsModal = false,
  });

  /// Called after successful sign-in. If null, pops the route or closes modal.
  final VoidCallback? onSuccess;

  /// When true, no app bar; suitable for modal. When false, shows back button.
  final bool showAsModal;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isRegisterMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.rose,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: AppColors.inkCharcoal),
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        elevation: 2,
      ),
    );
  }

  void _openForgotPassword() {
    try {
      final l10n = AppLocalizations.of(context);
      if (l10n == null) {
        _showError('Unable to load translations.');
        return;
      }
      final authService = ref.read(authServiceProvider);
      final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
      if (isMobile) {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => _ResetPasswordSheet(
            l10n: l10n,
            onCancel: () => Navigator.of(ctx).pop(),
            onSent: () {
              Navigator.of(ctx).pop();
              _showSuccess(l10n.resetPasswordSuccessMessage);
            },
            onError: _showError,
            authService: authService,
          ),
        );
      } else {
        showDialog<void>(
          context: context,
          builder: (ctx) => _ResetPasswordDialog(
            l10n: l10n,
            onCancel: () => Navigator.of(ctx).pop(),
            onSent: () {
              Navigator.of(ctx).pop();
              _showSuccess(l10n.resetPasswordSuccessMessage);
            },
            onError: _showError,
            authService: authService,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('Forgot password open error: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) _showError('Something went wrong. Please try again.');
    }
  }

  void _closeAfterSuccess() {
    if (!mounted) return;
    widget.onSuccess?.call();
    if (widget.showAsModal) {
      Navigator.of(context).pop();
    } else {
      context.pop();
    }
  }

  /// Navigate to the correct screen based on user role
  /// (admin → /admin, vendor → /vendor, driver → /driver, else → home).
  Future<void> _navigateAfterSignIn(String uid) async {
    final role = await ref.read(authRepositoryProvider).getRoleForRouting(uid);
    if (!mounted) return;
    final path = role == 'admin'
        ? '/admin'
        : role == 'vendor'
            ? '/vendor'
            : role == 'driver'
                ? '/driver'
            : '/';
    context.go(path);
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    // Mobile Google Sign-In needs a Web client ID. Web uses FirebaseAuth popup flow.
    if (!kIsWeb && DefaultFirebaseOptions.googleWebClientId.isEmpty) {
      _showError(
        'Google sign-in is not set up. To fix: add the Web client ID from Firebase Console (Authentication → Google) in lib/env/google_client_id.dart, or run with --dart-define=GOOGLE_WEB_CLIENT_ID=your-id. You can still sign in or register with email and password below.',
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final credential = await ref.read(authServiceProvider).signInWithGoogle();
      final uid = credential.user?.uid;
      if (uid != null) {
        await _navigateAfterSignIn(uid);
      } else {
        _closeAfterSuccess();
      }
    } catch (e, st) {
      debugPrint('Google sign-in error: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) _showError(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitEmailPassword() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final auth = ref.read(authServiceProvider);
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final credential = _isRegisterMode
          ? await auth.createUserWithEmailAndPassword(email: email, password: password)
          : await auth.signInWithEmailAndPassword(email: email, password: password);
      final uid = credential.user?.uid;
      if (uid != null) {
        await _navigateAfterSignIn(uid);
      } else {
        _closeAfterSuccess();
      }
    } catch (e) {
      if (mounted) _showError(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    const maxWidth = 420.0;

    final content = SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 28 : 48,
        vertical: isMobile ? 28 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.showAsModal) const SizedBox(height: 8),
                  Text(
                    l10n.loginTitle,
                    style: _loginTitleStyle,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.loginSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: 15,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 32),
                  _GoogleSignInButton(
                    label: l10n.continueWithGoogle,
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 28),
                  _OrDivider(label: l10n.orSignInWithEmail),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: _inputDecoration(
                      label: l10n.emailLabel,
                      hint: l10n.emailHint,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: _isRegisterMode
                        ? [AutofillHints.newPassword]
                        : [AutofillHints.password],
                    onFieldSubmitted: (_) => _submitEmailPassword(),
                    decoration: _inputDecoration(
                      label: l10n.passwordLabel,
                      hint: l10n.passwordHint,
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                    ),
                    validator: (v) => _validatePassword(v, _isRegisterMode),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading || _isRegisterMode
                          ? null
                          : _openForgotPassword,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        l10n.forgotPassword,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _isLoading || _isRegisterMode
                              ? Colors.grey.shade400
                              : AppColors.rose,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _SubmitButton(
                    isRegisterMode: _isRegisterMode,
                    isLoading: _isLoading,
                    onPressed: _submitEmailPassword,
                    signInLabel: l10n.signIn,
                    registerLabel: l10n.register,
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (_isRegisterMode) {
                              setState(() => _isRegisterMode = false);
                            } else {
                              context.push('/register');
                            }
                          },
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                              fontSize: 15,
                            ),
                        children: [
                          TextSpan(
                            text: _isRegisterMode
                                ? 'Already have an account? '
                                : "Don't have an account? ",
                          ),
                          TextSpan(
                            text: _isRegisterMode ? 'Sign in' : 'Create one',
                            style: const TextStyle(
                              color: AppColors.rose,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.showAsModal) return content;

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
      body: content,
    );
  }

  static InputDecoration _inputDecoration({
    required String label,
    required String hint,
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

  static String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter your email';
    if (!v.contains('@') || !v.contains('.')) return 'Please enter a valid email';
    return null;
  }

  static String? _validatePassword(String? v, bool isRegisterMode) {
    if (v == null || v.isEmpty) return 'Please enter your password';
    if (isRegisterMode && v.length < 6) return 'Use at least 6 characters';
    return null;
  }
}

/// Reset password dialog for desktop/web. Uses premium styling.
class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({
    required this.l10n,
    required this.onCancel,
    required this.onSent,
    required this.onError,
    required this.authService,
  });

  final AppLocalizations l10n;
  final VoidCallback onCancel;
  final VoidCallback onSent;
  final void Function(String message) onError;
  final AuthService authService;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendLink() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    setState(() => _isLoading = true);
    try {
      await widget.authService.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      widget.onSent();
    } catch (e) {
      if (mounted) widget.onError(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.l10n.resetPasswordTitle,
        style: GoogleFonts.playfairDisplay(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.inkCharcoal,
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.l10n.resetPasswordSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _LoginScreenState._inputDecoration(
                label: widget.l10n.emailLabel,
                hint: widget.l10n.emailHint,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              validator: _LoginScreenState._validateEmail,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : widget.onCancel,
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
          ),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _sendLink,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.rose,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.l10n.resetPasswordSendLink),
        ),
      ],
    );
  }
}

/// Reset password bottom sheet for mobile. Same logic, premium styling.
class _ResetPasswordSheet extends StatefulWidget {
  const _ResetPasswordSheet({
    required this.l10n,
    required this.onCancel,
    required this.onSent,
    required this.onError,
    required this.authService,
  });

  final AppLocalizations l10n;
  final VoidCallback onCancel;
  final VoidCallback onSent;
  final void Function(String message) onError;
  final AuthService authService;

  @override
  State<_ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends State<_ResetPasswordSheet> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendLink() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    setState(() => _isLoading = true);
    try {
      await widget.authService.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      widget.onSent();
    } catch (e) {
      if (mounted) widget.onError(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.paddingOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.l10n.resetPasswordTitle,
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.inkCharcoal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.l10n.resetPasswordSubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _LoginScreenState._inputDecoration(
                label: widget.l10n.emailLabel,
                hint: widget.l10n.emailHint,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              validator: _LoginScreenState._validateEmail,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              TextButton(
                onPressed: _isLoading ? null : widget.onCancel,
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _isLoading ? null : _sendLink,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rose,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(widget.l10n.resetPasswordSendLink),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Cached once to avoid GoogleFonts lookup on every build (matches Registration).
final _loginTitleStyle = GoogleFonts.playfairDisplay(
  fontSize: 30,
  fontWeight: FontWeight.w600,
  color: AppColors.inkCharcoal,
  letterSpacing: -0.5,
);

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

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.isRegisterMode,
    required this.isLoading,
    required this.onPressed,
    required this.signInLabel,
    required this.registerLabel,
  });

  final bool isRegisterMode;
  final bool isLoading;
  final VoidCallback onPressed;
  final String signInLabel;
  final String registerLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.rose,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.rose.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                isRegisterMode ? registerLabel : signInLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }
}

/// Large "Continue with Google" button with Google G icon.
class _GoogleSignInButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _GoogleSignInButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
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
                  AppCachedImage(
                    imageUrl: 'https://img.icons8.com/color/48/000000/google-logo.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                    errorIcon: Icons.g_mobiledata_rounded,
                    errorIconSize: 24,
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
