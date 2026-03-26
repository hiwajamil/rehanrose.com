import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';

class ManageCouponsScreen extends StatefulWidget {
  const ManageCouponsScreen({super.key});

  @override
  State<ManageCouponsScreen> createState() => _ManageCouponsScreenState();
}

class _ManageCouponsScreenState extends State<ManageCouponsScreen> {
  final CollectionReference<Map<String, dynamic>> _couponsRef =
      FirebaseFirestore.instance.collection('coupons');

  Future<void> _openCreateCouponDialog() async {
    final codeController = TextEditingController();
    final discountController = TextEditingController();
    DateTime? selectedExpiry;
    bool isActive = true;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickExpiry() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: now.add(const Duration(days: 30)),
                firstDate: now,
                lastDate: DateTime(now.year + 5),
              );
              if (picked == null) return;
              setDialogState(() {
                selectedExpiry = DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                  23,
                  59,
                );
              });
            }

            Future<void> saveCoupon() async {
              if (isSaving) return;
              final dialogNavigator = Navigator.of(dialogContext);
              final rawCode = codeController.text.trim().toUpperCase();
              final discount = double.tryParse(discountController.text.trim());
              if (rawCode.isEmpty) {
                _showSnack('Please enter a coupon code.');
                return;
              }
              if (discount == null || discount <= 0 || discount > 100) {
                _showSnack('Discount must be between 0 and 100.');
                return;
              }
              if (selectedExpiry == null) {
                _showSnack('Please select an expiry date.');
                return;
              }

              setDialogState(() => isSaving = true);
              try {
                final existing = await _couponsRef
                    .where('code', isEqualTo: rawCode)
                    .limit(1)
                    .get();
                if (existing.docs.isNotEmpty) {
                  _showSnack('Coupon code already exists.');
                  setDialogState(() => isSaving = false);
                  return;
                }

                await _couponsRef.add({
                  'code': rawCode,
                  'discountPercentage': discount,
                  'isActive': isActive,
                  'expiryDate': Timestamp.fromDate(selectedExpiry!),
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (!mounted) return;
                dialogNavigator.pop();
                _showSnack('Coupon created successfully.', isError: false);
              } catch (e) {
                debugPrint('Coupon Creation Error: $e');
                _showSnack('Failed: ${e.toString()}');
                setDialogState(() => isSaving = false);
              }
            }

            final expiryLabel = selectedExpiry == null
                ? 'Select expiry date'
                : DateFormat('yyyy-MM-dd').format(selectedExpiry!);
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 32,
                      offset: Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Promo Code',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create elegant limited-time offers for premium customers.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                    ),
                    const SizedBox(height: 18),
                    _LuxuryField(
                      label: 'Code',
                      hint: 'LOVE20',
                      controller: codeController,
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 12),
                    _LuxuryField(
                      label: 'Discount %',
                      hint: '20',
                      controller: discountController,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Expiry Date',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: isSaving ? null : pickExpiry,
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                expiryLabel,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: isActive,
                      onChanged: isSaving
                          ? null
                          : (v) => setDialogState(() => isActive = v),
                      title: const Text('Coupon is active'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSaving ? null : saveCoupon,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.rosePrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(isSaving ? 'Saving...' : 'Create'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleActive(String docId, bool current) async {
    try {
      await _couponsRef.doc(docId).update({'isActive': !current});
      _showSnack(current ? 'Coupon deactivated.' : 'Coupon activated.', isError: false);
    } catch (_) {
      _showSnack('Unable to update coupon status.');
    }
  }

  void _showSnack(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFF8B1E3F) : const Color(0xFF1F6E43),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateCouponDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Coupon'),
        backgroundColor: AppColors.rosePrimary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _couponsRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load coupons right now.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_offer_outlined, size: 34, color: AppColors.inkMuted),
                    const SizedBox(height: 10),
                    Text(
                      'No coupons yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create your first promo code to drive conversions.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(8),
            child: GridView.builder(
              itemCount: docs.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 390,
                childAspectRatio: 1.55,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final code = (data['code'] ?? '').toString();
                final discount = (data['discountPercentage'] is num)
                    ? (data['discountPercentage'] as num).toDouble()
                    : 0.0;
                final isActive = data['isActive'] == true;
                final expiryTs = data['expiryDate'] as Timestamp?;
                final expiry = expiryTs?.toDate();
                final isExpired =
                    expiry != null && expiry.isBefore(DateTime.now());
                final statusText = isExpired
                    ? 'Expired'
                    : (isActive ? 'Active' : 'Inactive');
                final statusColor = isExpired
                    ? const Color(0xFFB45309)
                    : (isActive ? const Color(0xFF166534) : AppColors.inkMuted);

                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              code,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              statusText,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Discount: ${discount.toStringAsFixed(discount % 1 == 0 ? 0 : 1)}%',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Expires: ${expiry != null ? DateFormat('yyyy-MM-dd').format(expiry) : '--'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.inkMuted,
                            ),
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _toggleActive(doc.id, isActive),
                          icon: Icon(
                            isActive ? Icons.toggle_on : Icons.toggle_off,
                            color: AppColors.rosePrimary,
                          ),
                          label: Text(isActive ? 'Deactivate' : 'Activate'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _LuxuryField extends StatelessWidget {
  const _LuxuryField({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

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
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.rosePrimary),
            ),
          ),
        ),
      ],
    );
  }
}
