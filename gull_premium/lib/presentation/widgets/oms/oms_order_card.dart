import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/florist_card_pdf.dart';
import '../../../core/utils/price_format_utils.dart';
import '../../../data/models/order_model.dart';
import '../../../l10n/app_localizations.dart';
import '../common/app_cached_image.dart';
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

/// Compact label-value cell for order card grid layout.
class _OrderCardDetailCell extends StatelessWidget {
  const _OrderCardDetailCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.inkMuted,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.ink,
              ),
        ),
      ],
    );
  }
}

/// Single label-value row for Florist Card.
class _FloristRow extends StatelessWidget {
  const _FloristRow({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text('$label:', style: labelStyle),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
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
  final Future<void> Function()? onDelete;

  const OmsOrderCard({
    super.key,
    required this.order,
    this.showVendorLine = false,
    this.showOrderIdInSubtitle = false,
    this.preparedCount,
    this.onAccept,
    this.onReady,
    this.onDelete,
  });

  String _priceString(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return l10n != null
        ? '${l10n.currencyIqd} ${formatPriceIqd(order.totalPrice.toInt())}'
        : '${order.totalPrice} IQD';
  }

  bool get _isVendorView => onAccept != null || onReady != null;

  @override
  Widget build(BuildContext context) {
    if (_isVendorView) {
      return _buildFloristCard(context);
    }
    return _buildStandardCard(context);
  }

  /// Elegant Florist Card for vendor: premium typography, optional QR, Print button.
  Widget _buildFloristCard(BuildContext context) {
    final createdAtStr = order.createdAt != null
        ? formatOmsOrderDate(order.createdAt!, short: showVendorLine)
        : '—';
    final orderDateStr = (order.orderDate != null && order.orderDate!.isNotEmpty)
        ? order.orderDate!
        : createdAtStr;
    final hasVoiceLink = order.voiceMessageLink != null &&
        order.voiceMessageLink!.trim().isNotEmpty;
    final hasImage = order.bouquetImageUrl != null && order.bouquetImageUrl!.isNotEmpty;
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.inkMuted,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        );
    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w500,
        );

    return RepaintBoundary(
      key: ValueKey('florist-${order.orderId}'),
      child: Card(
        margin: const EdgeInsets.only(bottom: 20),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Text(
                      'Rehan Rose',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Order Card',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.inkMuted,
                            letterSpacing: 1.2,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (hasImage) ...[
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AppCachedImage(
                      key: ValueKey<String>(order.bouquetImageUrl!),
                      imageUrl: order.bouquetImageUrl!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      memCacheWidth: 200,
                      memCacheHeight: 200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              _FloristRow(label: 'Order', value: order.orderId, valueStyle: valueStyle, labelStyle: labelStyle),
              _FloristRow(label: 'Date & Time', value: orderDateStr, valueStyle: valueStyle, labelStyle: labelStyle),
              _FloristRow(label: 'Customer', value: order.customerPhone, valueStyle: valueStyle, labelStyle: labelStyle),
              _FloristRow(label: 'Bouquet', value: order.bouquetName ?? '—', valueStyle: valueStyle, labelStyle: labelStyle),
              _FloristRow(label: 'Code', value: order.bouquetCode, valueStyle: valueStyle, labelStyle: labelStyle),
              if (order.bouquetDetails != null && order.bouquetDetails!.isNotEmpty)
                _FloristRow(label: 'Details', value: order.bouquetDetails!, valueStyle: valueStyle, labelStyle: labelStyle),
              _FloristRow(label: 'Total', value: _priceString(context), valueStyle: valueStyle, labelStyle: labelStyle),
              if (order.addons.isNotEmpty)
                _FloristRow(label: 'Add-ons', value: order.addons, valueStyle: valueStyle, labelStyle: labelStyle),
              if (order.deliveryLocationLink != null && order.deliveryLocationLink!.isNotEmpty)
                _FloristRow(label: 'Delivery', value: order.deliveryLocationLink!, valueStyle: valueStyle, labelStyle: labelStyle),
              if (hasVoiceLink) ...[
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: QrImageView(
                          data: order.voiceMessageLink!,
                          version: QrVersions.auto,
                          size: 120,
                          backgroundColor: Colors.white,
                          gapless: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Scan for voice message',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.inkMuted,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  if (onAccept != null)
                    Expanded(
                      child: PrimaryButton(label: 'Accept Order', onPressed: onAccept!),
                    ),
                  if (onAccept != null && onReady != null) const SizedBox(width: 12),
                  if (onReady != null)
                    Expanded(
                      child: PrimaryButton(label: 'Bouquet Is Ready', onPressed: onReady!),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _printOrderCard(context, order),
                  icon: Icon(
                    CupertinoIcons.printer,
                    size: 22,
                    color: AppColors.rosePrimary,
                  ),
                  label: Text(
                    'Print Order Card',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: AppColors.ink,
                    side: BorderSide(color: AppColors.rosePrimary.withValues(alpha: 0.55), width: 1.25),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStandardCard(BuildContext context) {
    final createdAtStr = order.createdAt != null
        ? formatOmsOrderDate(order.createdAt!, short: showVendorLine)
        : '—';
    final subtitle = showOrderIdInSubtitle
        ? '#${order.bouquetCode} · ${order.orderId}'
        : '#${order.bouquetCode}';
    final hasImage = order.bouquetImageUrl != null && order.bouquetImageUrl!.isNotEmpty;
    final showPreparedCount = preparedCount != null && preparedCount! > 0;
    final canDelete = onDelete != null;
    final isMobile = MediaQuery.sizeOf(context).width < kAdminShellDrawerBreakpoint;
    final padding = isMobile ? 16.0 : 20.0;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasImage) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AppCachedImage(
                        key: ValueKey<String>(order.bouquetImageUrl!),
                        imageUrl: order.bouquetImageUrl!,
                        width: _kOrderCardImageSize.toDouble(),
                        height: _kOrderCardImageSize.toDouble(),
                        fit: BoxFit.cover,
                        memCacheWidth: _kOrderCardImageCacheSize,
                        memCacheHeight: _kOrderCardImageCacheSize,
                        borderRadius: BorderRadius.circular(12),
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
                            if (canDelete)
                              IconButton(
                                onPressed: () async => await onDelete!(),
                                tooltip: 'Delete',
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red.shade300,
                                ),
                                splashRadius: 18,
                                visualDensity: VisualDensity.compact,
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
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: AppColors.border, width: 1),
                            ),
                          ),
                          child: isMobile && showVendorLine
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _OrderCardDetailCell(
                                      label: 'Customer',
                                      value: order.customerPhone,
                                    ),
                                    const SizedBox(height: 8),
                                    _OrderCardDetailCell(
                                      label: 'Vendor',
                                      value: order.vendorName ?? '—',
                                    ),
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _OrderCardDetailCell(
                                        label: 'Customer',
                                        value: order.customerPhone,
                                      ),
                                    ),
                                    if (showVendorLine)
                                      Expanded(
                                        child: _OrderCardDetailCell(
                                          label: 'Vendor',
                                          value: order.vendorName ?? '—',
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: order.addons.isNotEmpty
                                  ? BorderSide(color: AppColors.border, width: 1)
                                  : BorderSide.none,
                            ),
                          ),
                          child: isMobile
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _OrderCardDetailCell(
                                      label: 'Total',
                                      value: _priceString(context),
                                    ),
                                    const SizedBox(height: 8),
                                    _OrderCardDetailCell(
                                      label: 'Date',
                                      value: createdAtStr,
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: _OrderCardDetailCell(
                                        label: 'Total',
                                        value: _priceString(context),
                                      ),
                                    ),
                                    Expanded(
                                      child: _OrderCardDetailCell(
                                        label: 'Date',
                                        value: createdAtStr,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        if (order.addons.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _OrderCardDetailCell(
                              label: 'Add-ons',
                              value: order.addons,
                            ),
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
}

/// Opens the system print dialog for a vendor bouquet tag PDF ([printOrderCard]).
Future<void> _printOrderCard(BuildContext context, OmsOrderModel order) async {
  try {
    await printOrderCard(order);
  } on MissingPluginException {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Printing is not available in this app build. Please update/reinstall the vendor app and try again.',
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not print order card: $e')),
    );
  }
}
