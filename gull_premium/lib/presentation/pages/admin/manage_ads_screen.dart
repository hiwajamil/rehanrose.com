import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../widgets/common/app_cached_image.dart';

class ManageAdsScreen extends StatefulWidget {
  const ManageAdsScreen({super.key});

  @override
  State<ManageAdsScreen> createState() => _ManageAdsScreenState();
}

class _ManageAdsScreenState extends State<ManageAdsScreen> {
  static const int _maxAds = 3;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;

  DocumentReference<Map<String, dynamic>> get _adsDoc =>
      FirebaseFirestore.instance.collection('settings').doc('home_ads');

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addAdvertisement(List<String> existingUrls) async {
    if (_isUploading) return;
    if (existingUrls.length >= _maxAds) {
      _showMessage('You can add up to 3 advertisements only.');
      return;
    }

    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (picked == null) return;

    Uint8List bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (_) {
      _showMessage('Failed to read the selected image.');
      return;
    }
    if (bytes.isEmpty) {
      _showMessage('Selected image is empty.');
      return;
    }

    final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
    final fileName = 'ad_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storageRef = FirebaseStorage.instance.ref('advertisements/$fileName');

    setState(() => _isUploading = true);
    try {
      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: picked.mimeType ?? 'image/jpeg'),
      );
      final downloadUrl = await storageRef.getDownloadURL();
      await _adsDoc.set(<String, dynamic>{
        'imageUrls': FieldValue.arrayUnion(<String>[downloadUrl]),
      }, SetOptions(merge: true));
      _showMessage('Advertisement added.');
    } catch (e, stackTrace) {
      debugPrint('Upload Error: $e');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('Failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteAdvertisement(String imageUrl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete advertisement?'),
        content: const Text('This removes the image from the home banner.'),
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
    if (confirmed != true) return;

    try {
      await _adsDoc.set(<String, dynamic>{
        'imageUrls': FieldValue.arrayRemove(<String>[imageUrl]),
      }, SetOptions(merge: true));
      try {
        await FirebaseStorage.instance.refFromURL(imageUrl).delete();
      } catch (_) {
        // Keep UX smooth even when deleting old/missing storage files.
      }
      _showMessage('Advertisement removed.');
    } catch (_) {
      _showMessage('Failed to remove advertisement.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _adsDoc.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final rawUrls = (data?['imageUrls'] as List?) ?? const [];
        final imageUrls = rawUrls
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();

        return Container(
          width: double.infinity,
          color: const Color(0xFFF4F5F7),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage Advertisements',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload up to 3 elegant banners for the home carousel.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: 18),
                  if (imageUrls.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 44,
                        horizontal: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.view_carousel_outlined,
                            size: 38,
                            color: AppColors.inkMuted.withValues(alpha: 0.75),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No advertisements yet.',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final crossAxisCount = width > 920
                            ? 3
                            : (width > 620 ? 2 : 1);
                        return GridView.builder(
                          itemCount: imageUrls.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: 1.8,
                              ),
                          itemBuilder: (context, index) {
                            final imageUrl = imageUrls[index];
                            return Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: AppCachedImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Material(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    shape: const CircleBorder(),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white,
                                      ),
                                      onPressed: () =>
                                          _deleteAdvertisement(imageUrl),
                                      tooltip: 'Delete',
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 18),
                  if (imageUrls.length < _maxAds)
                    FilledButton.icon(
                      onPressed: _isUploading
                          ? null
                          : () => _addAdvertisement(imageUrls),
                      icon: _isUploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        _isUploading ? 'Uploading...' : 'Add Advertisement',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rosePrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
