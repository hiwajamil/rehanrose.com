import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/emotion_categories.dart';
import '../../../core/theme/app_colors.dart';
import '../../../controllers/controllers.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/layout/section_container.dart';

/// Add new bouquet: name, emotion, price (IQD), max 3 images, description, availability.
/// Bouquet ID is auto-generated (e.g. Bi-1, We-1, Th-1) per emotion.
class VendorAddBouquetPage extends ConsumerStatefulWidget {
  const VendorAddBouquetPage({super.key});

  @override
  ConsumerState<VendorAddBouquetPage> createState() =>
      _VendorAddBouquetPageState();
}

class _VendorAddBouquetPageState extends ConsumerState<VendorAddBouquetPage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String? _selectedEmotionValue;
  String? _emotionError;
  List<XFile> _images = [];
  bool _available = true;
  bool _submitting = false;
  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _message(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickImages() async {
    final picked = await _imagePicker.pickMultiImage();
    if (picked.isEmpty) return;
    setState(() => _images = picked.take(3).toList());
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final price = int.tryParse(_priceController.text.trim());

    if (name.isEmpty) {
      _message('Please enter a bouquet name.');
      return;
    }
    if (_selectedEmotionValue == null || _selectedEmotionValue!.isEmpty) {
      setState(() => _emotionError = 'Please select what this bouquet says.');
      _message('Please select what this bouquet says.');
      return;
    }
    if (!kEmotionValues.contains(_selectedEmotionValue)) {
      setState(() => _emotionError = 'Invalid selection.');
      return;
    }
    setState(() => _emotionError = null);

    if (price == null) {
      _message('Enter the price as a number in IQD.');
      return;
    }
    if (_images.isEmpty) {
      _message('Please upload at least one photo.');
      return;
    }

    final user = ref.read(authStateProvider).value;
    if (user == null) {
      _message('Please sign in again.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final code = await ref.read(vendorControllerProvider.notifier).publishBouquet(
            user: user,
            name: name,
            description: description,
            priceIqd: price,
            imageFiles: _images,
            emotion: _selectedEmotionValue!,
          );
      if (!mounted) return;
      _message(code != null ? 'Bouquet published. Code: $code' : 'Bouquet published.');
      _nameController.clear();
      _descriptionController.clear();
      _priceController.clear();
      setState(() {
        _images = [];
        _selectedEmotionValue = null;
        _emotionError = null;
      });
    } on TimeoutException catch (_) {
      _message('Publish timed out. Please try again.');
    } on fa.FirebaseException catch (e) {
      _message(e.message ?? 'Unable to publish bouquet.');
    } catch (_) {
      _message('Unable to publish. Try again or check your connection.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SectionContainer(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Bouquet',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Bouquet ID is auto-generated from the feeling you choose (e.g. Celebrate Them → Bi-1, Bi-2).',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Field(
                    label: 'Bouquet name',
                    hint: 'Spring Dawn',
                    controller: _nameController,
                    icon: Icons.local_florist_outlined,
                  ),
                  const SizedBox(height: 20),
                  _Field(
                    label: 'Description',
                    hint: 'Soft peonies with garden roses',
                    controller: _descriptionController,
                    icon: Icons.notes_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  _EmotionField(
                    value: _selectedEmotionValue,
                    error: _emotionError,
                    onChanged: (v) {
                      setState(() {
                        _selectedEmotionValue = v;
                        _emotionError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  _Field(
                    label: 'Price (IQD)',
                    hint: '45000',
                    controller: _priceController,
                    icon: Icons.payments_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: 'Upload photos',
                          onPressed: _pickImages,
                          variant: PrimaryButtonVariant.outline,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_images.length}/3',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.inkMuted,
                            ),
                      ),
                    ],
                  ),
                  if (_images.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _images
                          .map(
                            (f) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                f.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.inkMuted),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        'Available',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(width: 12),
                      Switch(
                        value: _available,
                        onChanged: (v) => setState(() => _available = v),
                        activeThumbColor: AppColors.rose,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: _submitting ? 'Publishing...' : 'Publish bouquet',
                    onPressed: _submitting || _selectedEmotionValue == null
                        ? () {}
                        : _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;

  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
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
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.inkMuted),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.rose),
            ),
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.ink,
              ),
        ),
      ],
    );
  }
}

class _EmotionField extends StatelessWidget {
  final String? value;
  final String? error;
  final ValueChanged<String?> onChanged;

  const _EmotionField({
    required this.value,
    required this.error,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What does this bouquet say?',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            errorText: error,
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.rose),
            ),
          ),
          hint: const Text('Choose a feeling'),
          items: kEmotions
              .map((e) => DropdownMenuItem<String>(
                    value: e.value,
                    child: Row(
                      children: [
                        if (e.icon != null) ...[
                          Icon(
                            e.icon,
                            size: 22,
                            color: AppColors.rose,
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(child: Text(e.label)),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
