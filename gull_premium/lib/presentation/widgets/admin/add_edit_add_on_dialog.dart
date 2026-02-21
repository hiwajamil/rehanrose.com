import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/add_on_model.dart';
import '../../../data/repositories/add_on_repository.dart';
import '../../widgets/common/app_cached_image.dart';
import '../common/primary_button.dart';

/// Modal dialog for creating or editing an add-on (Name, Price, Image Upload).
class AddEditAddOnDialog extends StatefulWidget {
  const AddEditAddOnDialog({
    super.key,
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
  State<AddEditAddOnDialog> createState() => _AddEditAddOnDialogState();
}

class _AddEditAddOnDialogState extends State<AddEditAddOnDialog> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  XFile? _pickedImage;
  Uint8List? _imageBytes;
  bool _saving = false;
  bool _isActive = true;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameController.text = e.nameEn;
      _priceController.text = e.priceIqd.toString();
      _isActive = e.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await widget.imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImage = file;
      _imageBytes = bytes;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final price = int.tryParse(_priceController.text.trim());

    if (name.isEmpty) {
      _showMessage('Enter the add-on name.');
      return;
    }
    if (price == null || price < 0) {
      _showMessage('Enter a valid price (IQD).');
      return;
    }

    if (!isEdit && _imageBytes == null) {
      _showMessage('Please pick an image for the add-on.');
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = widget.addOnRepository;
      if (isEdit) {
        final existing = widget.existing!;
        String imageUrl = existing.imageUrl;
        if (_imageBytes != null) {
          imageUrl =
              await repo.uploadImage(addOnId: existing.id, bytes: _imageBytes!);
        }
        final updated = AddOnModel(
          id: existing.id,
          nameEn: name,
          nameKu: '',
          nameAr: '',
          priceIqd: price,
          imageUrl: imageUrl,
          type: existing.type,
          isGlobal: true,
          isActive: _isActive,
        );
        await repo.update(updated);
        if (!mounted) return;
        Navigator.of(context).pop(updated);
        return;
      }

      final newAddOn = AddOnModel(
        id: '',
        nameEn: name,
        nameKu: '',
        nameAr: '',
        priceIqd: price,
        imageUrl: '',
        type: widget.type,
        isGlobal: true,
        isActive: _isActive,
      );
      final id = await repo.create(newAddOn);
      String imageUrl = '';
      if (_imageBytes != null) {
        imageUrl = await repo.uploadImage(addOnId: id, bytes: _imageBytes!);
      }
      final created = AddOnModel(
        id: id,
        nameEn: name,
        nameKu: '',
        nameAr: '',
        priceIqd: price,
        imageUrl: imageUrl,
        type: widget.type,
        isGlobal: true,
        isActive: _isActive,
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

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: TextStyle(color: AppColors.inkMuted.withValues(alpha: 0.7)),
        labelStyle: TextStyle(color: AppColors.inkMuted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.rose, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      );

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final categoryLabel = _categoryLabel(widget.type);
    final hasImage = _pickedImage != null ||
        (existing?.imageUrl.isNotEmpty == true);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 420,
        constraints: const BoxConstraints(maxHeight: 560),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.12),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Text(
                isEdit ? 'Edit $categoryLabel' : 'Add New $categoryLabel',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      letterSpacing: -0.3,
                    ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: _saving ? null : _pickImage,
                      child: Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: hasImage
                                ? AppColors.border
                                : AppColors.inkMuted.withValues(alpha: 0.3),
                            width: hasImage ? 1 : 2,
                            strokeAlign: BorderSide.strokeAlignInside,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: _imageBytes != null
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(
                                      _imageBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: _buildChangeImageChip(),
                                    ),
                                  ],
                                )
                              : existing != null && existing.imageUrl.isNotEmpty
                                  ? Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        AppCachedImage(
                                          imageUrl: existing.imageUrl,
                                          fit: BoxFit.cover,
                                          errorIconSize: 48,
                                        ),
                                        Positioned(
                                          bottom: 8,
                                          right: 8,
                                          child: _buildChangeImageChip(),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 48,
                                          color: AppColors.inkMuted
                                              .withValues(alpha: 0.6),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Add photo',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: AppColors.inkMuted,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ],
                                    ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _nameController,
                      decoration: _inputDecoration('Name'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _priceController,
                      decoration: _inputDecoration('Price (IQD)'),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isActive
                            ? AppColors.sage.withValues(alpha: 0.15)
                            : AppColors.inkMuted.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isActive
                              ? AppColors.sage.withValues(alpha: 0.4)
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isActive ? Icons.check_circle : Icons.remove_circle_outline,
                            size: 22,
                            color: _isActive ? AppColors.sage : AppColors.inkMuted,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'In Stock',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isActive
                                      ? 'Visible to customers'
                                      : 'Hidden from customers',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppColors.inkMuted,
                                        fontSize: 12,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isActive,
                            onChanged: (v) => setState(() => _isActive = v),
                            activeTrackColor: AppColors.sage.withValues(alpha: 0.6),
                            activeThumbColor: AppColors.sage,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  PrimaryButton(
                    label: _saving ? 'Saving...' : 'Save',
                    onPressed: _saving ? () {} : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangeImageChip() {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: _saving ? null : _pickImage,
        borderRadius: BorderRadius.circular(20),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            'Change',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  String _categoryLabel(AddOnType type) {
    switch (type) {
      case AddOnType.vase:
        return 'Vase';
      case AddOnType.chocolate:
        return 'Chocolate';
      case AddOnType.card:
        return 'Card';
      default:
        return 'Add-on';
    }
  }
}
