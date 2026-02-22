import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/breakpoints.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../controllers/controllers.dart';
import '../../../data/models/flower_model.dart';
import '../../widgets/admin/bouquet_approval/bouquet_approval.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';

/// Admin page for Bouquet Approval System. Tab-based UI: Pending, Approved, Rejected.
class BouquetApprovalPage extends ConsumerStatefulWidget {
  const BouquetApprovalPage({super.key});

  @override
  ConsumerState<BouquetApprovalPage> createState() => _BouquetApprovalPageState();
}

class _BouquetApprovalPageState extends ConsumerState<BouquetApprovalPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    if (user != null &&
        user.email?.trim().toLowerCase() == kSuperAdminEmail.trim().toLowerCase()) {
      await ref.read(authRepositoryProvider).ensureSuperAdminUserDoc(user.uid);
    }
  }

  Future<void> _approve(String bouquetId) async {
    setState(() => _processingIds.add(bouquetId));
    try {
      await _ensureSuperAdmin();
      await ref.read(bouquetRepositoryProvider).updateApprovalStatus(bouquetId, 'approved');
      if (mounted) _showMessage('Bouquet approved. It will appear on the main screen.');
    } catch (e, st) {
      if (mounted) {
        debugPrint('Approve bouquet error: $e $st');
        _showMessage('Unable to approve bouquet. Please try again.');
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
      await ref.read(bouquetRepositoryProvider).updateApprovalStatus(
            bouquetId,
            'rejected',
            rejectionReason: rejectionReason,
            rejectionNote: rejectionNote.isNotEmpty ? rejectionNote : null,
          );
      if (mounted) _showMessage('Bouquet rejected. Vendor will see the reason.');
    } catch (e, st) {
      if (mounted) {
        debugPrint('Reject bouquet error: $e $st');
        _showMessage('Unable to reject bouquet. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(bouquetId));
    }
  }

  Future<void> _deletePermanently(String bouquetId) async {
    setState(() => _processingIds.add(bouquetId));
    try {
      await ref.read(bouquetRepositoryProvider).deleteBouquetPermanently(bouquetId);
      if (mounted) _showMessage('Bouquet deleted permanently.');
    } catch (e, st) {
      if (mounted) {
        debugPrint('Delete bouquet error: $e $st');
        _showMessage('Unable to delete bouquet. Please try again.');
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
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    return AppScaffold(
      child: SectionContainer(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 48,
          vertical: isMobile ? 20 : 32,
        ),
        child: authAsync.when(
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
        ),
      ),
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
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bouquet Approval',
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
                'Bouquet Approval',
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
          'Review and manage vendor bouquets by status.',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 24),
        _OperationalOverview(isMobile: isMobile),
        const SizedBox(height: 24),
        TabBar(
          controller: _tabController,
          isScrollable: isMobile,
          labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.montserrat(),
          indicatorColor: AppColors.rosePrimary,
          labelColor: AppColors.ink,
          tabs: const [
            Tab(child: _TabBadge(providerKey: _TabProviderKey.pending)),
            Tab(child: _TabBadge(providerKey: _TabProviderKey.approved)),
            Tab(child: _TabBadge(providerKey: _TabProviderKey.rejected)),
          ],
        ),
        const SizedBox(height: 16),
        RepaintBoundary(
          child: SizedBox(
            height: (MediaQuery.sizeOf(context).height - 280).clamp(400.0, 1200.0),
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
                  emptyMessage: 'No pending bouquets.',
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
                  emptyMessage: 'No approved bouquets.',
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
                  emptyMessage: 'No rejected bouquets.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _TabProviderKey { pending, approved, rejected }

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
  final pending = ref.watch(pendingBouquetsStreamProvider);
  final approved = ref.watch(approvedBouquetsStreamProvider);
  final rejected = ref.watch(rejectedBouquetsStreamProvider);

  if (pending.isLoading || approved.isLoading || rejected.isLoading) {
    return const AsyncValue.loading();
  }
  if (pending.hasError) return AsyncValue.error(pending.error!, pending.stackTrace ?? StackTrace.current);
  if (approved.hasError) return AsyncValue.error(approved.error!, approved.stackTrace ?? StackTrace.current);
  if (rejected.hasError) return AsyncValue.error(rejected.error!, rejected.stackTrace ?? StackTrace.current);

  final p = pending.asData?.value ?? <FlowerModel>[];
  final a = approved.asData?.value ?? <FlowerModel>[];
  final r = rejected.asData?.value ?? <FlowerModel>[];
  final total = p.length + a.length + r.length;
  final qualityIndexPercent = total > 0 ? (a.length / total * 100) : 0.0;

  return AsyncValue.data(_ApprovalStats(
    totalApproved: a.length,
    totalRejected: r.length,
    totalPending: p.length,
    total: total,
    qualityIndexPercent: qualityIndexPercent,
  ));
});

/// Minimalist Approval Statistics: Total Approved, Total Rejected, Quality Index, and workload progress.
class _OperationalOverview extends ConsumerWidget {
  const _OperationalOverview({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_approvalStatsProvider);
    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        final montserrat = GoogleFonts.montserrat();
        final playfair = GoogleFonts.playfairDisplay(
          fontSize: isMobile ? 18 : 20,
          fontWeight: FontWeight.bold,
          color: AppColors.ink,
        );
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Operational Overview', style: playfair),
              const SizedBox(height: 16),
              if (isMobile)
                _buildStatsColumn(stats, montserrat)
              else
                _buildStatsRow(stats, montserrat),
              const SizedBox(height: 16),
              _buildWorkloadBar(stats, montserrat),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsRow(_ApprovalStats stats, TextStyle montserrat) {
    return Row(
      children: [
        _StatChip(
          label: 'Total Approved',
          value: stats.totalApproved.toString(),
          montserrat: montserrat,
          color: const Color(0xFF2E7D32),
        ),
        const SizedBox(width: 16),
        _StatChip(
          label: 'Total Rejected',
          value: stats.totalRejected.toString(),
          montserrat: montserrat,
          color: const Color(0xFFC62828),
        ),
        const SizedBox(width: 16),
        _StatChip(
          label: 'Quality Index',
          value: '${stats.qualityIndexPercent.toStringAsFixed(1)}%',
          montserrat: montserrat,
          color: AppColors.rosePrimary,
        ),
      ],
    );
  }

  Widget _buildStatsColumn(_ApprovalStats stats, TextStyle montserrat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatChip(
          label: 'Total Approved',
          value: stats.totalApproved.toString(),
          montserrat: montserrat,
          color: const Color(0xFF2E7D32),
        ),
        const SizedBox(height: 8),
        _StatChip(
          label: 'Total Rejected',
          value: stats.totalRejected.toString(),
          montserrat: montserrat,
          color: const Color(0xFFC62828),
        ),
        const SizedBox(height: 8),
        _StatChip(
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
    required this.label,
    required this.value,
    required this.montserrat,
    required this.color,
  });

  final String label;
  final String value;
  final TextStyle montserrat;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: montserrat.copyWith(fontSize: 11, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 2),
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
        pendingBouquetsStreamProvider.select((a) => a.asData?.value.length ?? 0),
      ),
    _TabProviderKey.approved => ref.watch(
        approvedBouquetsStreamProvider.select((a) => a.asData?.value.length ?? 0),
      ),
    _TabProviderKey.rejected => ref.watch(
        rejectedBouquetsStreamProvider.select((a) => a.asData?.value.length ?? 0),
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

class _TabContent extends ConsumerWidget {
  const _TabContent({
    required this.providerKey,
    required this.variant,
    required this.processingIds,
    required this.onApprove,
    required this.onReject,
    required this.onDeletePermanently,
    required this.emptyMessage,
  });

  final _TabProviderKey providerKey;
  final ApprovalCardVariant variant;
  final Set<String> processingIds;
  final ValueSetter<String> onApprove;
  final ValueSetter<String> onReject;
  final ValueSetter<FlowerModel> onDeletePermanently;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamAsync = switch (providerKey) {
      _TabProviderKey.pending => ref.watch(pendingBouquetsStreamProvider),
      _TabProviderKey.approved => ref.watch(approvedBouquetsStreamProvider),
      _TabProviderKey.rejected => ref.watch(rejectedBouquetsStreamProvider),
    };
    return streamAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Unable to load bouquets.',
              style: GoogleFonts.montserrat(color: AppColors.inkMuted),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Back to Admin',
              onPressed: () => context.go('/admin'),
              variant: PrimaryButtonVariant.outline,
            ),
          ],
        ),
      ),
      data: (bouquets) {
        if (bouquets.isEmpty) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                emptyMessage,
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: bouquets.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final bouquet = bouquets[index];
            return BouquetApprovalCard(
              key: ValueKey(bouquet.id),
              bouquet: bouquet,
              variant: variant,
              isProcessing: processingIds.contains(bouquet.id),
              onApprove: () => onApprove(bouquet.id),
              onReject: () => onReject(bouquet.id),
              onDeletePermanently: () => onDeletePermanently(bouquet),
            );
          },
        );
      },
    );
  }
}
