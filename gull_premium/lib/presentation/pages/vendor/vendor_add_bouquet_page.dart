import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/emotion_category.dart';
import '../../../core/theme/app_colors.dart';
import '../../../controllers/controllers.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/layout/section_container.dart';

/// Prefix for product code by occasion. Fallback: first 2 letters uppercase if not in map.
const Map<String, String> _occasionPrefixes = {
  'Birthday': 'BD',
  'Anniversary': 'AN',
  'Love & Romance': 'LV',
  'New Born': 'NB',
  'Get Well': 'GW',
  'Wedding': 'WD',
};

/// Maps occasion (dropdown label) to [kEmotionCategoryIds] for backend.
const Map<String, String> _occasionToEmotionCategoryId = {
  'Birthday': 'celebration',
  'Anniversary': 'love',
  'Love & Romance': 'love',
  'New Born': 'celebration',
  'Get Well': 'wellness',
  'Wedding': 'celebration',
};

/// Ordered list of occasions for the dropdown.
const List<String> _occasionOptions = [
  'Birthday',
  'Anniversary',
  'Love & Romance',
  'New Born',
  'Get Well',
  'Wedding',
];

String _prefixForOccasion(String occasion) {
  return _occasionPrefixes[occasion] ??
      (occasion.length >= 2 ? occasion.substring(0, 2).toUpperCase() : 'XX');
}

/// Add new bouquet: name, occasion, price (IQD), max 3 images, description, availability.
/// Product code is auto-generated from occasion (e.g. BD-402, AN-117).
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
  final _codeController = TextEditingController();
  String? _selectedOccasion;
  String? _occasionError;
  List<XFile> _images = [];
  bool _available = true;
  bool _submitting = false;
  final _imagePicker = ImagePicker();
  static final _random = Random();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onOccasionChanged(String? occasion) {
    if (occasion == null || occasion.isEmpty) return;
    setState(() {
      _selectedOccasion = occasion;
      _occasionError = null;
      final prefix = _prefixForOccasion(occasion);
      final randomNumber = _random.nextInt(900) + 100;
      _codeController.text = '$prefix-$randomNumber';
    });
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
    if (_selectedOccasion == null || _selectedOccasion!.isEmpty) {
      setState(() => _occasionError = 'Please select an occasion.');
      _message('Please select an occasion.');
      return;
    }
    final emotionCategoryId = _occasionToEmotionCategoryId[_selectedOccasion];
    if (emotionCategoryId == null || !isValidEmotionCategoryId(emotionCategoryId)) {
      setState(() => _occasionError = 'Invalid selection.');
      return;
    }
    setState(() => _occasionError = null);

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
      final codePrefix = _prefixForOccasion(_selectedOccasion!);
      final code = await ref.read(vendorControllerProvider.notifier).publishBouquet(
            user: user,
            name: name,
            description: description,
            priceIqd: price,
            imageFiles: _images,
            emotionCategoryId: emotionCategoryId,
            productCodePrefix: codePrefix,
          );
      if (!mounted) return;
      _message(
        code != null
            ? 'Bouquet submitted for approval. Code: $code. It will appear on the main screen after the super admin approves it.'
            : 'Bouquet submitted for approval. It will appear on the main screen after the super admin approves it.',
      );
      _nameController.clear();
      _descriptionController.clear();
      _priceController.clear();
      setState(() {
        _images = [];
        _selectedOccasion = null;
        _occasionError = null;
        _codeController.clear();
      });
    } on TimeoutException catch (_) {
      _message('Publish timed out. Please try again.');
    } on fa.FirebaseException catch (e) {
      _message(e.message ?? 'Unable to publish bouquet.');
    } catch (e, _) {
      final msg = e is Exception ? e.toString().replaceFirst('Exception: ', '') : '';
      _message(msg.isNotEmpty ? 'Unable to publish. $msg' : 'Unable to publish. Try again or check your connection.');
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
              'Product code is auto-generated from the occasion you choose (e.g. Birthday → BD-402).',
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
                    hint: '',
                    controller: _nameController,
                    icon: Icons.local_florist_outlined,
                  ),
                  const SizedBox(height: 20),
                  _Field(
                    label: 'Description',
                    hint: '',
                    controller: _descriptionController,
                    icon: Icons.notes_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  _OccasionDropdown(
                    value: _selectedOccasion,
                    error: _occasionError,
                    onChanged: _onOccasionChanged,
                  ),
                  const SizedBox(height: 20),
                  _Field(
                    label: 'Product code',
                    hint: 'Select an occasion to generate',
                    controller: _codeController,
                    icon: Icons.tag_outlined,
                    readOnly: true,
                  ),
                  const SizedBox(height: 20),
                  _Field(
                    label: 'Price (IQD)',
                    hint: '',
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
                    onPressed: _submitting || _selectedOccasion == null
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
  final bool readOnly;

  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.readOnly = false,
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
          readOnly: readOnly,
          autocorrect: false,
          enableSuggestions: false,
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

class _OccasionDropdown extends StatelessWidget {
  final String? value;
  final String? error;
  final ValueChanged<String?> onChanged;

  const _OccasionDropdown({
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
          'Occasion',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value != null && _occasionOptions.contains(value) ? value : null,
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
          hint: const Text('Choose occasion'),
          items: _occasionOptions
              .map((occasion) => DropdownMenuItem<String>(
                    value: occasion,
                    child: Text(occasion),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
