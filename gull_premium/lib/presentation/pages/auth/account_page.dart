import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../controllers/controllers.dart';
import '../../../core/services/whatsapp_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/layout/app_scaffold.dart';

/// Customer account / profile dashboard. When signed in, shows identity card,
/// quick actions, special occasions, and settings. When not logged in, shows
/// Sign In / Register CTA.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final l10n = AppLocalizations.of(context)!;

    return AppScaffold(
      child: authAsync.when(
        data: (user) {
          if (user == null) {
            return _SignedOutView(
              onSignIn: () => showLoginModalOrPush(context),
            );
          }
          return _CustomerDashboardView(
            uid: user.uid,
            fallbackDisplayName: user.displayName?.trim().isNotEmpty == true
                ? user.displayName!
                : (user.email ?? l10n.appTitle),
            fallbackPhotoUrl: user.photoURL,
            onSignOut: () async => ref.read(authRepositoryProvider).signOut(),
          );
        },
        loading: () => const _ProfileLoadingShimmer(),
        error: (_, __) => _SignedOutView(
          onSignIn: () => showLoginModalOrPush(context),
        ),
      ),
    );
  }
}

/// Shimmer placeholder while profile or auth is loading.
class _ProfileLoadingShimmer extends StatelessWidget {
  const _ProfileLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          Shimmer.fromColors(
            baseColor: AppColors.border,
            highlightColor: AppColors.surface,
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Shimmer.fromColors(
            baseColor: AppColors.border,
            highlightColor: AppColors.surface,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Signed-in customer dashboard: identity, quick actions, occasions, settings.
class _CustomerDashboardView extends ConsumerWidget {
  const _CustomerDashboardView({
    required this.uid,
    required this.fallbackDisplayName,
    required this.fallbackPhotoUrl,
    required this.onSignOut,
  });

  final String uid;
  final String fallbackDisplayName;
  final String? fallbackPhotoUrl;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(uid));

    return profileAsync.when(
      data: (profile) {
        final fullName = profile?['fullName']?.trim().isNotEmpty == true
            ? profile!['fullName']!
            : fallbackDisplayName;
        final phone = profile?['phone'] ?? '';
        final email = profile?['email'] ?? '';
        final city = profile?['city'] ?? '';
        final photoUrl = profile?['photoURL'] ?? fallbackPhotoUrl;

        return _DashboardContent(
          fullName: fullName,
          phone: phone,
          email: email,
          city: city,
          photoUrl: photoUrl,
          onSignOut: onSignOut,
        );
      },
      loading: () => const _ProfileLoadingShimmer(),
      error: (_, __) => _DashboardContent(
        fullName: fallbackDisplayName,
        phone: '',
        email: '',
        city: '',
        photoUrl: fallbackPhotoUrl,
        onSignOut: onSignOut,
      ),
    );
  }
}

class _DashboardContent extends StatefulWidget {
  const _DashboardContent({
    required this.fullName,
    required this.phone,
    required this.email,
    required this.city,
    required this.photoUrl,
    required this.onSignOut,
  });

  final String fullName;
  final String phone;
  final String email;
  final String city;
  final String? photoUrl;
  final Future<void> Function() onSignOut;

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  bool _isSigningOut = false;

  Future<void> _handleSignOut() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    try {
      await widget.onSignOut();
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sign out failed. Please try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  Future<void> _openWhatsAppSupport() async {
    final uri = Uri.parse('https://wa.me/$kWhatsAppOrderNumber');
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.profileComingSoon),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const cardRadius = 16.0;
    const sectionSpacing = 28.0;
    final softGrey = Colors.grey.shade600;
    final borderColor = Colors.grey.withValues(alpha: 0.1);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ——— Section A: User Identity & VIP Status ———
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(cardRadius),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey.shade100,
                      backgroundImage: widget.photoUrl != null &&
                              widget.photoUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(widget.photoUrl!)
                          : null,
                      child: widget.photoUrl == null || widget.photoUrl!.isEmpty
                          ? Text(
                              widget.fullName.isNotEmpty
                                  ? widget.fullName[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: softGrey,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B2724),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          l10n.profilePremiumMember,
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  widget.fullName,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkCharcoal,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.phone.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.phone,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: softGrey,
                          fontSize: 14,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (widget.email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.email,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: softGrey,
                          fontSize: 13,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (widget.city.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.city,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: softGrey,
                          fontSize: 13,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: sectionSpacing),

          // ——— Section B: Quick Actions ———
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: CupertinoIcons.doc_text,
                  label: l10n.profileMyOrders,
                  onTap: () => _showComingSoon(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _QuickActionCard(
                  icon: CupertinoIcons.location,
                  label: l10n.profileSavedAddresses,
                  onTap: () => _showComingSoon(),
                ),
              ),
            ],
          ),
          const SizedBox(height: sectionSpacing),

          // ——— Section C: Special Occasions (invitation card) ———
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(cardRadius),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.gift,
                      color: AppColors.rose,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.profileMySpecialOccasions,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkCharcoal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.profileOccasionsSubtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: softGrey,
                        fontSize: 13,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: _showComingSoon,
                  icon: Icon(
                    CupertinoIcons.add,
                    size: 18,
                    color: AppColors.rose,
                  ),
                  label: Text(
                    l10n.profileAddOccasion,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.rose,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: sectionSpacing),

          // ——— Section D: Settings list ———
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(cardRadius),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: CupertinoIcons.chat_bubble_2,
                  label: l10n.profileContactSupportWhatsApp,
                  onTap: _openWhatsAppSupport,
                ),
                Divider(height: 1, color: Colors.grey.withValues(alpha: 0.08)),
                _SettingsTile(
                  icon: CupertinoIcons.settings,
                  label: l10n.profileSettings,
                  onTap: _showComingSoon,
                ),
                Divider(height: 1, color: Colors.grey.withValues(alpha: 0.08)),
                _SettingsTile(
                  icon: CupertinoIcons.lock_open,
                  label: l10n.profileChangePassword,
                  onTap: _showComingSoon,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: _isSigningOut ? null : _handleSignOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade400,
                side: BorderSide(color: Colors.red.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(cardRadius),
                ),
              ),
              child: _isSigningOut
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.red.shade400,
                      ),
                    )
                  : Text(
                      l10n.signOut,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: Colors.red.shade400,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 28, color: AppColors.rose),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkCharcoal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, size: 22, color: Colors.grey.shade600),
      title: Text(
        label,
        style: GoogleFonts.montserrat(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.inkCharcoal,
        ),
      ),
      trailing: Icon(
        CupertinoIcons.chevron_right,
        size: 16,
        color: Colors.grey.shade400,
      ),
      onTap: onTap,
    );
  }
}

class _SignedOutView extends StatelessWidget {
  const _SignedOutView({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 72,
              color: AppColors.inkMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.account,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.inkCharcoal,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sign in to view your account and preferences.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rose,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.signInRegister,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
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
