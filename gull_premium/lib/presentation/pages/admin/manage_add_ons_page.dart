import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_format_utils.dart';
import '../../../controllers/controllers.dart';
import '../../../data/models/add_on_model.dart';
import '../../../data/repositories/repositories.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';

class ManageAddOnsPage extends ConsumerStatefulWidget {
  const ManageAddOnsPage({super.key});

  @override
  ConsumerState<ManageAddOnsPage> createState() => _ManageAddOnsPageState();
}

class _ManageAddOnsPageState extends ConsumerState<ManageAddOnsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _imagePicker = ImagePicker();

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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  AddOnType get _currentType {
    switch (_tabController.index) {
      case 0:
        return AddOnType.vase;
      case 1:
        return AddOnType.chocolate;
      default:
        return AddOnType.card;
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Access restricted. Sign in as admin.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Back to Admin',
          onPressed: () => context.go('/admin'),
          variant: PrimaryButtonVariant.outline,
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/admin'),
              tooltip: 'Back to dashboard',
            ),
            const SizedBox(width: 8),
            Text(
              'Manage Add-ons',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Add New Item',
              onPressed: () => _openAddEditDialog(context, type: _currentType),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TabBar(
          controller: _tabController,
          labelColor: AppColors.rose,
          unselectedLabelColor: AppColors.inkMuted,
          indicatorColor: AppColors.rose,
          tabs: const [
            Tab(text: 'Vases'),
            Tab(text: 'Chocolates'),
            Tab(text: 'Cards'),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _AddOnList(type: AddOnType.vase, onAdd: () => _openAddEditDialog(context, type: AddOnType.vase), onEdit: _openEditDialog, onDelete: _confirmDelete, showMessage: _showMessage),
              _AddOnList(type: AddOnType.chocolate, onAdd: () => _openAddEditDialog(context, type: AddOnType.chocolate), onEdit: _openEditDialog, onDelete: _confirmDelete, showMessage: _showMessage),
              _AddOnList(type: AddOnType.card, onAdd: () => _openAddEditDialog(context, type: AddOnType.card), onEdit: _openEditDialog, onDelete: _confirmDelete, showMessage: _showMessage),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openAddEditDialog(BuildContext context, {AddOnType? type, AddOnModel? existing}) async {
    final t = type ?? existing!.type;
    final result = await showDialog<AddOnModel?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddEditAddOnDialog(
        type: t,
        existing: existing,
        imagePicker: _imagePicker,
        addOnRepository: ref.read(addOnRepositoryProvider),
      ),
    );
    if (!mounted || result == null) return;
    _showMessage(existing == null ? 'Add-on created.' : 'Add-on updated.');
  }

  void _openEditDialog(AddOnModel addOn) {
    _openAddEditDialog(context, existing: addOn);
  }

  Future<void> _confirmDelete(AddOnModel addOn) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete add-on?'),
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
      _showMessage('Add-on deleted.');
    } on fa.FirebaseException catch (e) {
      _showMessage(e.message ?? 'Failed to delete.');
    } catch (_) {
      _showMessage('Failed to delete add-on.');
    }
  }
}

class _AddOnList extends ConsumerWidget {
  const _AddOnList({
    required this.type,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.showMessage,
  });

  final AddOnType type;
  final VoidCallback onAdd;
  final void Function(AddOnModel) onEdit;
  final void Function(AddOnModel) onDelete;
  final void Function(String) showMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminAddOnsByTypeProvider(type));
    return async.when(
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'No items yet.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Add New Item',
                  onPressed: onAdd,
                  variant: PrimaryButtonVariant.outline,
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            return _AddOnListTile(
              addOn: item,
              onEdit: () => onEdit(item),
              onDelete: () => onDelete(item),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Failed to load: $e',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
        ),
      ),
    );
  }
}

class _AddOnListTile extends StatelessWidget {
  const _AddOnListTile({
    required this.addOn,
    required this.onEdit,
    required this.onDelete,
  });

  final AddOnModel addOn;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: addOn.imageUrl.isEmpty
                ? Container(
                    width: 72,
                    height: 72,
                    color: AppColors.background,
                    child: const Icon(Icons.image_not_supported, color: AppColors.inkMuted),
                  )
                : Image.network(
                    addOn.imageUrl,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 72,
                      height: 72,
                      color: AppColors.background,
                      child: const Icon(Icons.broken_image, color: AppColors.inkMuted),
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
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (addOn.nameKu.isNotEmpty || addOn.nameAr.isNotEmpty)
                  Text(
                    '${addOn.nameKu.isNotEmpty ? addOn.nameKu : ''} ${addOn.nameAr.isNotEmpty ? addOn.nameAr : ''}'.trim(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
                  ),
                const SizedBox(height: 4),
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
    );
  }
}

class _AddEditAddOnDialog extends StatefulWidget {
  const _AddEditAddOnDialog({
    required this.type,
    required this.imagePicker,
    required this.addOnRepository,
    this.existing,
  });

  final AddOnType type;
  final AddOnModel? existing;
  final ImagePicker imagePicker;
  final AddOnRepository addOnRepository;

  @override
  State<_AddEditAddOnDialog> createState() => _AddEditAddOnDialogState();
}

class _AddEditAddOnDialogState extends State<_AddEditAddOnDialog> {
  final _nameEnController = TextEditingController();
  final _nameKuController = TextEditingController();
  final _nameArController = TextEditingController();
  final _priceController = TextEditingController();

  XFile? _pickedImage;
  Uint8List? _imageBytes;
  bool _saving = false;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameEnController.text = e.nameEn;
      _nameKuController.text = e.nameKu;
      _nameArController.text = e.nameAr;
      _priceController.text = e.priceIqd.toString();
    }
  }

  @override
  void dispose() {
    _nameEnController.dispose();
    _nameKuController.dispose();
    _nameArController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await widget.imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImage = file;
      _imageBytes = bytes;
    });
  }

  Future<void> _save() async {
    final nameEn = _nameEnController.text.trim();
    final nameKu = _nameKuController.text.trim();
    final nameAr = _nameArController.text.trim();
    final price = int.tryParse(_priceController.text.trim());

    if (nameEn.isEmpty) {
      _showMessage('Enter name (English).');
      return;
    }
    if (price == null || price < 0) {
      _showMessage('Enter a valid price (IQD).');
      return;
    }

    if (!isEdit && _imageBytes == null) {
      _showMessage('Please upload an image for the add-on.');
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = widget.addOnRepository;
      if (isEdit) {
        final existing = widget.existing!;
        String imageUrl = existing.imageUrl;
        if (_imageBytes != null) {
          imageUrl = await repo.uploadImage(addOnId: existing.id, bytes: _imageBytes!);
        }
        final updated = AddOnModel(
          id: existing.id,
          nameEn: nameEn,
          nameKu: nameKu,
          nameAr: nameAr,
          priceIqd: price,
          imageUrl: imageUrl,
          type: existing.type,
          isGlobal: existing.isGlobal,
          isActive: existing.isActive,
        );
        await repo.update(updated);
        if (!mounted) return;
        Navigator.of(context).pop(updated);
        return;
      }

      final newAddOn = AddOnModel(
        id: '', // will be set by create
        nameEn: nameEn,
        nameKu: nameKu,
        nameAr: nameAr,
        priceIqd: price,
        imageUrl: '',
        type: widget.type,
        isGlobal: true,
        isActive: true,
      );
      final id = await repo.create(newAddOn);
      String imageUrl = '';
      if (_imageBytes != null) {
        imageUrl = await repo.uploadImage(addOnId: id, bytes: _imageBytes!);
      }
      final created = AddOnModel(
        id: id,
        nameEn: nameEn,
        nameKu: nameKu,
        nameAr: nameAr,
        priceIqd: price,
        imageUrl: imageUrl,
        type: widget.type,
        isGlobal: true,
        isActive: true,
      );
      if (imageUrl.isNotEmpty) {
        await repo.update(created);
      }
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (mounted) _showMessage('Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Add-on' : 'Add New Add-on'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickImage,
                icon: const Icon(Icons.upload_file),
                label: Text(_pickedImage != null ? 'Image selected' : (existing?.imageUrl.isNotEmpty == true ? 'Change image' : 'Upload image')),
              ),
              if (_pickedImage != null || (existing?.imageUrl.isNotEmpty == true)) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _imageBytes != null
                      ? Image.memory(_imageBytes!, height: 120, width: double.infinity, fit: BoxFit.cover)
                      : existing != null && existing.imageUrl.isNotEmpty
                          ? Image.network(existing.imageUrl, height: 120, width: double.infinity, fit: BoxFit.cover)
                          : const SizedBox.shrink(),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _nameEnController,
                decoration: const InputDecoration(
                  labelText: 'Name (English)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameKuController,
                decoration: const InputDecoration(
                  labelText: 'Name (Kurdish)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameArController,
                decoration: const InputDecoration(
                  labelText: 'Name (Arabic)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (IQD)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        PrimaryButton(
          label: _saving ? 'Saving...' : 'Save',
          onPressed: _saving ? () {} : _save,
        ),
      ],
    );
  }
}
