import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../controllers/controllers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/custom_request_model.dart';

/// Vendor: open custom-bouquet tenders and submit price + ETA notes.
class VendorCustomTendersPage extends ConsumerStatefulWidget {
  const VendorCustomTendersPage({super.key});

  @override
  ConsumerState<VendorCustomTendersPage> createState() => _VendorCustomTendersPageState();
}

class _VendorCustomTendersPageState extends ConsumerState<VendorCustomTendersPage> {
  final _priceController = TextEditingController();
  final _noteController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _openReferenceImageFullScreen(String imageUrl) {
    if (imageUrl.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openBidSheet(CustomRequestModel r) {
    final pageContext = context;
    _priceController.clear();
    _noteController.clear();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Submit your bid',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Request ${r.requestId}',
                    style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Your price offer (IQD)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (ETA, delivery, etc.)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _submitting
                        ? null
                        : () async {
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid == null) return;
                            final raw = _priceController.text.trim().replaceAll(',', '');
                            final price = num.tryParse(raw);
                            if (price == null || price <= 0) {
                              ScaffoldMessenger.of(modalContext).showSnackBar(
                                const SnackBar(content: Text('Enter a valid price.')),
                              );
                              return;
                            }
                            setModalState(() => _submitting = true);
                            try {
                              await ref.read(customRequestRepositoryProvider).submitBid(
                                    requestId: r.requestId,
                                    vendorId: uid,
                                    offeredPrice: price,
                                    vendorNote: _noteController.text.trim(),
                                  );
                              HapticFeedback.lightImpact();
                              if (!mounted || !sheetContext.mounted) return;
                              Navigator.pop(sheetContext);
                              if (!pageContext.mounted) return;
                              ScaffoldMessenger.of(pageContext).showSnackBar(
                                const SnackBar(content: Text('Bid submitted.')),
                              );
                            } catch (e) {
                              if (modalContext.mounted) {
                                ScaffoldMessenger.of(modalContext).showSnackBar(
                                  SnackBar(content: Text('Failed: $e')),
                                );
                              }
                            } finally {
                              setModalState(() => _submitting = false);
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.rosePrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(_submitting ? 'Submitting…' : 'Submit bid'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vendorBroadcastingRequestsStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tender / Open Requests',
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.inkCharcoal,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'These custom bouquet requests are open for bidding. Submit your best price and ETA notes.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    'No open tenders right now.',
                    style: TextStyle(color: AppColors.inkMuted),
                  ),
                );
              }
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final r = list[i];
                  return Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.border.withValues(alpha: 0.85)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      leading: r.imagePath.isNotEmpty
                          ? Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _openReferenceImageFullScreen(r.imagePath),
                                borderRadius: BorderRadius.circular(8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    r.imagePath,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.image_not_supported),
                                  ),
                                ),
                              ),
                            )
                          : const CircleAvatar(child: Icon(Icons.brush_outlined)),
                      title: Text(
                        r.description.isNotEmpty
                            ? (r.description.length > 80
                                ? '${r.description.substring(0, 80)}…'
                                : r.description)
                            : 'Custom bouquet',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Budget: ${r.budget}'),
                      ),
                      trailing: FilledButton(
                        onPressed: () => _openBidSheet(r),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.inkCharcoal,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Bid'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
