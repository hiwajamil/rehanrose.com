import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/bouquet_code_utils.dart';
import '../../../core/constants/occasions.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';

enum _VendorAccountStatus { pending, approved, rejected }

class VendorDashboardPage extends StatefulWidget {
  const VendorDashboardPage({super.key});

  @override
  State<VendorDashboardPage> createState() => _VendorDashboardPageState();
}

class _VendorDashboardPageState extends State<VendorDashboardPage> {
  bool _isSignIn = true;
  bool _isSubmitting = false;
  final ImagePicker _imagePicker = ImagePicker();
  List<XFile> _pickedImages = [];
  String? _selectedOccasion;
  String? _occasionValidationError;

  final TextEditingController _signInEmailController = TextEditingController();
  final TextEditingController _signInPasswordController = TextEditingController();

  final TextEditingController _studioNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _signUpEmailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _signUpPasswordController = TextEditingController();

  final TextEditingController _bouquetNameController = TextEditingController();
  final TextEditingController _bouquetDescriptionController =
      TextEditingController();
  final TextEditingController _bouquetPriceController = TextEditingController();

  @override
  void dispose() {
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _studioNameController.dispose();
    _ownerNameController.dispose();
    _signUpEmailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _signUpPasswordController.dispose();
    _bouquetNameController.dispose();
    _bouquetDescriptionController.dispose();
    _bouquetPriceController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  static Object? _unwrapError(Object? error) {
    try {
      final dynamic d = error;
      if (d != null && d.error != null) return d.error as Object?;
    } catch (_) {}
    return error;
  }

  static String _firebaseErrorLabel(String code) {
    switch (code) {
      case 'permission-denied':
        return 'Permission denied. Check that you are signed in and approved as a vendor.';
      case 'unauthenticated':
        return 'Please sign in again.';
      case 'resource-exhausted':
        return 'Too many requests. Please try again later.';
      case 'failed-precondition':
        return 'Operation not allowed in current state.';
      default:
        return 'Unable to publish bouquet.';
    }
  }

  Future<void> _submitApplication() async {
    if (_studioNameController.text.trim().isEmpty ||
        _ownerNameController.text.trim().isEmpty ||
        _signUpEmailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _signUpPasswordController.text.trim().isEmpty) {
      _showMessage('Please complete every field.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _signUpEmailController.text.trim(),
        password: _signUpPasswordController.text.trim(),
      );
      final uid = credential.user!.uid;
      final firestore = FirebaseFirestore.instance;

      await firestore.collection('users').doc(uid).set({
        'role': 'vendor',
        'vendorStatus': 'pending',
        'email': _signUpEmailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await firestore.collection('vendor_applications').doc(uid).set({
        'studioName': _studioNameController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
        'email': _signUpEmailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseAuth.instance.signOut();
      _showMessage('Application submitted. You will be notified after review.');
      setState(() {
        _isSignIn = true;
      });
    } on FirebaseAuthException catch (error) {
      _showMessage(error.message ?? 'Unable to submit application.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _signInVendor() async {
    if (_signInEmailController.text.trim().isEmpty ||
        _signInPasswordController.text.trim().isEmpty) {
      _showMessage('Enter your email and password.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _signInEmailController.text.trim(),
        password: _signInPasswordController.text.trim(),
      );
      final status = await _fetchVendorStatus(credential.user!);
      if (status != _VendorAccountStatus.approved) {
        await FirebaseAuth.instance.signOut();
        _showMessage(
          status == _VendorAccountStatus.rejected
              ? 'Your application was rejected. Contact support for details.'
              : 'Your application is still under review.',
        );
      }
    } on FirebaseAuthException catch (error) {
      _showMessage(error.message ?? 'Unable to sign in.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<_VendorAccountStatus> _fetchVendorStatus(User user) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final status = doc.data()?['vendorStatus']?.toString() ?? 'pending';
    if (status == 'approved') return _VendorAccountStatus.approved;
    if (status == 'rejected') return _VendorAccountStatus.rejected;
    return _VendorAccountStatus.pending;
  }

  Future<void> _pickImages() async {
    final images = await _imagePicker.pickMultiImage();
    if (images.isEmpty) return;
    setState(() {
      _pickedImages = images.take(3).toList();
    });
  }

  Future<void> _submitBouquet(User user) async {
    if (_bouquetNameController.text.trim().isEmpty ||
        _bouquetDescriptionController.text.trim().isEmpty ||
        _bouquetPriceController.text.trim().isEmpty) {
      _showMessage('Please complete the bouquet details.');
      return;
    }

    if (_selectedOccasion == null || _selectedOccasion!.isEmpty) {
      setState(() => _occasionValidationError = 'Please select an occasion.');
      _showMessage('Please select an occasion.');
      return;
    }
    if (!kOccasions.contains(_selectedOccasion)) {
      setState(() => _occasionValidationError = 'Invalid occasion.');
      _showMessage('Please select an occasion from the list.');
      return;
    }
    setState(() => _occasionValidationError = null);

    final price = int.tryParse(_bouquetPriceController.text.trim());
    if (price == null) {
      _showMessage('Enter the price as a number in IQD.');
      return;
    }

    if (_pickedImages.isEmpty) {
      _showMessage('Please upload at least one bouquet photo.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final storage = FirebaseStorage.instance;
      final firestore = FirebaseFirestore.instance;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imageUrls = <String>[];

      for (var i = 0; i < _pickedImages.length; i++) {
        final image = _pickedImages[i];
        if (kDebugMode) debugPrint('Reading image bytes: ${image.name}');
        final bytes = await image
            .readAsBytes()
            .timeout(const Duration(seconds: 15));
        final ref = storage.ref(
          'bouquets/${user.uid}/$timestamp-$i.jpg',
        );
        if (kDebugMode) debugPrint('Uploading image ${i + 1}/${_pickedImages.length}');
        final task = await ref
            .putData(
              bytes,
              SettableMetadata(contentType: 'image/jpeg'),
            )
            .timeout(const Duration(seconds: 45));
        final url = await task.ref.getDownloadURL();
        imageUrls.add(url);
      }

      final occasion = _selectedOccasion!;
      assert(kOccasions.contains(occasion), 'occasion must be from kOccasions');
      final prefix = getOccasionPrefix(occasion);
      if (prefix.isEmpty) {
        if (mounted) setState(() => _isSubmitting = false);
        _showMessage('Invalid occasion. Cannot generate bouquet code.');
        return;
      }

      final bouquetRef = firestore.collection('bouquets').doc();
      final counterRef = firestore.collection('counters').doc('bouquet_$prefix');
      String? generatedCode;
      await firestore.runTransaction((transaction) async {
        final counterSnap = await transaction.get(counterRef);
        final lastNumber = (counterSnap.data()?['lastNumber'] as num?)?.toInt() ?? 0;
        final nextNumber = lastNumber + 1;
        generatedCode = '$prefix-$nextNumber';
        transaction.set(counterRef, {'lastNumber': nextNumber});
        transaction.set(bouquetRef, {
          'vendorId': user.uid,
          'name': _bouquetNameController.text.trim(),
          'description': _bouquetDescriptionController.text.trim(),
          'priceIqd': price,
          'imageUrls': imageUrls,
          'bouquetCode': generatedCode,
          'occasion': occasion,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }).timeout(const Duration(seconds: 15));

      _showMessage(
        generatedCode != null
            ? 'Bouquet published. Code: $generatedCode'
            : 'Bouquet published.',
      );
      _bouquetNameController.clear();
      _bouquetDescriptionController.clear();
      _bouquetPriceController.clear();
      setState(() {
        _pickedImages = [];
        _selectedOccasion = null;
        _occasionValidationError = null;
      });
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Publish bouquet failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      // On web, Firebase errors can be boxed (e.g. "Dart exception thrown from converted Future")
      final e = _unwrapError(error);
      String message;
      if (e is TimeoutException) {
        message = 'Publish timed out. Please try again.';
      } else if (e is FirebaseException) {
        message = e.message ?? _firebaseErrorLabel(e.code);
      } else {
        message = 'Unable to publish bouquet. '
            'If you just set up Firestore, deploy the rules (Firebase Console → Firestore → Rules → Publish).';
      }
      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showEditBouquetSheet(
    BuildContext context,
    User user,
    DocumentReference docRef,
    Map<String, dynamic> data,
  ) {
    final priceController = TextEditingController(
      text: (data['priceIqd'] is int)
          ? '${data['priceIqd']}'
          : (data['priceIqd']?.toString() ?? ''),
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewPadding.bottom + 24,
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
            Text(
              'Edit bouquet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Text(
              'Price (IQD)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                prefixIcon: const Icon(Icons.payments_outlined, color: AppColors.inkMuted),
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
              label: 'Save price',
              onPressed: () async {
                final price = int.tryParse(priceController.text.trim());
                if (price == null) {
                  _showMessage('Enter a valid price in IQD.');
                  return;
                }
                Navigator.of(context).pop();
                await _updateBouquetPrice(docRef, price);
              },
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Remove and upload photos',
              onPressed: () async {
                Navigator.of(context).pop();
                await _replaceBouquetPhotos(context, user, docRef);
              },
              variant: PrimaryButtonVariant.outline,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete bouquet?'),
                    content: const Text(
                      'This bouquet will be removed from the storefront. This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text('Cancel', style: TextStyle(color: AppColors.inkMuted)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  Navigator.of(context).pop();
                  await _deleteBouquet(docRef);
                }
              },
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              label: const Text(
                'Delete bouquet',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(priceController.dispose);
  }

  Future<void> _updateBouquetPrice(DocumentReference docRef, int price) async {
    setState(() => _isSubmitting = true);
    try {
      await docRef.update({'priceIqd': price});
      if (mounted) _showMessage('Price updated.');
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Update price failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (mounted) _showMessage('Unable to update price.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _replaceBouquetPhotos(
    BuildContext context,
    User user,
    DocumentReference docRef,
  ) async {
    final images = await _imagePicker.pickMultiImage();
    if (images.isEmpty) return;

    final newImages = images.take(3).toList();
    setState(() => _isSubmitting = true);
    try {
      final storage = FirebaseStorage.instance;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imageUrls = <String>[];

      for (var i = 0; i < newImages.length; i++) {
        final image = newImages[i];
        final bytes = await image.readAsBytes().timeout(const Duration(seconds: 15));
        final ref = storage.ref('bouquets/${user.uid}/$timestamp-$i.jpg');
        final task = await ref
            .putData(bytes, SettableMetadata(contentType: 'image/jpeg'))
            .timeout(const Duration(seconds: 45));
        final url = await task.ref.getDownloadURL();
        imageUrls.add(url);
      }

      await docRef.update({'imageUrls': imageUrls});
      if (mounted) _showMessage('Photos updated.');
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Replace photos failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (mounted) _showMessage('Unable to update photos.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteBouquet(DocumentReference docRef) async {
    setState(() => _isSubmitting = true);
    try {
      await docRef.delete();
      if (mounted) _showMessage('Bouquet deleted.');
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Delete bouquet failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (mounted) _showMessage('Unable to delete bouquet.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null) {
            return _buildMarketing(context);
          }
          return _buildVendorDashboard(context, user);
        },
      ),
    );
  }

  Widget _buildMarketing(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => context.go('/admin'),
                child: Text(
                  'Admin',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
        SectionContainer(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 980;
              return Flex(
                direction: isNarrow ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment:
                    isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Become a Gull vendor',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Showcase your studio, manage orders, and connect with clients who value artisanal florals.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 28),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: const [
                            _BenefitChip(label: 'Weekly payouts'),
                            _BenefitChip(label: 'Curated client base'),
                            _BenefitChip(label: 'Dedicated concierge'),
                          ],
                        ),
                        const SizedBox(height: 32),
                        _VendorStatsRow(isNarrow: isNarrow),
                      ],
                    ),
                  ),
                  if (!isNarrow) const SizedBox(width: 32),
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 26,
                            offset: Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AuthToggle(
                            isSignIn: _isSignIn,
                            onChanged: (value) =>
                                setState(() => _isSignIn = value),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _isSignIn
                                ? 'Vendor sign in'
                                : 'Start your vendor application',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isSignIn
                                ? 'Welcome back. Access your storefront and orders.'
                                : 'Tell us about your studio so we can review your application.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.inkMuted),
                          ),
                          const SizedBox(height: 20),
                          if (_isSignIn) ...[
                            _AuthField(
                              label: 'Business email',
                              hintText: 'studio@email.com',
                              icon: Icons.mail_outline,
                              controller: _signInEmailController,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 16),
                            _AuthField(
                              label: 'Password',
                              hintText: 'Enter your password',
                              icon: Icons.lock_outline,
                              obscureText: true,
                              controller: _signInPasswordController,
                              textInputAction: TextInputAction.done,
                              onSubmitted: _isSubmitting ? null : _signInVendor,
                            ),
                            const SizedBox(height: 24),
                            PrimaryButton(
                              label:
                                  _isSubmitting ? 'Signing in...' : 'Sign in',
                              onPressed: _isSubmitting ? () {} : _signInVendor,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Forgot your password? Contact vendor support.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.inkMuted),
                            ),
                          ] else ...[
                            _AuthField(
                              label: 'Studio name',
                              hintText: 'Lune Botanica',
                              icon: Icons.storefront_outlined,
                              controller: _studioNameController,
                            ),
                            const SizedBox(height: 16),
                            _AuthField(
                              label: 'Owner name',
                              hintText: 'First and last name',
                              icon: Icons.person_outline,
                              controller: _ownerNameController,
                            ),
                            const SizedBox(height: 16),
                            _AuthField(
                              label: 'Business email',
                              hintText: 'studio@email.com',
                              icon: Icons.mail_outline,
                              controller: _signUpEmailController,
                            ),
                            const SizedBox(height: 16),
                            _AuthField(
                              label: 'Phone number',
                              hintText: '+1 (555) 123-4567',
                              icon: Icons.call_outlined,
                              controller: _phoneController,
                            ),
                            const SizedBox(height: 16),
                            _AuthField(
                              label: 'Studio location',
                              hintText: 'City, State',
                              icon: Icons.location_on_outlined,
                              controller: _locationController,
                            ),
                            const SizedBox(height: 16),
                            _AuthField(
                              label: 'Create a password',
                              hintText: 'At least 8 characters',
                              icon: Icons.lock_outline,
                              obscureText: true,
                              controller: _signUpPasswordController,
                            ),
                            const SizedBox(height: 24),
                            PrimaryButton(
                              label: _isSubmitting
                                  ? 'Submitting...'
                                  : 'Submit application',
                              onPressed:
                                  _isSubmitting ? () {} : _submitApplication,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'By submitting, you agree to our vendor terms and review process.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.inkMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        SectionContainer(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vendor success toolkit',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Everything you need to run a premium floral studio, in one place.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 980;
                  final cardWidth = isNarrow
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 32) / 3;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _ToolkitCard(
                        width: cardWidth,
                        title: 'Order management',
                        description:
                            'Track inbound orders, confirm delivery windows, and chat with concierge support.',
                        icon: Icons.receipt_long_outlined,
                      ),
                      _ToolkitCard(
                        width: cardWidth,
                        title: 'Merchandising tools',
                        description:
                            'Curate collections, schedule seasonal launches, and highlight your signature style.',
                        icon: Icons.auto_awesome_outlined,
                      ),
                      _ToolkitCard(
                        width: cardWidth,
                        title: 'Insights & payouts',
                        description:
                            'Review weekly performance and receive reliable payouts every Friday.',
                        icon: Icons.bar_chart_outlined,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVendorDashboard(BuildContext context, User user) {
    return Column(
      children: [
        SectionContainer(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
          child: Row(
            children: [
              Text(
                'Vendor dashboard',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Sign out',
                onPressed: () => FirebaseAuth.instance.signOut(),
                variant: PrimaryButtonVariant.outline,
              ),
            ],
          ),
        ),
        SectionContainer(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 980;
              return Flex(
                direction: isNarrow ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment:
                    isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildBouquetForm(context, user),
                  ),
                  if (!isNarrow) const SizedBox(width: 24),
                  Expanded(
                    flex: 6,
                    child: _buildBouquetList(context, user),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBouquetForm(BuildContext context, User user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add a new bouquet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Publish instantly to the main storefront. Prices are listed in IQD.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: 20),
          _AuthField(
            label: 'Bouquet name',
            hintText: 'Spring Dawn',
            icon: Icons.local_florist_outlined,
            controller: _bouquetNameController,
          ),
          const SizedBox(height: 16),
          _AuthField(
            label: 'Description',
            hintText: 'Soft peonies with garden roses',
            icon: Icons.notes_outlined,
            controller: _bouquetDescriptionController,
          ),
          const SizedBox(height: 16),
          _OccasionDropdown(
            value: _selectedOccasion,
            onChanged: (value) {
              setState(() {
                _selectedOccasion = value;
                _occasionValidationError = null;
              });
            },
            errorText: _occasionValidationError,
          ),
          const SizedBox(height: 16),
          _AuthField(
            label: 'Price (IQD)',
            hintText: '45000',
            icon: Icons.payments_outlined,
            controller: _bouquetPriceController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
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
                '${_pickedImages.length}/3 selected',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
          if (_pickedImages.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _pickedImages
                  .map(
                    (image) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        image.name,
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
          PrimaryButton(
            label: _isSubmitting ? 'Publishing...' : 'Publish bouquet',
            onPressed: (_isSubmitting || _selectedOccasion == null)
                ? () {}
                : () => _submitBouquet(user),
          ),
        ],
      ),
    );
  }

  Widget _buildBouquetList(BuildContext context, User user) {
    final bouquetsStream = FirebaseFirestore.instance
        .collection('bouquets')
        .where('vendorId', isEqualTo: user.uid)
        .snapshots();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your published bouquets',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: bouquetsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                if (kDebugMode) debugPrint('Bouquet stream error: ${snapshot.error}');
                return Text(
                  'Unable to load published bouquets.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.inkMuted),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Text(
                  'No bouquets yet. Publish your first one.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.inkMuted),
                );
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final imageUrls =
                      (data['imageUrls'] as List?)?.cast<String>() ?? [];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                imageUrls.isNotEmpty
                                    ? imageUrls.first
                                    : 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=400&q=80',
                                width: 86,
                                height: 86,
                                fit: BoxFit.cover,
                                cacheWidth: 172,
                                cacheHeight: 172,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 86,
                                  height: 86,
                                  color: AppColors.background,
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: AppColors.inkMuted,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['name']?.toString() ?? 'Bouquet',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    data['description']?.toString() ?? '',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.inkMuted),
                                  ),
                                  if ((data['bouquetCode']?.toString() ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      data['bouquetCode']?.toString() ?? '',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.inkMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'IQD ${data['priceIqd'] ?? '--'}',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: 'Edit',
                          onPressed: () => _showEditBouquetSheet(
                            context,
                            user,
                            doc.reference,
                            data,
                          ),
                          variant: PrimaryButtonVariant.outline,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AuthToggle extends StatelessWidget {
  final bool isSignIn;
  final ValueChanged<bool> onChanged;

  const _AuthToggle({required this.isSignIn, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ToggleButton(
          label: 'Sign in',
          isActive: isSignIn,
          onTap: () => onChanged(true),
        ),
        const SizedBox(width: 12),
        _ToggleButton(
          label: 'Create account',
          isActive: !isSignIn,
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppColors.rose : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isActive ? AppColors.rose : AppColors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isActive ? Colors.white : AppColors.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OccasionDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  const _OccasionDropdown({
    required this.value,
    required this.onChanged,
    this.errorText,
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
          initialValue: value,
          decoration: InputDecoration(
            errorText: errorText,
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.rose),
            ),
          ),
          hint: const Text('Select occasion'),
          items: kOccasions
              .map(
                (occasion) => DropdownMenuItem<String>(
                  value: occasion,
                  child: Text(occasion),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _AuthField extends StatelessWidget {
  final String label;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final VoidCallback? onSubmitted;
  final TextInputAction? textInputAction;

  const _AuthField({
    required this.label,
    required this.hintText,
    required this.icon,
    required this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onSubmitted,
    this.textInputAction,
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
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted != null ? (_) => onSubmitted!() : null,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: AppColors.inkMuted),
            filled: true,
            fillColor: AppColors.background,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.rose),
            ),
          ),
        ),
      ],
    );
  }
}

class _BenefitChip extends StatelessWidget {
  final String label;

  const _BenefitChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _VendorStatsRow extends StatelessWidget {
  final bool isNarrow;

  const _VendorStatsRow({required this.isNarrow});

  @override
  Widget build(BuildContext context) {
    final stats = [
      const _StatTile(
        value: '96%',
        label: 'Vendor satisfaction',
      ),
      const _StatTile(
        value: '\$4.8k',
        label: 'Avg. weekly revenue',
      ),
      const _StatTile(
        value: '48 hrs',
        label: 'Fast onboarding',
      ),
    ];

    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: stats
          .map(
            (stat) => SizedBox(
              width: isNarrow ? 200 : 180,
              child: stat,
            ),
          )
          .toList(),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;

  const _StatTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.rose,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ToolkitCard extends StatelessWidget {
  final double width;
  final String title;
  final String description;
  final IconData icon;

  const _ToolkitCard({
    required this.width,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.rose),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
        ],
      ),
    );
  }
}
