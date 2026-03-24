import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/env/app_env.dart';
import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../controllers/controllers.dart';
import '../../../data/models/flower_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/admin/bouquet_approval/bouquet_approval.dart';
import '../../widgets/common/primary_button.dart';

/// Admin page for Perfume Approval System. Premium tab-based UI: Pending, Approved, Rejected, Deleted.
class PerfumeApprovalScreen extends ConsumerStatefulWidget {
  const PerfumeApprovalScreen({super.key});

  @override
  ConsumerState<PerfumeApprovalScreen> createState() => _PerfumeApprovalScreenState();
}

class _PerfumeApprovalScreenState extends ConsumerState<PerfumeApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _ensureSuperAdmin() async {
    final user = ref.read(authStateProvider).when(
          data: (u) => u,
          loading: () => null,
          error: (_, __) => null,
        );
    final superEmail = AppEnv.superAdminEmail.trim();
    if (user != null &&
        superEmail.isNotEmpty &&
        user.email?.trim().toLowerCase() == superEmail.toLowerCase()) {
      await ref.read(authRepositoryProvider).ensureSuperAdminUserDoc(user.uid);
    }
  }

  Future<void> _approve(String bouquetId) async {
    setState(() => _processingIds.add(bouquetId));
    try {
      await _ensureSuperAdmin();
      await FirebaseFirestore.instance.collection('perfumes').doc(bouquetId).update({
        'approvalStatus': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'rejectedAt': FieldValue.delete(),
        'deletedAt': FieldValue.delete(),
        'rejectionReason': FieldValue.delete(),
        'rejectionNote': FieldValue.delete(),
      });
      if (mounted) _showMessage('Perfume approved. It will appear on the main screen.');
    } catch (e, st) {
      if (mounted) {
        debugPrint('Approve bouquet error: $e $st');
        _showMessage('Unable to approve perfume. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(bouquetId));
    }
  }

  Future<void> _showRejectDialog(String bouquetId) async {
    final result = await showDialog<RejectDialogResult>(
      context: context,
      builder: (context) => const RejectBouquetDialog(),
    );
    if (result == null || !mounted) return;
    await _reject(bouquetId, result.reason, result.note);
  }

  Future<void> _reject(String bouquetId, String rejectionReason, [String rejectionNote = '']) async {
    setState(() => _processingIds.add(bouquetId));
    try {
      await _ensureSuperAdmin();
      await FirebaseFirestore.instance.collection('perfumes').doc(bouquetId).update({
        'approvalStatus': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'approvedAt': FieldValue.delete(),
        'deletedAt': FieldValue.delete(),
        'rejectionReason': rejectionReason,
        if (rejectionNote.isNotEmpty) 'rejectionNote': rejectionNote else 'rejectionNote': FieldValue.delete(),
      });
      if (mounted) _showMessage('Perfume rejected. Vendor will see the reason.');
    } catch (e, st) {
      if (mounted) {
        debugPrint('Reject bouquet error: $e $st');
        _showMessage('Unable to reject perfume. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(bouquetId));
    }
  }

  Future<void> _deletePermanently(String bouquetId) async {
    setState(() => _processingIds.add(bouquetId));
    try {
      await FirebaseFirestore.instance.collection('perfumes').doc(bouquetId).delete();
      if (mounted) _showMessage('Perfume deleted permanently.');
    } catch (e, st) {
      if (mounted) {
        debugPrint('Delete bouquet error: $e $st');
        _showMessage('Unable to delete perfume. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(bouquetId));
    }
  }

  Future<void> _softDelete(String bouquetId) async {
    setState(() => _processingIds.add(bouquetId));
    try {
      await _ensureSuperAdmin();
      await FirebaseFirestore.instance.collection('perfumes').doc(bouquetId).update({
        'approvalStatus': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) _showMessage('Perfume moved to Deleted.');
    } catch (e, st) {
      if (mounted) {
        debugPrint('Soft delete bouquet error: $e $st');
        _showMessage('Unable to delete perfume. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(bouquetId));
    }
  }

  Future<void> _confirmDelete(BuildContext context, FlowerModel bouquet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Permanently?', style: GoogleFonts.montserrat()),
        content: Text(
          'This will permanently delete "${bouquet.name}" and all its images. This action cannot be undone.',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: GoogleFonts.montserrat()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB71C1C)),
            child: Text('Delete', style: GoogleFonts.montserrat(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _deletePermanently(bouquet.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    return authAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildAccessDenied(context),
      data: (user) {
        if (user == null) return _buildAccessDenied(context);
        return FutureBuilder<bool>(
          future: ref.read(authRepositoryProvider).isAdmin(user.uid),
          builder: (context, adminSnapshot) {
            if (adminSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (adminSnapshot.data != true) return _buildAccessDenied(context);
            return _buildContent(context);
          },
        );
      },
    );
  }

  Widget _buildAccessDenied(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Access restricted', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Back to Admin',
            onPressed: () => context.go('/admin'),
            variant: PrimaryButtonVariant.outline,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.perfume_approval,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Back to Admin',
                onPressed: () => context.go('/admin'),
                variant: PrimaryButtonVariant.outline,
              ),
            ],
          )
        else
          Row(
            children: [
              Text(
                l10n.perfume_approval,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Back to Admin',
                onPressed: () => context.go('/admin'),
                variant: PrimaryButtonVariant.outline,
              ),
            ],
          ),
        const SizedBox(height: 8),
        Text(
          'Review and manage vendor perfumes by status.',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 24),
        _OperationalOverview(isMobile: isMobile),
        const SizedBox(height: 24),
        _BouquetPillTabBar(controller: _tabController),
        const SizedBox(height: 16),
        Expanded(
          child: RepaintBoundary(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TabContent(
                  providerKey: _TabProviderKey.pending,
                  variant: ApprovalCardVariant.pending,
                  processingIds: _processingIds,
                  onApprove: _approve,
                  onReject: _showRejectDialog,
                  onDeletePermanently: (bouquet) {
                    unawaited(_confirmDelete(context, bouquet));
                  },
                  onSoftDelete: null,
                  emptyMessage: 'No pending perfumes.',
                ),
                _TabContent(
                  providerKey: _TabProviderKey.approved,
                  variant: ApprovalCardVariant.approved,
                  processingIds: _processingIds,
                  onApprove: _approve,
                  onReject: _showRejectDialog,
                  onDeletePermanently: (bouquet) {
                    unawaited(_confirmDelete(context, bouquet));
                  },
                  onSoftDelete: _softDelete,
                  emptyMessage: 'No approved perfumes.',
                ),
                _TabContent(
                  providerKey: _TabProviderKey.rejected,
                  variant: ApprovalCardVariant.rejected,
                  processingIds: _processingIds,
                  onApprove: _approve,
                  onReject: _showRejectDialog,
                  onDeletePermanently: (bouquet) {
                    unawaited(_confirmDelete(context, bouquet));
                  },
                  onSoftDelete: null,
                  emptyMessage: 'No rejected perfumes.',
                ),
                _TabContent(
                  providerKey: _TabProviderKey.deleted,
                  variant: ApprovalCardVariant.deleted,
                  processingIds: _processingIds,
                  onApprove: _approve,
                  onReject: _showRejectDialog,
                  onDeletePermanently: (bouquet) {
                    unawaited(_confirmDelete(context, bouquet));
                  },
                  onSoftDelete: null,
                  emptyMessage: 'No deleted perfumes.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _TabProviderKey { pending, approved, rejected, deleted }

/// Premium pill-shaped segmented control for bouquet approval tabs.
/// Scrollable horizontal row so all 4 tabs fit on mobile without overflow.
class _BouquetPillTabBar extends StatelessWidget {
  const _BouquetPillTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicator: BoxDecoration(
            color: AppColors.rosePrimary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.rosePrimary.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: AppColors.rosePrimary,
          unselectedLabelColor: AppColors.inkMuted,
          labelStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          tabs: const [
            Tab(child: _TabBadge(providerKey: _TabProviderKey.pending)),
            Tab(child: _TabBadge(providerKey: _TabProviderKey.approved)),
            Tab(child: _TabBadge(providerKey: _TabProviderKey.rejected)),
            Tab(child: _TabBadge(providerKey: _TabProviderKey.deleted)),
          ],
        ),
      ),
    );
  }
}

/// Combined approval statistics for the Operational Overview. Updates in real time from streams.
class _ApprovalStats {
  const _ApprovalStats({
    required this.totalApproved,
    required this.totalRejected,
    required this.totalPending,
    required this.total,
    required this.qualityIndexPercent,
  });

  final int totalApproved;
  final int totalRejected;
  final int totalPending;
  final int total;
  final double qualityIndexPercent;
}

final _approvalStatsProvider = Provider<AsyncValue<_ApprovalStats>>((ref) {
  final statsAsync = ref.watch(_perfumeApprovalStatsStreamProvider);
  return statsAsync.whenData((stats) => stats);
});

/// Minimalist Approval Statistics: Total Approved, Total Rejected, Quality Index, and workload progress.
class _OperationalOverview extends ConsumerWidget {
  const _OperationalOverview({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_approvalStatsProvider);
    final stats = statsAsync.maybeWhen(
      data: (value) => value,
      orElse: () => const _ApprovalStats(
        totalApproved: 0,
        totalRejected: 0,
        totalPending: 0,
        total: 0,
        qualityIndexPercent: 0,
      ),
    );

    final montserrat = GoogleFonts.montserrat();
    final playfair = GoogleFonts.playfairDisplay(
      fontSize: isMobile ? 18 : 20,
      fontWeight: FontWeight.bold,
      color: AppColors.ink,
    );
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Operational Overview', style: playfair),
          const SizedBox(height: 20),
          if (isMobile)
            _buildStatsColumn(stats, montserrat)
          else
            _buildStatsRow(stats, montserrat),
          const SizedBox(height: 20),
          _buildWorkloadBar(stats, montserrat),
        ],
      ),
    );
  }

  Widget _buildStatsRow(_ApprovalStats stats, TextStyle montserrat) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            icon: Icons.check_circle_outline,
            label: 'Total Approved',
            value: stats.totalApproved.toString(),
            montserrat: montserrat,
            color: const Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatChip(
            icon: Icons.cancel_outlined,
            label: 'Total Rejected',
            value: stats.totalRejected.toString(),
            montserrat: montserrat,
            color: const Color(0xFFC62828),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatChip(
            icon: Icons.trending_up,
            label: 'Quality Index',
            value: '${stats.qualityIndexPercent.toStringAsFixed(1)}%',
            montserrat: montserrat,
            color: AppColors.rosePrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsColumn(_ApprovalStats stats, TextStyle montserrat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatChip(
          icon: Icons.check_circle_outline,
          label: 'Total Approved',
          value: stats.totalApproved.toString(),
          montserrat: montserrat,
          color: const Color(0xFF2E7D32),
        ),
        const SizedBox(height: 12),
        _StatChip(
          icon: Icons.cancel_outlined,
          label: 'Total Rejected',
          value: stats.totalRejected.toString(),
          montserrat: montserrat,
          color: const Color(0xFFC62828),
        ),
        const SizedBox(height: 12),
        _StatChip(
          icon: Icons.trending_up,
          label: 'Quality Index',
          value: '${stats.qualityIndexPercent.toStringAsFixed(1)}%',
          montserrat: montserrat,
          color: AppColors.rosePrimary,
        ),
      ],
    );
  }

  Widget _buildWorkloadBar(_ApprovalStats stats, TextStyle montserrat) {
    final total = stats.total > 0 ? stats.total : 1;
    final pendingFraction = stats.totalPending / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Workload: Pending vs Total',
          style: montserrat.copyWith(fontSize: 12, color: AppColors.inkMuted),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: pendingFraction,
                  minHeight: 10,
                  backgroundColor: AppColors.rosePrimary.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE65100)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${stats.totalPending} / $total',
              style: montserrat.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _LegendDot(color: const Color(0xFFE65100), label: 'Pending', montserrat: montserrat),
            const SizedBox(width: 16),
            _LegendDot(color: AppColors.rosePrimary.withValues(alpha: 0.5), label: 'Processed', montserrat: montserrat),
          ],
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.montserrat,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final TextStyle montserrat;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: montserrat.copyWith(fontSize: 11, color: AppColors.inkMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: montserrat.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
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

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label, required this.montserrat});

  final Color color;
  final String label;
  final TextStyle montserrat;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: montserrat.copyWith(fontSize: 11, color: AppColors.inkMuted),
        ),
      ],
    );
  }
}

class _TabBadge extends ConsumerWidget {
  const _TabBadge({required this.providerKey});

  final _TabProviderKey providerKey;

  static const _labels = {
    _TabProviderKey.pending: 'Pending',
    _TabProviderKey.approved: 'Approved',
    _TabProviderKey.rejected: 'Rejected',
    _TabProviderKey.deleted: 'Deleted',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(_bouquetCountProvider(providerKey));
    return _TabWithBadge(label: _labels[providerKey]!, count: count);
  }
}

final _bouquetCountProvider = Provider.family<int, _TabProviderKey>((ref, key) {
  return switch (key) {
    _TabProviderKey.pending => ref.watch(
        _pendingPerfumesStreamProvider.select((a) => a.asData?.value.length ?? 0),
      ),
    _TabProviderKey.approved => ref.watch(
        _approvedPerfumesStreamProvider.select((a) => a.asData?.value.length ?? 0),
      ),
    _TabProviderKey.rejected => ref.watch(
        _rejectedPerfumesStreamProvider.select((a) => a.asData?.value.length ?? 0),
      ),
    _TabProviderKey.deleted => ref.watch(
        _deletedPerfumesStreamProvider.select((a) => a.asData?.value.length ?? 0),
      ),
  };
});

class _TabWithBadge extends StatelessWidget {
  const _TabWithBadge({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: GoogleFonts.montserrat()),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.rosePrimary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.rosePrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _TabContent extends ConsumerStatefulWidget {
  const _TabContent({
    required this.providerKey,
    required this.variant,
    required this.processingIds,
    required this.onApprove,
    required this.onReject,
    required this.onDeletePermanently,
    this.onSoftDelete,
    required this.emptyMessage,
  });

  final _TabProviderKey providerKey;
  final ApprovalCardVariant variant;
  final Set<String> processingIds;
  final ValueSetter<String> onApprove;
  final ValueSetter<String> onReject;
  final ValueSetter<FlowerModel> onDeletePermanently;
  final ValueSetter<String>? onSoftDelete;
  final String emptyMessage;

  @override
  ConsumerState<_TabContent> createState() => _TabContentState();
}

class _TabContentState extends ConsumerState<_TabContent> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final asyncList = ref.watch(switch (widget.providerKey) {
      _TabProviderKey.pending => _pendingPerfumesStreamProvider,
      _TabProviderKey.approved => _approvedPerfumesStreamProvider,
      _TabProviderKey.rejected => _rejectedPerfumesStreamProvider,
      _TabProviderKey.deleted => _deletedPerfumesStreamProvider,
    });

    return asyncList.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: (bouquets) {
        if (bouquets.isEmpty) {
          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.inkMuted.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: AppColors.inkMuted.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.emptyMessage,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      color: AppColors.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          key: PageStorageKey<String>('tab-${widget.providerKey.name}'),
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: bouquets.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final bouquet = bouquets[index];
            return BouquetApprovalCard(
              key: ValueKey(bouquet.id),
              bouquet: bouquet,
              variant: widget.variant,
              isProcessing: widget.processingIds.contains(bouquet.id),
              onApprove: () => widget.onApprove(bouquet.id),
              onReject: () => widget.onReject(bouquet.id),
              onDeletePermanently: () => widget.onDeletePermanently(bouquet),
              onSoftDelete: widget.onSoftDelete != null ? () => widget.onSoftDelete!(bouquet.id) : null,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.inkMuted.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: AppColors.inkMuted.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Unable to load perfumes.',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Back to Admin',
                onPressed: () => context.go('/admin'),
                variant: PrimaryButtonVariant.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

FlowerModel _perfumeFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final raw = doc.data() ?? <String, dynamic>{};
  final normalized = Map<String, dynamic>.from(raw);
  // Perfume payload uses `brand`; map to legacy model key for compatibility.
  normalized['occasion'] = normalized['brand'] ?? normalized['occasion'] ?? 'All';
  return FlowerModel.fromJson(doc.id, normalized);
}

/// Bucketing for Operational Overview, tab counts, and Approved list (missing/empty/unknown → approved).
String _normalizeApprovalBucketKey(Map<String, dynamic> data) {
  final raw = data['approvalStatus']?.toString();
  final s = (raw ?? 'approved').trim().toLowerCase();
  if (s.isEmpty) return 'approved';
  switch (s) {
    case 'pending':
    case 'rejected':
    case 'deleted':
      return s;
    case 'approved':
    default:
      return 'approved';
  }
}

Stream<List<FlowerModel>> _watchPerfumesByApprovalStatus(String approvalStatus) {
  final query = FirebaseFirestore.instance
      .collection('perfumes')
      .where('approvalStatus', isEqualTo: approvalStatus)
      .orderBy('createdAt', descending: true);
  return query.snapshots().map((snapshot) => snapshot.docs.map(_perfumeFromDoc).toList());
}

/// Approved tab must include legacy docs without [approvalStatus], matching Operational Overview counts.
Stream<List<FlowerModel>> _watchApprovedPerfumesList() {
  return FirebaseFirestore.instance.collection('perfumes').snapshots().map((snapshot) {
    final list = snapshot.docs
        .where((d) => _normalizeApprovalBucketKey(d.data()) == 'approved')
        .map(_perfumeFromDoc)
        .toList();
    list.sort(
      (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return list;
  });
}

final _pendingPerfumesStreamProvider = StreamProvider<List<FlowerModel>>((ref) {
  return _watchPerfumesByApprovalStatus('pending');
});

final _approvedPerfumesStreamProvider = StreamProvider<List<FlowerModel>>((ref) {
  return _watchApprovedPerfumesList();
});

final _rejectedPerfumesStreamProvider = StreamProvider<List<FlowerModel>>((ref) {
  return _watchPerfumesByApprovalStatus('rejected');
});

final _deletedPerfumesStreamProvider = StreamProvider<List<FlowerModel>>((ref) {
  return _watchPerfumesByApprovalStatus('deleted');
});

final _perfumeApprovalStatsStreamProvider = StreamProvider<_ApprovalStats>((ref) {
  return FirebaseFirestore.instance.collection('perfumes').snapshots().map((snapshot) {
    var totalApproved = 0;
    var totalRejected = 0;
    var totalPending = 0;
    var totalDeleted = 0;

    for (final doc in snapshot.docs) {
      switch (_normalizeApprovalBucketKey(doc.data())) {
        case 'pending':
          totalPending++;
          break;
        case 'rejected':
          totalRejected++;
          break;
        case 'deleted':
          totalDeleted++;
          break;
        case 'approved':
          totalApproved++;
          break;
      }
    }

    final total = totalApproved + totalRejected + totalPending + totalDeleted;
    final qualityIndexPercent = total > 0 ? (totalApproved / total * 100) : 0.0;
    return _ApprovalStats(
      totalApproved: totalApproved,
      totalRejected: totalRejected,
      totalPending: totalPending,
      total: total,
      qualityIndexPercent: qualityIndexPercent,
    );
  });
});
