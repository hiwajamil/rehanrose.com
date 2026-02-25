import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_format_utils.dart';
import '../../../data/models/order_model.dart';
import '../../../l10n/app_localizations.dart';
import '../common/primary_button.dart';

/// Formats order date: "Today HH:mm" for same day, else "dd/mm/yyyy HH:mm".
String formatOmsOrderDate(DateTime d, {bool short = false}) {
  if (short) {
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final orderDay = DateTime(d.year, d.month, d.day);
  if (orderDay == today) {
    return 'Today ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
  return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Label-value row for OMS order details.
class OmsDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final double labelWidth;

  const OmsDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.ink,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card dimensions for cached image decode (2x for retina).
const int _kOrderCardImageSize = 80;
const int _kOrderCardImageCacheSize = 160;

/// Reusable OMS order card for admin and vendor. Shows image, bouquet info, details, optional actions.
/// When [preparedCount] is set (e.g. for Ready tab grouped view), shows how many of this bouquet are ready.
class OmsOrderCard extends StatelessWidget {
  final OmsOrderModel order;
  final bool showVendorLine;
  final bool showOrderIdInSubtitle;
  /// When non-null, shows "N prepared" for grouped Ready section so vendor sees quantity.
  final int? preparedCount;
  final VoidCallback? onAccept;
  final VoidCallback? onReady;

  const OmsOrderCard({
    super.key,
    required this.order,
    this.showVendorLine = false,
    this.showOrderIdInSubtitle = false,
    this.preparedCount,
    this.onAccept,
    this.onReady,
  });

  String _priceString(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return l10n != null
        ? '${l10n.currencyIqd} ${formatPriceIqd(order.totalPrice.toInt())}'
        : '${order.totalPrice} IQD';
  }

  @override
  Widget build(BuildContext context) {
    final createdAtStr = order.createdAt != null
        ? formatOmsOrderDate(order.createdAt!, short: showVendorLine)
        : '—';
    final subtitle = showOrderIdInSubtitle
        ? '#${order.bouquetCode} · ${order.orderId}'
        : '#${order.bouquetCode}';
    final hasImage = order.bouquetImageUrl != null && order.bouquetImageUrl!.isNotEmpty;
    final showPreparedCount = preparedCount != null && preparedCount! > 0;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasImage) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        order.bouquetImageUrl!,
                        key: ValueKey<String>(order.bouquetImageUrl!),
                        width: _kOrderCardImageSize.toDouble(),
                        height: _kOrderCardImageSize.toDouble(),
                        fit: BoxFit.cover,
                        cacheWidth: _kOrderCardImageCacheSize,
                        cacheHeight: _kOrderCardImageCacheSize,
                        gaplessPlayback: true,
                        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded || frame != null) return child;
                          return SizedBox(
                            width: _kOrderCardImageSize.toDouble(),
                            height: _kOrderCardImageSize.toDouble(),
                            child: _placeholderBox(),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return SizedBox(
                            width: _kOrderCardImageSize.toDouble(),
                            height: _kOrderCardImageSize.toDouble(),
                            child: _placeholderBox(),
                          );
                        },
                        errorBuilder: (_, __, ___) => _placeholderBox(),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.bouquetName ?? 'Bouquet',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink,
                                    ),
                              ),
                            ),
                            if (showPreparedCount)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.rosePrimary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.rosePrimary.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  '×${preparedCount!} prepared',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: AppColors.rosePrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.inkMuted,
                              ),
                        ),
                        const SizedBox(height: 8),
                        OmsDetailRow(label: 'Customer', value: order.customerPhone),
                        if (showVendorLine)
                          OmsDetailRow(
                            label: 'Vendor',
                            value: order.vendorName ?? '—',
                            labelWidth: 72,
                          ),
                        OmsDetailRow(
                          label: 'Total',
                          value: _priceString(context),
                          labelWidth: showVendorLine ? 72 : 80,
                        ),
                        OmsDetailRow(
                          label: 'Placed',
                          value: createdAtStr,
                          labelWidth: showVendorLine ? 72 : 80,
                        ),
                        if (order.addons.isNotEmpty)
                          OmsDetailRow(
                            label: 'Add-ons',
                            value: order.addons,
                            labelWidth: showVendorLine ? 72 : 80,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (onAccept != null || onReady != null) ...[
                const SizedBox(height: 16),
                if (onAccept != null)
                  PrimaryButton(label: 'Accept Order', onPressed: onAccept!),
                if (onReady != null) ...[
                  if (onAccept != null) const SizedBox(height: 8),
                  PrimaryButton(label: 'Bouquet Is Ready', onPressed: onReady!),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderBox() {
    return Container(
      width: _kOrderCardImageSize.toDouble(),
      height: _kOrderCardImageSize.toDouble(),
      color: AppColors.border,
      child: const Icon(Icons.local_florist, color: AppColors.inkMuted),
    );
  }
}
