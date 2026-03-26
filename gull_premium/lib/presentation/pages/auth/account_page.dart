import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../controllers/controllers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/user_occasion_model.dart';
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
      title: l10n.account,
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
            fallbackEmail: user.email ?? '',
            fallbackPhotoUrl: user.photoURL,
            onSignOut: () async {
              try {
                await ref.read(authRepositoryProvider).signOut();
              } finally {
                await fa.FirebaseAuth.instance.signOut();
              }
            },
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
    required this.fallbackEmail,
    required this.fallbackPhotoUrl,
    required this.onSignOut,
  });

  final String uid;
  final String fallbackDisplayName;
  final String fallbackEmail;
  final String? fallbackPhotoUrl;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(uid));
    final premiumAsync = ref.watch(userPremiumStatusProvider(uid));

    return profileAsync.when(
      data: (profile) {
        final fullName = profile?['fullName']?.trim().isNotEmpty == true
            ? profile!['fullName']!
            : fallbackDisplayName;
        final phone = profile?['phone'] ?? '';
        final profileEmail = profile?['email']?.trim() ?? '';
        final email = profileEmail.isNotEmpty ? profileEmail : fallbackEmail;
        final city = profile?['city'] ?? '';
        final photoUrl = profile?['photoURL'] ?? fallbackPhotoUrl;
        final isPremium = premiumAsync.value ?? false;

        return _DashboardContent(
          uid: uid,
          fullName: fullName,
          phone: phone,
          email: email,
          city: city,
          photoUrl: photoUrl,
          isPremium: isPremium,
          onSignOut: onSignOut,
        );
      },
      loading: () => const _ProfileLoadingShimmer(),
      error: (_, __) {
        final isPremium = premiumAsync.value ?? false;
        return _DashboardContent(
          uid: uid,
          fullName: fallbackDisplayName,
          phone: '',
          email: fallbackEmail,
          city: '',
          photoUrl: fallbackPhotoUrl,
          isPremium: isPremium,
          onSignOut: onSignOut,
        );
      },
    );
  }
}

class _DashboardContent extends ConsumerStatefulWidget {
  const _DashboardContent({
    required this.uid,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.city,
    required this.photoUrl,
    required this.isPremium,
    required this.onSignOut,
  });

  final String uid;
  final String fullName;
  final String phone;
  final String email;
  final String city;
  final String? photoUrl;
  final bool isPremium;
  final Future<void> Function() onSignOut;

  @override
  ConsumerState<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends ConsumerState<_DashboardContent> {
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
    const number = '9647709818181';
    final uri = Uri.parse('https://wa.me/$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleChangePassword() async {
    final email = widget.email.trim();
    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No email on file. Please contact support.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Check your inbox — we\'ve sent a link to reset your password.',
          ),
          backgroundColor: AppColors.forestGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send reset email: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAddOccasionModal() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddOccasionSheet(
        titleText: l10n.profileAddOccasion,
        submitText: 'Save',
        successText: 'Occasion saved.',
        onSave: (name, date) async {
          await ref.read(userOccasionsRepositoryProvider).addOccasion(
                widget.uid,
                name: name,
                date: date,
              );
        },
        l10n: l10n,
      ),
    );
  }

  void _showEditOccasionModal(UserOccasionModel occasion) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddOccasionSheet(
        titleText: 'Edit occasion',
        submitText: 'Update',
        successText: 'Occasion updated.',
        initialName: occasion.name,
        initialDate: occasion.date,
        onSave: (name, date) async {
          await ref.read(userOccasionsRepositoryProvider).updateOccasion(
                widget.uid,
                occasion.id,
                name: name,
                date: date,
              );
        },
        l10n: l10n,
      ),
    );
  }

  Future<void> _confirmAndDeleteOccasion(UserOccasionModel occasion) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Delete Occasion?',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.inkCharcoal,
            ),
          ),
          content: Text(
            'Are you sure you want to remove this occasion?',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(userOccasionsRepositoryProvider)
          .deleteOccasion(widget.uid, occasion.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Occasion removed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
    const cardRadius = 20.0;
    const sectionSpacing = 24.0;
    final softGrey = AppColors.inkMuted;
    final borderColor = AppColors.border;
    final occasionsAsync = ref.watch(userOccasionsStreamProvider(widget.uid));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          // ——— Section A: User Identity & Premium badge (Rehan Rose luxury) ———
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor.withValues(alpha: 0.9)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.forestGreen.withValues(alpha: 0.05),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.isPremium
                              ? AppColors.accentGold
                              : AppColors.forestGreen.withValues(alpha: 0.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (widget.isPremium
                                    ? AppColors.accentGold
                                    : AppColors.forestGreen)
                                .withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.creamBackground,
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
                                  fontSize: 36,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.forestGreen,
                                ),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: widget.isPremium
                              ? AppColors.badgeGoldBackground
                              : AppColors.forestGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: widget.isPremium
                                ? AppColors.accentGold.withValues(alpha: 0.5)
                                : AppColors.forestGreen.withValues(alpha: 0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.isPremium
                                  ? Icons.workspace_premium_rounded
                                  : Icons.person_rounded,
                              size: 16,
                              color: widget.isPremium
                                  ? AppColors.accentGold
                                  : AppColors.forestGreen,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.isPremium
                                  ? l10n.profilePremiumMember
                                  : 'Member',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.isPremium
                                    ? AppColors.ink
                                    : AppColors.forestGreen,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  widget.fullName,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkCharcoal,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                if (widget.email.isNotEmpty)
                  _ContactRow(
                    icon: Icons.email_outlined,
                    text: widget.email,
                    softGrey: softGrey,
                  ),
                if (widget.phone.isNotEmpty) ...[
                  if (widget.email.isNotEmpty) const SizedBox(height: 6),
                  _ContactRow(
                    icon: Icons.phone_outlined,
                    text: widget.phone,
                    softGrey: softGrey,
                  ),
                ],
                if (widget.city.isNotEmpty) ...[
                  if (widget.email.isNotEmpty || widget.phone.isNotEmpty)
                    const SizedBox(height: 6),
                  _ContactRow(
                    icon: Icons.location_on_outlined,
                    text: widget.city,
                    softGrey: softGrey,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: sectionSpacing),

          // ——— Section B: Dashboard shortcuts (balanced 2x2 grid) ———
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 12) / 2;
              final ratio = itemWidth < 150 ? 1.02 : 1.1;
              return GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: ratio,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _SummaryCard(
                    icon: Icons.local_mall_outlined,
                    label: l10n.profileMyOrders,
                    onTap: () => context.push('/orders'),
                  ),
                  _SummaryCard(
                    icon: Icons.location_on_outlined,
                    label: l10n.profileSavedAddresses,
                    onTap: () => context.push('/addresses'),
                  ),
                  _SummaryCard(
                    icon: Icons.record_voice_over,
                    label: 'Voice Messages',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const VoiceMessagesHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  _SummaryCard(
                    icon: Icons.favorite_outline_rounded,
                    label: 'My Favorites',
                    onTap: () => context.push('/wishlist'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: sectionSpacing),

          // ——— Section C: My Special Occasions (elegant banner card) ———
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surface,
                  AppColors.rose.withValues(alpha: 0.06),
                  AppColors.forestGreen.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(cardRadius),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: AppColors.rose.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.rose.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.rose.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.card_giftcard_rounded,
                        color: AppColors.rose,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.profileMySpecialOccasions,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkCharcoal,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.profileOccasionsSubtitle,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: softGrey,
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                occasionsAsync.when(
                  data: (occasions) {
                    if (occasions.isNotEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...occasions.map(
                            (o) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _OccasionChip(
                                name: o.name,
                                date: o.date,
                                onEdit: () => _showEditOccasionModal(o),
                                onDelete: () => _confirmAndDeleteOccasion(o),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Center(child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _showAddOccasionModal,
                    icon: Icon(
                      Icons.add_rounded,
                      size: 22,
                      color: AppColors.surface,
                    ),
                    label: Text(
                      l10n.profileAddOccasion,
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.surface,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forestGreen,
                      foregroundColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: sectionSpacing),

          // ——— Section D: Settings list (elegant tiles with trailing arrows) ———
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(cardRadius),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: l10n.profileContactSupportWhatsApp,
                  onTap: _openWhatsAppSupport,
                ),
                _DividerIndent(indent: 72),
                _SettingsTile(
                  icon: Icons.settings_outlined,
                  label: l10n.profileSettings,
                  onTap: _showComingSoon,
                ),
                _DividerIndent(indent: 72),
                _SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  label: l10n.profileChangePassword,
                  onTap: _handleChangePassword,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 240,
              height: 52,
              child: OutlinedButton(
                onPressed: _isSigningOut ? null : _handleSignOut,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade400,
                  side: BorderSide(color: Colors.red.shade300, width: 1.2),
                  shape: const StadiumBorder(),
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
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.red.shade400,
                        ),
                      ),
              ),
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.text,
    required this.softGrey,
  });

  final IconData icon;
  final String text;
  final Color softGrey;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: softGrey),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: softGrey,
                  fontSize: 14,
                ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Prominent clickable summary card for My Orders / Saved Addresses.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: AppColors.forestGreen.withValues(alpha: 0.08),
        highlightColor: AppColors.forestGreen.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                color: AppColors.forestGreen.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.forestGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 34, color: AppColors.forestGreen),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkCharcoal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DividerIndent extends StatelessWidget {
  const _DividerIndent({required this.indent});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: Colors.grey.withValues(alpha: 0.12),
      indent: indent,
      endIndent: 20,
    );
  }
}

class _OccasionChip extends StatelessWidget {
  const _OccasionChip({
    required this.name,
    required this.date,
    this.onEdit,
    this.onDelete,
  });

  final String name;
  final DateTime date;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.cake_rounded, size: 20, color: AppColors.rose),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.inkCharcoal,
              ),
            ),
          ),
          Text(
            DateFormat.yMMMd().format(date),
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(width: 6),
          if (onEdit != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Edit',
              onPressed: onEdit,
              icon: Icon(
                Icons.edit_rounded,
                size: 18,
                color: AppColors.inkMuted,
              ),
            ),
          if (onDelete != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 19,
                color: Colors.red.shade400,
              ),
            ),
        ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.forestGreen.withValues(alpha: 0.08),
        highlightColor: AppColors.forestGreen.withValues(alpha: 0.04),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          leading: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.forestGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: AppColors.forestGreen),
          ),
          title: Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.inkCharcoal,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: AppColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

class VoiceMessagesHistoryScreen extends StatelessWidget {
  const VoiceMessagesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Voice Messages',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w600,
            color: AppColors.inkCharcoal,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mic_none,
                size: 56,
                color: AppColors.forestGreen,
              ),
              const SizedBox(height: 16),
              Text(
                'Voice message history is coming soon.',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkCharcoal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal bottom sheet to add an occasion (name + date). Saves to Firestore via [onSave].
class _AddOccasionSheet extends StatefulWidget {
  const _AddOccasionSheet({
    required this.titleText,
    required this.submitText,
    required this.successText,
    required this.onSave,
    required this.l10n,
    this.initialName,
    this.initialDate,
  });

  final String titleText;
  final String submitText;
  final String successText;
  final Future<void> Function(String name, DateTime date) onSave;
  final AppLocalizations l10n;
  final String? initialName;
  final DateTime? initialDate;

  @override
  State<_AddOccasionSheet> createState() => _AddOccasionSheetState();
}

class _AddOccasionSheetState extends State<_AddOccasionSheet> {
  final _nameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initialName = widget.initialName?.trim();
    if (initialName != null && initialName.isNotEmpty) {
      _nameController.text = initialName;
    }
    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.forestGreen,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter an occasion name.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(name, _selectedDate);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.successText),
          backgroundColor: AppColors.forestGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.creamBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.titleText,
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.inkCharcoal,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Occasion name (e.g. Birthday, Anniversary)',
              hintText: 'Birthday, Anniversary, Mother\'s Day…',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.forestGreen, width: 1.5),
              ),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: _saving ? null : _pickDate,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, color: AppColors.forestGreen, size: 22),
                  const SizedBox(width: 14),
                  Text(
                    DateFormat.yMMMd().format(_selectedDate),
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkCharcoal,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                    foregroundColor: AppColors.surface,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(widget.submitText),
                ),
              ),
            ],
          ),
        ],
      ),
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
