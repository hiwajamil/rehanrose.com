import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_format_utils.dart';
import '../../../controllers/controllers.dart';
import '../../../data/models/add_on_model.dart';
import '../../widgets/admin/add_edit_add_on_dialog.dart';
import '../../widgets/common/app_cached_image.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';

/// Dedicated inventory screen for a single add-on category (Vases, Chocolates, or Cards).
/// Displays a grid of items with name, price, thumbnail. Prominent "+ Add New X" button.
class AddOnCategoryInventoryPage extends ConsumerStatefulWidget {
  const AddOnCategoryInventoryPage({
    super.key,
    required this.categoryType,
  });

  final AddOnType categoryType;

  static const Map<AddOnType, String> _routeSegments = {
    AddOnType.vase: 'vases',
    AddOnType.chocolate: 'chocolates',
    AddOnType.card: 'cards',
  };

  static void navigate(BuildContext context, AddOnType type) {
    final segment = _routeSegments[type] ?? 'vases';
    context.push('/admin/add-ons/$segment');
  }

  @override
  ConsumerState<AddOnCategoryInventoryPage> createState() =>
      _AddOnCategoryInventoryPageState();
}

class _AddOnCategoryInventoryPageState
    extends ConsumerState<AddOnCategoryInventoryPage> {
  final _imagePicker = ImagePicker();

  String get _categoryLabel {
    switch (widget.categoryType) {
      case AddOnType.vase:
        return 'Vase';
      case AddOnType.chocolate:
        return 'Chocolate';
      case AddOnType.card:
        return 'Card';
      default:
        return 'Item';
    }
  }

  String get _categoryLabelPlural {
    switch (widget.categoryType) {
      case AddOnType.vase:
        return 'Vases';
      case AddOnType.chocolate:
        return 'Chocolates';
      case AddOnType.card:
        return 'Cards';
      default:
        return 'Items';
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAddDialog() async {
    final result = await showDialog<AddOnModel?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AddEditAddOnDialog(
        type: widget.categoryType,
        imagePicker: _imagePicker,
        addOnRepository: ref.read(addOnRepositoryProvider),
      ),
    );
    if (!mounted || result == null) return;
    _showMessage('$_categoryLabel added.');
  }

  Future<void> _openEditDialog(AddOnModel addOn) async {
    final result = await showDialog<AddOnModel?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AddEditAddOnDialog(
        type: addOn.type,
        existing: addOn,
        imagePicker: _imagePicker,
        addOnRepository: ref.read(addOnRepositoryProvider),
      ),
    );
    if (!mounted || result == null) return;
    _showMessage('$_categoryLabel updated.');
  }

  Future<void> _confirmDelete(AddOnModel addOn) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $_categoryLabel?'),
        content: Text(
          'Delete "${addOn.nameEn}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await ref.read(addOnRepositoryProvider).delete(addOn.id);
      _showMessage('$_categoryLabel deleted.');
    } on fa.FirebaseException catch (e) {
      _showMessage(e.message ?? 'Failed to delete.');
    } catch (_) {
      _showMessage('Failed to delete $_categoryLabel.');
    }
  }

  Future<void> _toggleActive(AddOnModel addOn) async {
    try {
      final updated = AddOnModel(
        id: addOn.id,
        nameEn: addOn.nameEn,
        nameKu: addOn.nameKu,
        nameAr: addOn.nameAr,
        priceIqd: addOn.priceIqd,
        imageUrl: addOn.imageUrl,
        type: addOn.type,
        isGlobal: addOn.isGlobal,
        isActive: !addOn.isActive,
      );
      await ref.read(addOnRepositoryProvider).update(updated);
      if (mounted) {
        _showMessage(addOn.isActive ? '$_categoryLabel disabled.' : '$_categoryLabel enabled.');
      }
    } on fa.FirebaseException catch (e) {
      _showMessage(e.message ?? 'Failed to update.');
    } catch (_) {
      _showMessage('Failed to update $_categoryLabel.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    final addOnsAsync = ref.watch(adminAddOnsByTypeProvider(widget.categoryType));
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    final playfair = GoogleFonts.playfairDisplay(
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    );

    return AppScaffold(
      child: SectionContainer(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 20 : 48,
          vertical: isMobile ? 24 : 40,
        ),
        child: authAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _buildAccessDenied(context),
          data: (user) {
            if (user == null) return _buildAccessDenied(context);
            return FutureBuilder<bool>(
              future: () async {
                final authRepo = ref.read(authRepositoryProvider);
                final ok = await authRepo.isAdmin(user.uid);
                if (ok) await authRepo.ensureSuperAdminUserDoc(user.uid);
                return ok;
              }(),
              builder: (context, adminSnapshot) {
                if (adminSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (adminSnapshot.data != true) return _buildAccessDenied(context);
                return _buildContent(
                  context,
                  addOnsAsync,
                  playfair,
                  isMobile,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildAccessDenied(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Access restricted. Sign in as admin.',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => context.pop(),
          child: const Text('Back to Admin'),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    AsyncValue<List<AddOnModel>> addOnsAsync,
    TextStyle playfair,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                    tooltip: 'Back to Manage Add-ons',
                    style: IconButton.styleFrom(foregroundColor: AppColors.ink),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Manage $_categoryLabelPlural',
                      style: playfair.copyWith(fontSize: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openAddDialog,
                  icon: const Icon(Icons.add, size: 20),
                  label: Text('Add New $_categoryLabel'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rosePrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
                tooltip: 'Back to Manage Add-ons',
                style: IconButton.styleFrom(foregroundColor: AppColors.ink),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Manage $_categoryLabelPlural',
                  style: playfair.copyWith(fontSize: 26),
                ),
              ),
              FilledButton.icon(
                onPressed: _openAddDialog,
                icon: const Icon(Icons.add, size: 20),
                label: Text('Add New $_categoryLabel'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rosePrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),
        addOnsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Text(
                'Failed to load: $e',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.inkMuted),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (list) {
            if (list.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: AppColors.inkMuted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No $_categoryLabelPlural yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your first $_categoryLabel to get started',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _openAddDialog,
                      icon: const Icon(Icons.add, size: 20),
                      label: Text('Add New $_categoryLabel'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rosePrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return isMobile
                ? _buildListMobile(context, list)
                : _buildGridDesktop(context, list);
          },
        ),
      ],
    );
  }

  Widget _buildListMobile(BuildContext context, List<AddOnModel> list) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _InventoryCard(
            addOn: item,
            onEdit: () => _openEditDialog(item),
            onDelete: () => _confirmDelete(item),
            onToggleActive: () => _toggleActive(item),
          ),
        );
      },
    );
  }

  Widget _buildGridDesktop(BuildContext context, List<AddOnModel> list) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 3
            : (constraints.maxWidth > 600 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: 2.2,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            return _InventoryCard(
              addOn: item,
              onEdit: () => _openEditDialog(item),
              onDelete: () => _confirmDelete(item),
              onToggleActive: () => _toggleActive(item),
            );
          },
        );
      },
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.addOn,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final AddOnModel addOn;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;

    return Opacity(
      opacity: addOn.isActive ? 1 : 0.65,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isMobile ? _buildMobileLayout(context) : _buildDesktopLayout(context),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: addOn.imageUrl.isEmpty
                  ? Container(
                      width: 72,
                      height: 72,
                      color: AppColors.background,
                      child: const Icon(
                        Icons.image_not_supported,
                        color: AppColors.inkMuted,
                        size: 28,
                      ),
                    )
                  : SizedBox(
                      width: 72,
                      height: 72,
                      child: AppCachedImage(
                        imageUrl: addOn.imageUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorIconSize: 28,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    addOn.nameEn,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                  ),
                  if (addOn.nameKu.isNotEmpty || addOn.nameAr.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${addOn.nameKu.isNotEmpty ? addOn.nameKu : ''} ${addOn.nameAr.isNotEmpty ? addOn.nameAr : ''}'
                            .trim(),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.inkMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    '${formatPriceIqd(addOn.priceIqd)} IQD',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.rose,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Active', style: Theme.of(context).textTheme.bodySmall),
            Switch(
              value: addOn.isActive,
              onChanged: (_) => onToggleActive(),
              activeTrackColor: AppColors.rose.withValues(alpha: 0.5),
              activeThumbColor: AppColors.rose,
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
              tooltip: 'Delete',
              style: IconButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: addOn.imageUrl.isEmpty
              ? Container(
                  width: 80,
                  height: 80,
                  color: AppColors.background,
                  child: const Icon(
                    Icons.image_not_supported,
                    color: AppColors.inkMuted,
                    size: 32,
                  ),
                )
              : SizedBox(
                  width: 80,
                  height: 80,
                  child: AppCachedImage(
                    imageUrl: addOn.imageUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorIconSize: 28,
                  ),
                ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                addOn.nameEn,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
              ),
              if (addOn.nameKu.isNotEmpty || addOn.nameAr.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${addOn.nameKu.isNotEmpty ? addOn.nameKu : ''} ${addOn.nameAr.isNotEmpty ? addOn.nameAr : ''}'
                        .trim(),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                '${formatPriceIqd(addOn.priceIqd)} IQD',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.rose,
                    ),
              ),
            ],
          ),
        ),
        Switch(
          value: addOn.isActive,
          onChanged: (_) => onToggleActive(),
          activeTrackColor: AppColors.rose.withValues(alpha: 0.5),
          activeThumbColor: AppColors.rose,
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: onEdit,
          tooltip: 'Edit',
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
          tooltip: 'Delete',
          style: IconButton.styleFrom(foregroundColor: Colors.red),
        ),
      ],
    );
  }
}
