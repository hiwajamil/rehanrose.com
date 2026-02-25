import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../controllers/controllers.dart';
import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/auth_error_utils.dart';
import '../../../firebase_options.dart';
import '../../../l10n/app_localizations.dart';

// Reused input borders to avoid allocations on every build.
final _inputBorderRadius = BorderRadius.circular(12);
final _inputEnabledBorder = OutlineInputBorder(
  borderRadius: _inputBorderRadius,
  borderSide: const BorderSide(color: AppColors.border),
);
final _inputFocusedBorder = OutlineInputBorder(
  borderRadius: _inputBorderRadius,
  borderSide: const BorderSide(color: AppColors.rose, width: 1.5),
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

  void _closeAfterSuccess() {
    if (!mounted) return;
    widget.onSuccess?.call();
    if (widget.showAsModal) {
      Navigator.of(context).pop();
    } else {
      context.pop();
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    // Require Web client ID for Google Sign-In to work (Android, iOS, and web).
    if (DefaultFirebaseOptions.googleWebClientId.isEmpty) {
      _showError(
        'Google sign-in is not set up. To fix: add the Web client ID from Firebase Console (Authentication → Google) in lib/env/google_client_id.dart, or run with --dart-define=GOOGLE_WEB_CLIENT_ID=your-id. You can still sign in or register with email and password below.',
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      _closeAfterSuccess();
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
      if (_isRegisterMode) {
        await auth.createUserWithEmailAndPassword(email: email, password: password);
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      }
      _closeAfterSuccess();
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
        horizontal: isMobile ? 24 : 40,
        vertical: isMobile ? 24 : 40,
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
                if (!widget.showAsModal) const SizedBox(height: 24),
                Text(
                  l10n.loginTitle,
                  style: _loginTitleStyle,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.loginSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkMuted,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 32),
                _GoogleSignInButton(
                  label: l10n.continueWithGoogle,
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 24),
                _OrDivider(label: l10n.orSignInWithEmail),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: _inputDecoration(
                    label: l10n.emailLabel,
                    hint: l10n.emailHint,
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
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
                  ),
                  validator: (v) => _validatePassword(v, _isRegisterMode),
                ),
                const SizedBox(height: 24),
                _SubmitButton(
                  isRegisterMode: _isRegisterMode,
                  isLoading: _isLoading,
                  onPressed: _submitEmailPassword,
                  signInLabel: l10n.signIn,
                  registerLabel: l10n.register,
                ),
                const SizedBox(height: 16),
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
                  child: Text(
                    _isRegisterMode
                        ? 'Already have an account? Sign in'
                        : "Don't have an account? Create one",
                    style: const TextStyle(
                      color: AppColors.rose,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
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

  static InputDecoration _inputDecoration({required String label, required String hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: _inputBorderRadius),
      enabledBorder: _inputEnabledBorder,
      focusedBorder: _inputFocusedBorder,
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

// Cached once to avoid GoogleFonts lookup on every build.
final _loginTitleStyle = GoogleFonts.playfairDisplay(
  fontSize: 28,
  fontWeight: FontWeight.bold,
  color: AppColors.inkCharcoal,
);

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border, height: 1)),
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
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.rose,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.rose.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
          borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              vertical: isMobile ? 16 : 18,
              horizontal: isMobile ? 20 : 24,
            ),
            decoration: BoxDecoration(
              color: _hovered && enabled
                  ? AppColors.surface
                  : Colors.white,
              borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
              border: Border.all(
                color: _hovered && enabled
                    ? AppColors.rose.withValues(alpha: 0.4)
                    : AppColors.border,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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
                  FaIcon(
                    FontAwesomeIcons.google,
                    color: const Color(0xFF4285F4),
                    size: 22,
                  ),
                const SizedBox(width: 14),
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: enabled ? AppColors.inkCharcoal : AppColors.inkMuted,
                        fontWeight: FontWeight.w600,
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
