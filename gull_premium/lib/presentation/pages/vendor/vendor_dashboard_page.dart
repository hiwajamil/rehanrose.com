import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/utils/auth_error_utils.dart';
import '../../../controllers/controllers.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';
import 'vendor_dashboard_home_page.dart';

class VendorDashboardPage extends ConsumerStatefulWidget {
  const VendorDashboardPage({super.key});

  @override
  ConsumerState<VendorDashboardPage> createState() =>
      _VendorDashboardPageState();
}

class _VendorDashboardPageState extends ConsumerState<VendorDashboardPage> {
  bool _isSignIn = true;
  bool _isSubmitting = false;

  final TextEditingController _signInEmailController = TextEditingController();
  final TextEditingController _signInPasswordController = TextEditingController();

  final TextEditingController _studioNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _signUpEmailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _signUpPasswordController = TextEditingController();

  @override
  void dispose() {
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _studioNameController.dispose();
    _ownerNameController.dispose();
    _signUpEmailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _signUpPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitApplication() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (_studioNameController.text.trim().isEmpty ||
        _ownerNameController.text.trim().isEmpty ||
        _signUpEmailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _signUpPasswordController.text.trim().isEmpty) {
      _showMessage(l10n.vendorPleaseCompleteEveryField);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ref.read(vendorControllerProvider.notifier).submitApplication(
            studioName: _studioNameController.text.trim(),
            ownerName: _ownerNameController.text.trim(),
            email: _signUpEmailController.text.trim(),
            phone: _phoneController.text.trim(),
            location: _locationController.text.trim(),
            password: _signUpPasswordController.text.trim(),
          );
      if (!mounted) return;
      _showMessage(l10n.vendorApplicationSubmittedMessage);
      setState(() => _isSignIn = true);
    } on fa.FirebaseAuthException catch (e) {
      _showMessage(e.message ?? l10n.vendorUnableToSubmitApplication);
    } catch (e, _) {
      _showMessage(authErrorMessage(e, fallback: l10n.vendorUnableToSubmitApplicationRetry));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _signInVendor() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (_signInEmailController.text.trim().isEmpty ||
        _signInPasswordController.text.trim().isEmpty) {
      _showMessage(l10n.vendorEnterEmailPassword);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final status = await ref.read(vendorControllerProvider.notifier).signInVendor(
            email: _signInEmailController.text.trim(),
            password: _signInPasswordController.text.trim(),
          );
      if (!mounted) return;
      if (status != VendorStatus.approved) {
        _showMessage(
          status == VendorStatus.rejected
              ? l10n.vendorApplicationRejectedMessage
              : l10n.vendorApplicationUnderReviewMessage,
        );
      }
    } on fa.FirebaseAuthException catch (e) {
      _showMessage(e.message ?? l10n.vendorUnableToSignIn);
    } catch (e, _) {
      _showMessage(authErrorMessage(e, fallback: l10n.vendorCouldNotSignInFallback));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    return authAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => AppScaffold(child: _buildMarketing(context)),
      data: (user) {
        if (user == null) return AppScaffold(child: _buildMarketing(context));
        // Resolve vendor status so we never show the dashboard for a pending
        // user (e.g. right after submit, before signOut() completes).
        final statusAsync = ref.watch(vendorStatusForUidProvider(user.uid));
        return statusAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => AppScaffold(child: _buildMarketing(context)),
          data: (status) {
            if (status == 'approved') {
              return const VendorDashboardHomePage();
            }
            // Not approved: show wait-for-approval screen. Do NOT auto sign-out
            // here — it would race with submitApplication() which still needs
            // the user to be signed in to write users/ and vendor_applications/.
            // User can tap "Back to sign in" to sign out.
            return AppScaffold(
              child: _buildWaitForApproval(context, status == 'rejected'),
            );
          },
        );
      },
    );
  }

  Widget _buildWaitForApproval(BuildContext context, bool rejected) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              rejected ? Icons.cancel_outlined : Icons.schedule_outlined,
              size: 64,
              color: AppColors.inkMuted,
            ),
            const SizedBox(height: 24),
            Text(
              rejected
                  ? l10n.vendorApplicationRejectedMessage
                  : l10n.vendorApplicationSubmittedMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.inkMuted,
                  ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              child: Text(l10n.vendorBackToSignIn),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketing(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    final horizontalPadding = isMobile ? 16.0 : 48.0;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF5F4F2),
            Color(0xFFFAFAFA),
            Colors.white,
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => context.go('/admin'),
                child: Text(
                  l10n.vendorAdminLink,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
        SectionContainer(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 72),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 980;
              final isMobile = constraints.maxWidth <= kMobileBreakpoint;
              final formCard = Container(
                padding: EdgeInsets.all(isMobile ? 20 : 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AuthToggle(
                      isSignIn: _isSignIn,
                      onChanged: (value) =>
                          setState(() => _isSignIn = value),
                      signInLabel: l10n.vendorToggleSignIn,
                      createAccountLabel: l10n.vendorToggleCreateAccount,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      _isSignIn
                          ? l10n.vendorSignInTitle
                          : l10n.vendorStartApplicationTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isSignIn
                          ? l10n.vendorSignInSubtitle
                          : l10n.vendorStartApplicationSubtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.inkMuted),
                    ),
                    const SizedBox(height: 24),
                    if (_isSignIn) ...[
                      _AuthField(
                        label: l10n.vendorLabelBusinessEmail,
                        hintText: '',
                        icon: Icons.mail_outline,
                        controller: _signInEmailController,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      _AuthField(
                        label: l10n.vendorLabelPassword,
                        hintText: '',
                        icon: Icons.lock_outline,
                        obscureText: true,
                        controller: _signInPasswordController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: _isSubmitting ? null : _signInVendor,
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label:
                            _isSubmitting ? l10n.vendorSigningIn : l10n.signIn,
                        onPressed: _isSubmitting ? () {} : _signInVendor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.vendorForgotPasswordContactSupport,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.inkMuted),
                      ),
                    ] else ...[
                      _AuthField(
                        label: l10n.vendorStudioName,
                        hintText: '',
                        icon: Icons.storefront_outlined,
                        controller: _studioNameController,
                      ),
                      const SizedBox(height: 16),
                      _AuthField(
                        label: l10n.vendorOwnerName,
                        hintText: l10n.vendorOwnerNameHint,
                        hintStyle: TextStyle(color: AppColors.inkMuted),
                        icon: Icons.person_outline,
                        controller: _ownerNameController,
                      ),
                      const SizedBox(height: 16),
                      _AuthField(
                        label: l10n.vendorLabelBusinessEmail,
                        hintText: '',
                        icon: Icons.mail_outline,
                        controller: _signUpEmailController,
                      ),
                      const SizedBox(height: 16),
                      _AuthField(
                        label: l10n.vendorPhoneNumber,
                        hintText: '',
                        icon: Icons.call_outlined,
                        controller: _phoneController,
                      ),
                      const SizedBox(height: 16),
                      _AuthField(
                        label: l10n.vendorStudioLocation,
                        hintText: l10n.vendorStudioLocationHint,
                        hintStyle: TextStyle(color: AppColors.inkMuted),
                        icon: Icons.location_on_outlined,
                        controller: _locationController,
                      ),
                      const SizedBox(height: 16),
                      _AuthField(
                        label: l10n.vendorCreatePassword,
                        hintText: l10n.vendorCreatePasswordHint,
                        hintStyle: TextStyle(color: AppColors.inkMuted),
                        icon: Icons.lock_outline,
                        obscureText: true,
                        controller: _signUpPasswordController,
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: _isSubmitting
                            ? l10n.vendorSubmitting
                            : l10n.vendorSubmitApplication,
                        onPressed:
                            _isSubmitting ? () {} : _submitApplication,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.vendorTermsAgreement,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.inkMuted),
                      ),
                    ],
                  ],
                ),
              );
              if (isNarrow) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.vendorSignupHeadline,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.vendorShowcaseCopy,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 32),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _BenefitChip(label: l10n.vendorBenefitWeeklyPayouts),
                            _BenefitChip(label: l10n.vendorBenefitCuratedClientBase),
                            _BenefitChip(label: l10n.vendorBenefitDedicatedConcierge),
                          ],
                        ),
                        const SizedBox(height: 40),
                        _VendorStatsRow(isNarrow: true),
                      ],
                    ),
                    const SizedBox(height: 40),
                    formCard,
                  ],
                );
              }
              return Flex(
                direction: Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.vendorSignupHeadline,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.vendorShowcaseCopy,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 32),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _BenefitChip(label: l10n.vendorBenefitWeeklyPayouts),
                            _BenefitChip(label: l10n.vendorBenefitCuratedClientBase),
                            _BenefitChip(label: l10n.vendorBenefitDedicatedConcierge),
                          ],
                        ),
                        const SizedBox(height: 40),
                        _VendorStatsRow(isNarrow: isNarrow),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    flex: 5,
                    child: formCard,
                  ),
                ],
              );
            },
          ),
        ),
        SectionContainer(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.vendorSuccessToolkitTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.vendorSuccessToolkitSubtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.inkMuted,
                    ),
              ),
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 980;
                  if (isNarrow) {
                    return Column(
                      children: [
                        _ToolkitItem(
                          title: l10n.vendorToolkitOrderManagement,
                          description: l10n.vendorToolkitOrderManagementDesc,
                          icon: Icons.receipt_long_outlined,
                        ),
                        const SizedBox(height: 20),
                        _ToolkitItem(
                          title: l10n.vendorToolkitMerchandising,
                          description: l10n.vendorToolkitMerchandisingDesc,
                          icon: Icons.auto_awesome_outlined,
                        ),
                        const SizedBox(height: 20),
                        _ToolkitItem(
                          title: l10n.vendorToolkitInsightsPayouts,
                          description: l10n.vendorToolkitInsightsPayoutsDesc,
                          icon: Icons.bar_chart_outlined,
                        ),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ToolkitItem(
                          title: l10n.vendorToolkitOrderManagement,
                          description: l10n.vendorToolkitOrderManagementDesc,
                          icon: Icons.receipt_long_outlined,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _ToolkitItem(
                          title: l10n.vendorToolkitMerchandising,
                          description: l10n.vendorToolkitMerchandisingDesc,
                          icon: Icons.auto_awesome_outlined,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _ToolkitItem(
                          title: l10n.vendorToolkitInsightsPayouts,
                          description: l10n.vendorToolkitInsightsPayoutsDesc,
                          icon: Icons.bar_chart_outlined,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }

}

class _AuthToggle extends StatelessWidget {
  final bool isSignIn;
  final ValueChanged<bool> onChanged;
  final String signInLabel;
  final String createAccountLabel;

  const _AuthToggle({
    required this.isSignIn,
    required this.onChanged,
    required this.signInLabel,
    required this.createAccountLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ToggleButton(
          label: signInLabel,
          isActive: isSignIn,
          onTap: () => onChanged(true),
        ),
        const SizedBox(width: 12),
        _ToggleButton(
          label: createAccountLabel,
          isActive: !isSignIn,
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppColors.rose : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isActive ? AppColors.rose : AppColors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isActive ? Colors.white : AppColors.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextStyle? hintStyle;
  final IconData icon;
  final bool obscureText;
  final TextEditingController controller;
  final VoidCallback? onSubmitted;
  final TextInputAction? textInputAction;

  const _AuthField({
    required this.label,
    required this.hintText,
    this.hintStyle,
    required this.icon,
    required this.controller,
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
            hintStyle: hintStyle,
            prefixIcon: Icon(icon, color: AppColors.inkMuted, size: 22),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.rose.withValues(alpha: 0.4), width: 1),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _BenefitChip extends StatelessWidget {
  final String label;

  const _BenefitChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _VendorStatsRow extends StatelessWidget {
  final bool isNarrow;

  const _VendorStatsRow({required this.isNarrow});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stats = [
      _StatTile(
        value: '96%',
        label: l10n.vendorStatSatisfaction,
      ),
      _StatTile(
        value: '\$4.8k',
        label: l10n.vendorStatAvgRevenue,
      ),
      _StatTile(
        value: '48 hrs',
        label: l10n.vendorStatFastOnboarding,
      ),
    ];

    if (isNarrow) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: stats
            .map(
              (stat) => SizedBox(
                width: 160,
                child: stat,
              ),
            )
            .toList(),
      );
    }
    return Row(
      children: [
        for (int i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: stats[i]),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;

  const _StatTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.rose,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _ToolkitItem extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _ToolkitItem({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.rose.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.rose, size: 24),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkMuted,
                      height: 1.45,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
