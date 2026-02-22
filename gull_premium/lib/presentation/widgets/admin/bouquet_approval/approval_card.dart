import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/price_format_utils.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../controllers/bouquets_controller.dart';
import '../../../../data/models/flower_model.dart';
import '../../../../data/models/vendor_list_model.dart';
import '../../common/app_cached_image.dart';

/// Tab variant for Bouquet Approval card actions.
enum ApprovalCardVariant { pending, approved, rejected }

String ordinalSuffix(int n) {
  if (n >= 11 && n <= 13) return 'th';
  switch (n % 10) {
    case 1:
      return 'st';
    case 2:
      return 'nd';
    case 3:
      return 'rd';
    default:
      return 'th';
  }
}

/// Per-vendor count of approved bouquets. Used for "Stored Value" reputation on cards.
final vendorApprovedCountProvider = Provider.family<int, String>((ref, vendorId) {
  final approved = ref.watch(approvedBouquetsStreamProvider);
  return approved.when(
    data: (list) => list.where((b) => b.vendorId == vendorId).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Card displaying a single bouquet in the admin approval flow.
class BouquetApprovalCard extends ConsumerWidget {
  const BouquetApprovalCard({
    super.key,
    required this.bouquet,
    required this.variant,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
    required this.onDeletePermanently,
  });

  final FlowerModel bouquet;
  final ApprovalCardVariant variant;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDeletePermanently;

  static const double _thumbSize = 96;
  static const double _thumbSizeWide = 120;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorAsync = bouquet.vendorId != null
        ? ref.watch(vendorByIdProvider(bouquet.vendorId!))
        : const AsyncValue<VendorListModel?>.data(null);

    final vendorName = vendorAsync.value?.shopName ??
        (bouquet.vendorId != null
            ? 'Vendor (ID: ${bouquet.vendorId!.length >= 8 ? bouquet.vendorId!.substring(0, 8) : bouquet.vendorId}…)'
            : '—');

    final approvedCount = bouquet.vendorId != null
        ? ref.watch(vendorApprovedCountProvider(bouquet.vendorId!))
        : 0;

    final codeDisplay = bouquet.bouquetCode.isNotEmpty
        ? (bouquet.bouquetCode.startsWith('#') ? bouquet.bouquetCode : '#${bouquet.bouquetCode}')
        : null;

    final montserrat = GoogleFonts.montserrat();
    final playfair = GoogleFonts.playfairDisplay();
    final greyText = montserrat.copyWith(fontSize: 13, color: Colors.grey.shade600);

    final isWide = MediaQuery.sizeOf(context).width >= 500;
    final thumbSize = isWide ? _thumbSizeWide : _thumbSize;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: isWide
          ? _buildHorizontal(context, thumbSize, vendorName, approvedCount, codeDisplay, montserrat, playfair, greyText)
          : _buildVertical(context, thumbSize, vendorName, approvedCount, codeDisplay, montserrat, playfair, greyText),
    );
  }

  Widget _buildHorizontal(
    BuildContext context,
    double thumbSize,
    String vendorName,
    int approvedCount,
    String? codeDisplay,
    TextStyle montserrat,
    TextStyle playfair,
    TextStyle greyText,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildThumbnail(thumbSize),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                bouquet.name,
                style: playfair.copyWith(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (codeDisplay != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    codeDisplay,
                    style: montserrat.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Published by: $vendorName',
                      style: montserrat.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.inkMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (bouquet.vendorId != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.sage.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.sage.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        approvedCount == 0
                            ? 'First approval'
                            : '$approvedCount${ordinalSuffix(approvedCount)} approved for this vendor',
                        style: montserrat.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ink),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                iqdPriceString(bouquet.priceIqd),
                style: montserrat.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.rosePrimary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _buildActions(context, montserrat),
      ],
    );
  }

  Widget _buildVertical(
    BuildContext context,
    double thumbSize,
    String vendorName,
    int approvedCount,
    String? codeDisplay,
    TextStyle montserrat,
    TextStyle playfair,
    TextStyle greyText,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThumbnail(thumbSize),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bouquet.name,
                    style: playfair.copyWith(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (codeDisplay != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        codeDisplay,
                        style: montserrat.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Published by: $vendorName',
                    style: montserrat.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (bouquet.vendorId != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.sage.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.sage.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        approvedCount == 0
                            ? 'First approval'
                            : '$approvedCount${ordinalSuffix(approvedCount)} approved for this vendor',
                        style: montserrat.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ink),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    iqdPriceString(bouquet.priceIqd),
                    style: montserrat.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.rosePrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildActions(context, montserrat),
      ],
    );
  }

  Widget _buildThumbnail(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: bouquet.listingImageUrl.isNotEmpty
          ? AppCachedImage(
              imageUrl: bouquet.listingImageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorIconSize: 32,
            )
          : Container(
              color: Colors.grey.shade200,
              child: Icon(Icons.image_not_supported_outlined, size: size * 0.4, color: Colors.grey.shade500),
            ),
    );
  }

  Widget _buildActions(BuildContext context, TextStyle montserrat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () => context.push('/flower/${bouquet.id}'),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'View Full Details',
            style: montserrat.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.rosePrimary,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.rosePrimary,
            ),
          ),
        ),
        if (variant == ApprovalCardVariant.pending) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Approve',
                child: IconButton(
                  onPressed: isProcessing ? null : onApprove,
                  icon: Icon(
                    isProcessing ? Icons.hourglass_empty : Icons.check_circle_outline,
                    color: isProcessing ? Colors.grey : const Color(0xFF2E7D32),
                    size: 28,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Reject',
                child: IconButton(
                  onPressed: isProcessing ? null : onReject,
                  icon: Icon(
                    isProcessing ? Icons.hourglass_empty : Icons.cancel_outlined,
                    color: isProcessing ? Colors.grey : const Color(0xFFC62828),
                    size: 28,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828).withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (variant == ApprovalCardVariant.rejected) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: isProcessing ? null : onApprove,
                icon: Icon(isProcessing ? Icons.hourglass_empty : Icons.check_circle_outline, size: 18),
                label: Text(isProcessing ? 'Working…' : 'Approve Anyway'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: isProcessing ? null : onDeletePermanently,
                icon: Icon(isProcessing ? Icons.hourglass_empty : Icons.delete_forever, size: 18),
                label: Text(isProcessing ? 'Working…' : 'Delete Permanently'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB71C1C),
                  side: const BorderSide(color: Color(0xFFB71C1C)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
