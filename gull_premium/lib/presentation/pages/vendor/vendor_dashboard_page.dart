import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
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
    if (_studioNameController.text.trim().isEmpty ||
        _ownerNameController.text.trim().isEmpty ||
        _signUpEmailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _signUpPasswordController.text.trim().isEmpty) {
      _showMessage('Please complete every field.');
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
      _showMessage('Application submitted. You will be notified after review.');
      setState(() => _isSignIn = true);
    } on fa.FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Unable to submit application.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _signInVendor() async {
    if (_signInEmailController.text.trim().isEmpty ||
        _signInPasswordController.text.trim().isEmpty) {
      _showMessage('Enter your email and password.');
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
              ? 'Your application was rejected. Contact support for details.'
              : 'Your application is still under review. Only approved vendors can sign in.',
        );
      }
    } on fa.FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Unable to sign in.');
    } catch (_) {
      _showMessage('Could not verify vendor status. Try again or contact support.');
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
        return const VendorDashboardHomePage();
      },
    );
  }

  Widget _buildMarketing(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    final horizontalPadding = isMobile ? 16.0 : 48.0;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => context.go('/admin'),
                child: Text(
                  'Admin',
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
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 980;
              final isMobile = constraints.maxWidth <= kMobileBreakpoint;
              return Flex(
                direction: isNarrow ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment:
                    isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Become a Gull vendor',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Showcase your studio, manage orders, and connect with clients who value artisanal florals.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 28),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: const [
                            _BenefitChip(label: 'Weekly payouts'),
                            _BenefitChip(label: 'Curated client base'),
                            _BenefitChip(label: 'Dedicated concierge'),
                          ],
                        ),
                        const SizedBox(height: 32),
                        _VendorStatsRow(isNarrow: isNarrow),
                      ],
                    ),
                  ),
                  if (!isNarrow) const SizedBox(width: 32),
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: EdgeInsets.all(isMobile ? 16 : 28),
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
                          _AuthToggle(
                            isSignIn: _isSignIn,
                            onChanged: (value) =>
                                setState(() => _isSignIn = value),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _isSignIn
                                ? 'Vendor sign in'
                                : 'Start your vendor application',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isSignIn
                                ? 'Welcome back. Access your storefront and orders.'
                                : 'Tell us about your studio so we can review your application.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.inkMuted),
                          ),
                          const SizedBox(height: 20),
                          if (_isSignIn) ...[
                            _AuthField(
                              label: 'Business email',
                              hintText: 'studio@email.com',
                              icon: Icons.mail_outline,
                              controller: _signInEmailController,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 16),
                            _AuthField(
                              label: 'Password',
                              hintText: 'Enter your password',
                              icon: Icons.lock_outline,
                              obscureText: true,
                              controller: _signInPasswordController,
                              textInputAction: TextInputAction.done,
                              onSubmitted: _isSubmitting ? null : _signInVendor,
                            ),
                            const SizedBox(height: 24),
                            PrimaryButton(
                              label:
                                  _isSubmitting ? 'Signing in...' : 'Sign in',
                              onPressed: _isSubmitting ? () {} : _signInVendor,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Forgot your password? Contact vendor support.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.inkMuted),
                            ),
                          ] else ...[
                            _AuthField(
                              label: 'Studio name',
                              hintText: 'Lune Botanica',
                              icon: Icons.storefront_outlined,
                              controller: _studioNameController,
                            ),
                            const SizedBox(height: 16),
                            _AuthField(
                              label: 'Owner name',
                              hintText: 'First and last name',
                              icon: Icons.person_outline,
                              controller: _ownerNameController,
                            ),
                            const SizedBox(height: 16),
                            _AuthField(
                              label: 'Business email',
                              hintText: 'studio@email.com',
                              icon: Icons.mail_outline,
                              controller: _signUpEmailController,
                            ),
                            const SizedBox(height: 16),
                            _AuthField(
                              label: 'Phone number',
                              hintText: '+1 (555) 123-4567',
                              icon: Icons.call_outlined,
                              controller: _phoneController,
                            ),
                            const SizedBox(height: 16),
                            _AuthField(
                              label: 'Studio location',
                              hintText: 'City, State',
                              icon: Icons.location_on_outlined,
                              controller: _locationController,
                            ),
                            const SizedBox(height: 16),
                            _AuthField(
                              label: 'Create a password',
                              hintText: 'At least 8 characters',
                              icon: Icons.lock_outline,
                              obscureText: true,
                              controller: _signUpPasswordController,
                            ),
                            const SizedBox(height: 24),
                            PrimaryButton(
                              label: _isSubmitting
                                  ? 'Submitting...'
                                  : 'Submit application',
                              onPressed:
                                  _isSubmitting ? () {} : _submitApplication,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'By submitting, you agree to our vendor terms and review process.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.inkMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        SectionContainer(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vendor success toolkit',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Everything you need to run a premium floral studio, in one place.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 980;
                  final cardWidth = isNarrow
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 32) / 3;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _ToolkitCard(
                        width: cardWidth,
                        title: 'Order management',
                        description:
                            'Track inbound orders, confirm delivery windows, and chat with concierge support.',
                        icon: Icons.receipt_long_outlined,
                      ),
                      _ToolkitCard(
                        width: cardWidth,
                        title: 'Merchandising tools',
                        description:
                            'Curate collections, schedule seasonal launches, and highlight your signature style.',
                        icon: Icons.auto_awesome_outlined,
                      ),
                      _ToolkitCard(
                        width: cardWidth,
                        title: 'Insights & payouts',
                        description:
                            'Review weekly performance and receive reliable payouts every Friday.',
                        icon: Icons.bar_chart_outlined,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

}

class _AuthToggle extends StatelessWidget {
  final bool isSignIn;
  final ValueChanged<bool> onChanged;

  const _AuthToggle({required this.isSignIn, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ToggleButton(
          label: 'Sign in',
          isActive: isSignIn,
          onTap: () => onChanged(true),
        ),
        const SizedBox(width: 12),
        _ToggleButton(
          label: 'Create account',
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
  final IconData icon;
  final bool obscureText;
  final TextEditingController controller;
  final VoidCallback? onSubmitted;
  final TextInputAction? textInputAction;

  const _AuthField({
    required this.label,
    required this.hintText,
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
            prefixIcon: Icon(icon, color: AppColors.inkMuted),
            filled: true,
            fillColor: AppColors.background,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

class _BenefitChip extends StatelessWidget {
  final String label;

  const _BenefitChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
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
    final stats = [
      const _StatTile(
        value: '96%',
        label: 'Vendor satisfaction',
      ),
      const _StatTile(
        value: '\$4.8k',
        label: 'Avg. weekly revenue',
      ),
      const _StatTile(
        value: '48 hrs',
        label: 'Fast onboarding',
      ),
    ];

    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: stats
          .map(
            (stat) => SizedBox(
              width: isNarrow ? 200 : 180,
              child: stat,
            ),
          )
          .toList(),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.rose,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ToolkitCard extends StatelessWidget {
  final double width;
  final String title;
  final String description;
  final IconData icon;

  const _ToolkitCard({
    required this.width,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.rose),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
        ],
      ),
    );
  }
}
