import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_format_utils.dart';
import '../../../controllers/controllers.dart';
import '../../../data/models/flower_model.dart';
import '../../../data/models/vendor_list_model.dart';
import '../../widgets/common/app_cached_image.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';

/// Admin page to approve or reject pending vendor products (bouquets).
/// Shows only products where status == 'pending'.
class AdminProductApprovalPage extends ConsumerStatefulWidget {
  const AdminProductApprovalPage({super.key});

  @override
  ConsumerState<AdminProductApprovalPage> createState() =>
      _AdminProductApprovalPageState();
}

class _AdminProductApprovalPageState
    extends ConsumerState<AdminProductApprovalPage> {
  final Set<String> _processingIds = {};

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _approve(String bouquetId) async {
    setState(() => _processingIds.add(bouquetId));
    try {
      await ref
          .read(bouquetRepositoryProvider)
          .updateApprovalStatus(bouquetId, 'approved');
      if (mounted) {
        _showMessage('Bouquet approved. It will appear on the main screen.');
      }
    } catch (_) {
      if (mounted) _showMessage('Unable to approve bouquet.');
    } finally {
      if (mounted) setState(() => _processingIds.remove(bouquetId));
    }
  }

  Future<void> _reject(String bouquetId) async {
    setState(() => _processingIds.add(bouquetId));
    try {
      await ref
          .read(bouquetRepositoryProvider)
          .updateApprovalStatus(bouquetId, 'rejected');
      if (mounted) _showMessage('Bouquet rejected.');
    } catch (_) {
      if (mounted) _showMessage('Unable to reject bouquet.');
    } finally {
      if (mounted) setState(() => _processingIds.remove(bouquetId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    return AppScaffold(
      child: SectionContainer(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
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
          Text(
            'Access restricted',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
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
    final pendingAsync = ref.watch(pendingBouquetsStreamProvider);

    return pendingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Unable to load pending bouquets.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.inkMuted),
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
      data: (pendingBouquets) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Pending Bouquets',
                    style: Theme.of(context).textTheme.headlineMedium,
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
                'Vendor bouquets waiting for approval. Approve to show on the main screen.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkMuted,
                    ),
              ),
              const SizedBox(height: 24),
              if (pendingBouquets.isEmpty)
                Container(
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Text(
                      'No pending bouquets.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount =
                        constraints.maxWidth > 700 ? 2 : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisExtent: 220,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: pendingBouquets.length,
                      itemBuilder: (context, index) {
                        final bouquet = pendingBouquets[index];
                        return _PendingCard(
                          bouquet: bouquet,
                          isProcessing: _processingIds.contains(bouquet.id),
                          onApprove: () => _approve(bouquet.id),
                          onReject: () => _reject(bouquet.id),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PendingCard extends ConsumerWidget {
  const _PendingCard({
    required this.bouquet,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  final FlowerModel bouquet;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorAsync = bouquet.vendorId != null
        ? ref.watch(vendorByIdProvider(bouquet.vendorId!))
        : const AsyncValue<VendorListModel?>.data(null);

    final vendorName = vendorAsync.value?.shopName ??
        bouquet.vendorId ??
        '—';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: bouquet.listingImageUrl.isNotEmpty
                      ? AppCachedImage(
                          imageUrl: bouquet.listingImageUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorIconSize: 28,
                        )
                      : const Icon(Icons.image_not_supported, size: 36),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bouquet.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      iqdPriceString(bouquet.priceIqd),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vendorName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: isProcessing ? null : onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isProcessing ? 'Working…' : 'Approve'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: isProcessing ? null : onReject,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isProcessing ? 'Working…' : 'Reject'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
