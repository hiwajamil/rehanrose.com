
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../controllers/controllers.dart';
import '../../core/theme/app_colors.dart';

/// Elegant bottom sheet: design your own bouquet → Storage + Firestore [CustomRequests].
Future<void> showCustomBouquetRequestSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _CustomBouquetRequestSheetBody(),
  );
}

class _CustomBouquetRequestSheetBody extends ConsumerStatefulWidget {
  const _CustomBouquetRequestSheetBody();

  @override
  ConsumerState<_CustomBouquetRequestSheetBody> createState() =>
      _CustomBouquetRequestSheetBodyState();
}

class _CustomBouquetRequestSheetBodyState extends ConsumerState<_CustomBouquetRequestSheetBody> {
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  XFile? _pickedImage;
  Uint8List? _previewBytes;
  bool _submitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  int? _parseBudgetIqd(String raw) {
    final cleaned = raw.replaceAll(',', '').replaceAll(' ', '').trim();
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned);
  }

  Future<void> _pickFrom(ImageSource source) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to submit a custom request.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2000,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedImage = file;
        _previewBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not capture image: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showImageSourcePicker() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to add a reference photo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFrom(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFrom(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _clearImage() => setState(() {
        _pickedImage = null;
        _previewBytes = null;
      });

  Future<String> _uploadImageBytes(Uint8List bytes, String mimeType, String ext) async {
    final name = const Uuid().v4();
    final ref = FirebaseStorage.instance.ref('custom_requests/images/$name.$ext');
    await ref.putData(bytes, SettableMetadata(contentType: mimeType));
    return ref.getDownloadURL();
  }

  Future<void> _showSuccessDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.rosePrimary, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Request submitted',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'Thank you. Our team will review your custom bouquet request shortly.',
          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.4),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rosePrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to submit a custom request.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_pickedImage == null || _previewBytes == null || _previewBytes!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a reference photo from your gallery or camera.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final description = _descriptionController.text.trim();
    final budgetIqd = _parseBudgetIqd(_budgetController.text);
    if (budgetIqd == null || budgetIqd <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid estimated budget in IQD (whole numbers).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final file = _pickedImage!;
      final bytes = _previewBytes!;
      final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
      final mime = file.mimeType ?? 'image/jpeg';

      final downloadUrl = await _uploadImageBytes(bytes, mime, ext);

      await ref.read(customRequestRepositoryProvider).createCustomerCustomRequest(
            customerId: user.uid,
            imagePath: downloadUrl,
            description: description,
            budgetIqd: budgetIqd,
          );

      if (!mounted) return;
      setState(() => _submitting = false);

      await _showSuccessDialog();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not submit: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final user = FirebaseAuth.instance.currentUser;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Design Your Own Bouquet',
                            style: GoogleFonts.montserrat(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkCharcoal,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: AppColors.inkMuted,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(22, 0, 22, 24 + bottom),
                        children: [
                          Text(
                            'Upload a reference photo, describe your vision, and set your budget. We will review your request in the app.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.inkMuted,
                                  height: 1.4,
                                ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'Reference image',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.inkCharcoal,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_previewBytes != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  Image.memory(
                                    _previewBytes!,
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Material(
                                      color: Colors.black45,
                                      shape: const CircleBorder(),
                                      child: IconButton(
                                        onPressed: _submitting ? null : _clearImage,
                                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: _submitting ? null : _showImageSourcePicker,
                              icon: const Icon(Icons.add_photo_alternate_outlined),
                              label: Text(user != null ? 'Gallery or camera' : 'Sign in to add a photo'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.inkCharcoal,
                                minimumSize: const Size.fromHeight(52),
                                side: BorderSide(color: AppColors.inkMuted.withValues(alpha: 0.35)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          const SizedBox(height: 22),
                          Text(
                            'Description / Notes',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.inkCharcoal,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 5,
                            maxLength: 2000,
                            enabled: !_submitting,
                            decoration: InputDecoration(
                              hintText: 'e.g. flower types, colors, size, occasion…',
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppColors.rosePrimary, width: 1.2),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please describe your bouquet.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Estimated budget (IQD)',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.inkCharcoal,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _budgetController,
                            keyboardType: TextInputType.number,
                            enabled: !_submitting,
                            decoration: InputDecoration(
                              hintText: 'e.g. 75000',
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppColors.rosePrimary, width: 1.2),
                              ),
                            ),
                            validator: (v) {
                              final n = _parseBudgetIqd(v ?? '');
                              if (n == null || n <= 0) {
                                return 'Enter a valid amount in IQD.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),
                          FilledButton(
                            onPressed: _submitting
                                ? null
                                : () {
                                    HapticFeedback.lightImpact();
                                    FocusScope.of(context).unfocus();
                                    _submit();
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.rosePrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Submit',
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_submitting)
              Positioned.fill(
                child: AbsorbPointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Uploading and saving…'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
