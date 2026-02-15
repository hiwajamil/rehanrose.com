import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/emotion_categories.dart';
import '../../../core/theme/app_colors.dart';
import '../../../controllers/controllers.dart';
import '../../../data/models/flower_model.dart';
import '../../widgets/common/app_cached_image.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/layout/section_container.dart';

/// List all vendor bouquets: image, name, occasion, price (IQD), status, Edit/Delete.
/// If [code] query param is set, show only the bouquet with that code (published);
/// if none match, show "There is no bouquet with that code."
/// Supports multi-select and bulk delete.
class VendorBouquetsPage extends ConsumerStatefulWidget {
  const VendorBouquetsPage({super.key});

  @override
  ConsumerState<VendorBouquetsPage> createState() => _VendorBouquetsPageState();
}

class _VendorBouquetsPageState extends ConsumerState<VendorBouquetsPage> {
  final Set<String> _selectedIds = {};

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _bulkDelete(WidgetRef ref, List<String> ids) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete ${ids.length} bouquet${ids.length == 1 ? '' : 's'}?'),
        content: Text(
          ids.length == 1
              ? 'This bouquet will be removed from the storefront.'
              : 'These bouquets will be removed from the storefront.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppColors.inkMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _selectedIds.clear());
    final notifier = ref.read(vendorControllerProvider.notifier);
    for (final id in ids) {
      await notifier.deleteBouquet(id);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ids.length} bouquet${ids.length == 1 ? '' : 's'} deleted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bouquetsAsync = ref.watch(vendorBouquetsStreamProvider);
    final user = ref.watch(authStateProvider).value;
    final codeQuery =
        GoRouterState.of(context).uri.queryParameters['code']?.trim() ?? '';

    return SingleChildScrollView(
      child: SectionContainer(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bouquets',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        codeQuery.isEmpty
                            ? 'Manage your bouquets. Edit or delete below. Select multiple to delete at once.'
                            : 'Search by code: "$codeQuery"',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.inkMuted,
                            ),
                      ),
                    ],
                  ),
                ),
                if (codeQuery.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => context.go('/vendor/bouquets'),
                    icon: const Icon(Icons.clear, size: 18, color: AppColors.inkMuted),
                    label: Text(
                      'Clear search',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                    ),
                  ),
              ],
            ),
            if (_selectedIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Text(
                      '${_selectedIds.length} selected',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _selectedIds.clear()),
                      child: Text('Clear', style: TextStyle(color: AppColors.inkMuted)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: user == null
                          ? null
                          : () => _bulkDelete(ref, _selectedIds.toList()),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete selected'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            bouquetsAsync.when(
              loading: () => const Center(
                  child: Padding(
                      padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
              error: (_, __) => _EmptyState(
                icon: Icons.error_outline,
                message: 'Unable to load bouquets.',
              ),
              data: (bouquets) {
                List<FlowerModel> toShow = bouquets;
                if (codeQuery.isNotEmpty) {
                  toShow = bouquets
                      .where((b) =>
                          b.bouquetCode.trim().toLowerCase() ==
                          codeQuery.toLowerCase())
                      .toList();
                  if (toShow.isEmpty) {
                    return _EmptyState(
                      icon: Icons.search_off,
                      message: 'There is no bouquet with that code.',
                    );
                  }
                }
                if (toShow.isEmpty) {
                  return _EmptyState(
                    icon: Icons.local_florist_outlined,
                    message: 'No bouquets yet. Add one from the sidebar.',
                  );
                }
                return Column(
                  children: toShow
                      .map((b) => _BouquetCard(
                            bouquet: b,
                            user: user!,
                            ref: ref,
                            isSelected: _selectedIds.contains(b.id),
                            onToggleSelect: () => _toggleSelection(b.id),
                            onEdit: () => _showEditSheet(context, ref, user, b),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static void _showEditSheet(
      BuildContext context, WidgetRef ref, fa.User user, FlowerModel bouquet) {
    final priceController = TextEditingController(text: '${bouquet.priceIqd}');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewPadding.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 26,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit bouquet', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 20),
            Text(
              'Price (IQD)',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '45000',
                prefixIcon: const Icon(Icons.payments_outlined,
                    color: AppColors.inkMuted),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Change Price',
              onPressed: () async {
                final price = int.tryParse(priceController.text.trim());
                if (price == null) return;
                Navigator.of(ctx).pop();
                await ref
                    .read(vendorControllerProvider.notifier)
                    .updateBouquetPrice(bouquet.id, price);
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Price updated.')));
                }
              },
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Replace photo',
              onPressed: () async {
                Navigator.of(ctx).pop();
                final images = await ImagePicker().pickMultiImage();
                if (images.isEmpty) return;
                await ref
                    .read(vendorControllerProvider.notifier)
                    .replaceBouquetPhotos(
                      user: user,
                      bouquetId: bouquet.id,
                      imageFiles: images.take(3).toList(),
                    );
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Photos updated.')));
                }
              },
              variant: PrimaryButtonVariant.outline,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: ctx,
                  builder: (c) => AlertDialog(
                    title: const Text('Delete bouquet?'),
                    content: const Text(
                      'This bouquet will be removed from the storefront.',
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(c).pop(false),
                          child: Text('Cancel',
                              style: TextStyle(color: AppColors.inkMuted))),
                      TextButton(
                          onPressed: () => Navigator.of(c).pop(true),
                          child: const Text('Delete',
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true && ctx.mounted) {
                  Navigator.of(ctx).pop();
                  await ref
                      .read(vendorControllerProvider.notifier)
                      .deleteBouquet(bouquet.id);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Bouquet deleted.')));
                  }
                }
              },
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              label: const Text('Delete',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    ).whenComplete(priceController.dispose);
  }

}

class _BouquetCard extends StatelessWidget {
  final FlowerModel bouquet;
  final fa.User user;
  final WidgetRef ref;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final VoidCallback onEdit;

  const _BouquetCard({
    required this.bouquet,
    required this.user,
    required this.ref,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onEdit,
  });

  Widget _selectionCheckbox(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggleSelect,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 28,
            height: 28,
            child: Checkbox(
              value: isSelected,
              onChanged: (_) => onToggleSelect(),
              activeColor: AppColors.sage,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = bouquet.listingImageUrl.isNotEmpty
        ? bouquet.listingImageUrl
        : 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=400&q=80';
    final isNarrow = MediaQuery.sizeOf(context).width < 500;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.sage.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? AppColors.sage : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: isNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _selectionCheckbox(context),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: AppCachedImage(
                          imageUrl: imageUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorIconSize: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(bouquet.name,
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            'IQD ${bouquet.priceIqd}',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      labelForEmotionValue(bouquet.occasion),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.inkMuted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (bouquet.bouquetCode.isNotEmpty)
                      Text(
                        bouquet.bouquetCode,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.inkMuted,
                            ),
                      ),
                    _StatusBadge(status: bouquet.status),
                  ],
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Edit',
                  onPressed: onEdit,
                  variant: PrimaryButtonVariant.outline,
                ),
              ],
            )
          : Row(
              children: [
                _selectionCheckbox(context),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 86,
                    height: 86,
                    child: AppCachedImage(
                      imageUrl: imageUrl,
                      width: 86,
                      height: 86,
                      fit: BoxFit.cover,
                      errorIconSize: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(bouquet.name,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        labelForEmotionValue(bouquet.occasion),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.inkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (bouquet.bouquetCode.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          bouquet.bouquetCode,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.inkMuted,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  'IQD ${bouquet.priceIqd}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: bouquet.status),
                const SizedBox(width: 12),
                PrimaryButton(
                  label: 'Edit',
                  onPressed: onEdit,
                  variant: PrimaryButtonVariant.outline,
                ),
              ],
            ),
    );
  }
}

/// Badge for product approval status: Yellow = Pending Review, Green = Live, Red = Rejected.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (String label, Color bgColor, Color textColor) = switch (status) {
      'pending' => (
          'Pending Review',
          Colors.amber.shade100,
          Colors.amber.shade900,
        ),
      'approved' => (
          'Live',
          AppColors.sage.withValues(alpha: 0.3),
          AppColors.ink,
        ),
      'rejected' => (
          'Rejected',
          Colors.red.shade100,
          Colors.red.shade900,
        ),
      _ => (
          status,
          AppColors.sage.withValues(alpha: 0.3),
          AppColors.ink,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppColors.inkMuted),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.inkMuted,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
