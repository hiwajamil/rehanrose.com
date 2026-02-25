import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../controllers/controllers.dart';
import '../../core/services/whatsapp_service.dart';
import '../../core/theme/app_colors.dart';
import '../pages/product/delivery_map_picker.dart';
import '../../core/utils/price_format_utils.dart';
import '../../data/models/add_on_model.dart';
import '../../data/models/flower_model.dart';
import '../../l10n/app_localizations.dart';
import '../pages/product/add_on_variant_selection_page.dart';
import 'common/app_cached_image.dart';
import 'common/order_via_whatsapp_button.dart';
import 'voice_message_dialog.dart';

/// Free delivery threshold in IQD. Orders at or above this total get free delivery.
const int freeDeliveryThreshold = 50000;

/// Opens the Add-on & Personalization dialog (centered) for the given bouquet.
/// Step 1: Add-ons (multi-select). Step 2: Voice message QR. Step 3: Order via WhatsApp.
void showAddOnPersonalizationModal(BuildContext context, String flowerId) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        child: _AddOnPersonalizationSheet(flowerId: flowerId),
      ),
    ),
  );
}

class _AddOnPersonalizationSheet extends ConsumerStatefulWidget {
  final String flowerId;

  const _AddOnPersonalizationSheet({required this.flowerId});

  @override
  ConsumerState<_AddOnPersonalizationSheet> createState() =>
      _AddOnPersonalizationSheetState();
}

class _AddOnPersonalizationSheetState
    extends ConsumerState<_AddOnPersonalizationSheet> {
  final List<AddOnModel> _selectedAddOns = [];
  String? _voiceMessageUrl;
  LatLng? _deliveryLatLng;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _hasSelectedAddOn(AddOnType type) =>
      _selectedAddOns.any((a) => a.type == type);

  void _removeAddOn(AddOnType type) {
    setState(() => _selectedAddOns.removeWhere((a) => a.type == type));
  }

  Future<void> _openVariantSelection(
    BuildContext context,
    AddOnType categoryType,
    List<AddOnModel> variants,
  ) async {
    if (variants.isEmpty) return;
    final selected = await AddOnVariantSelectionPage.open(
      context,
      categoryType: categoryType,
      variants: variants,
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedAddOns.removeWhere((a) => a.type == selected.type);
        _selectedAddOns.add(selected);
      });
    }
  }

  static const List<AddOnType> _addOnCategoryOrder = [
    AddOnType.vase,
    AddOnType.chocolate,
    AddOnType.card,
  ];

  static String _categoryTitle(AddOnType type) {
    switch (type) {
      case AddOnType.vase:
        return 'Vases';
      case AddOnType.chocolate:
        return 'Chocolates';
      case AddOnType.card:
        return 'Card';
      default:
        return 'Add-ons';
    }
  }

  static IconData _categoryIcon(AddOnType type) {
    switch (type) {
      case AddOnType.vase:
        return Icons.card_giftcard;
      case AddOnType.chocolate:
        return Icons.inventory_2;
      case AddOnType.card:
        return Icons.description;
      default:
        return Icons.card_giftcard;
    }
  }

  int _totalPriceIqd(FlowerModel bouquet) {
    var total = bouquet.priceIqd;
    for (final a in _selectedAddOns) {
      total += a.priceIqd;
    }
    return total;
  }

  Future<void> _openVoiceMessage() async {
    final url = await showVoiceMessageDialog(context);
    if (url != null && mounted) setState(() => _voiceMessageUrl = url);
  }

  Future<void> _openDeliveryMapPicker() async {
    final result = await showDeliveryMapPicker(context);
    if (result != null && mounted) {
      setState(() => _deliveryLatLng = result);
    }
  }

  void _orderViaWhatsApp(FlowerModel bouquet) {
    ref.read(bouquetRepositoryProvider).incrementOrderCount(bouquet.id);
    final l10n = AppLocalizations.of(context)!;
    final productUrl = '${Uri.base.origin}/p/${widget.flowerId}';
    final total = _totalPriceIqd(bouquet);
    launchOrderWhatsApp(
      flowerName: bouquet.name,
      flowerPrice: formatPriceWithCurrency(bouquet.priceIqd, l10n.currencyIqd),
      flowerId: bouquet.id,
      flowerImageUrl: bouquet.imageUrls.isNotEmpty ? bouquet.imageUrls.first : '',
      bouquetCode:
          bouquet.bouquetCode.isNotEmpty ? bouquet.bouquetCode : null,
      selectedAddOns:
          _selectedAddOns.isEmpty ? null : List.from(_selectedAddOns),
      totalPriceIqd: total,
      productUrl: productUrl,
      voiceMessageUrl: _voiceMessageUrl,
      freeDeliveryUnlocked: total >= freeDeliveryThreshold,
      deliveryLocation: _deliveryLatLng != null
          ? DeliveryLatLng(_deliveryLatLng!.latitude, _deliveryLatLng!.longitude)
          : null,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bouquetAsync = ref.watch(bouquetDetailProvider(widget.flowerId));
    final addOnsAsync = ref.watch(addOnsProvider(null));
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final montserrat = GoogleFonts.montserrat(
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    );

    final maxH = MediaQuery.of(context).size.height * 0.85;
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.montserratTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      child: Container(
        height: maxH,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          Text(
            l10n.addOnPersonalizationTitle,
            style: montserrat.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: bouquetAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Text(
                  l10n.couldNotLoadProduct,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              data: (bouquet) {
                if (bouquet == null) {
                  return Center(
                    child: Text(
                      l10n.productNotFound,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  );
                }
                final addOns = addOnsAsync.maybeWhen(
                  data: (list) => list.where((a) => a.isActive).toList(),
                  orElse: () => <AddOnModel>[],
                );
                final total = _totalPriceIqd(bouquet);

                return ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    Text(
                      bouquet.name,
                      style: montserrat.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.currencyIqd} ${formatPriceIqd(bouquet.priceIqd)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.step1AddOns,
                      style: montserrat.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _addOnCategoryOrder.map((categoryType) {
                        final ofType = addOns
                            .where((a) => a.type == categoryType)
                            .toList();
                        final isAvailable = ofType.isNotEmpty;
                        final isFirst = categoryType == _addOnCategoryOrder.first;
                        final isLast = categoryType == _addOnCategoryOrder.last;
                        const gap = 12.0;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: isFirst ? 0 : gap / 2,
                              right: isLast ? 0 : gap / 2,
                            ),
                            child: Opacity(
                              opacity: isAvailable ? 1.0 : 0.6,
                              child: AbsorbPointer(
                                absorbing: !isAvailable,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        _AddOnCategoryTile(
                                          categoryType: categoryType,
                                          ofType: ofType,
                                          isAvailable: isAvailable,
                                          locale: locale,
                                          l10n: l10n,
                                          montserrat: montserrat,
                                          onTap: isAvailable
                                              ? () => _openVariantSelection(
                                                    context,
                                                    categoryType,
                                                    ofType,
                                                  )
                                              : null,
                                        ),
                                        Positioned(
                                          top: -4,
                                          right: 8,
                                          child: _AvailabilityBadge(
                                            isAvailable: isAvailable,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _CategoryCircleIndicator(
                                            isSelected: _hasSelectedAddOn(
                                                categoryType),
                                          ),
                                          if (_hasSelectedAddOn(
                                              categoryType)) ...[
                                            const SizedBox(height: 6),
                                            TextButton(
                                              onPressed: () =>
                                                  _removeAddOn(categoryType),
                                              style: TextButton.styleFrom(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              child: Text(
                                                'Remove',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: AppColors.inkMuted,
                                                      decoration: TextDecoration
                                                          .underline,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      l10n.step2VoiceMessage,
                      style: montserrat.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: _voiceMessageUrl != null
                          ? AppColors.sage.withValues(alpha: 0.25)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: _openVoiceMessage,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _voiceMessageUrl != null
                                  ? AppColors.sage
                                  : AppColors.border,
                              width: _voiceMessageUrl != null ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.qr_code_2,
                                size: 28,
                                color: _voiceMessageUrl != null
                                    ? AppColors.ink
                                    : AppColors.inkMuted,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.includesFreeVoiceMessageQRCode,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.ink,
                                          ),
                                    ),
                                    if (_voiceMessageUrl != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          l10n.voiceMessageAdded,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.inkMuted,
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: AppColors.inkMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      l10n.step3Order,
                      style: montserrat.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.totalPriceLabel,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.inkMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        Text(
                          '${l10n.currencyIqd} ${formatPriceIqd(total)}',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _FreeDeliveryProgressBar(
                      currentTotal: total,
                      threshold: freeDeliveryThreshold,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 20),
                    Material(
                      color: _deliveryLatLng != null
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: _openDeliveryMapPicker,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _deliveryLatLng != null
                                  ? const Color(0xFF4CAF50)
                                  : AppColors.border,
                              width: _deliveryLatLng != null ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _deliveryLatLng != null
                                    ? Icons.check_circle
                                    : Icons.location_on,
                                size: 28,
                                color: _deliveryLatLng != null
                                    ? const Color(0xFF4CAF50)
                                    : AppColors.inkMuted,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _deliveryLatLng != null
                                      ? '✅ Location Selected (Tap to change)'
                                      : '📍 Select Delivery Location',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                      ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: AppColors.inkMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OrderViaWhatsAppButton(
                        label: l10n.orderViaWhatsApp,
                        valueProposition: '',
                        appearsDisabled: _deliveryLatLng == null,
                        onPressed: () {
                          if (_deliveryLatLng == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  '⚠️ Please select a delivery location first.',
                                  style: TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          ref.read(analyticsServiceProvider).logClickWhatsApp(
                                itemId: bouquet.id,
                                itemName: bouquet.name,
                              );
                          _orderViaWhatsApp(bouquet);
                        },
                        enabled:
                            ref.watch(connectivityStatusProvider).value ?? true,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
    );
  }
}

/// Single card per add-on category (Vases, Chocolates, Card).
/// Unavailable: light grey card, grey icon, label. Available: white card, image, label, price.
class _AddOnCategoryTile extends StatelessWidget {
  final AddOnType categoryType;
  final List<AddOnModel> ofType;
  final bool isAvailable;
  final String locale;
  final AppLocalizations l10n;
  final TextStyle montserrat;
  final VoidCallback? onTap;

  const _AddOnCategoryTile({
    required this.categoryType,
    required this.ofType,
    required this.isAvailable,
    required this.locale,
    required this.l10n,
    required this.montserrat,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = _AddOnPersonalizationSheetState._categoryTitle(categoryType);
    final iconData = _AddOnPersonalizationSheetState._categoryIcon(categoryType);

    final isUnavailable = ofType.isEmpty;
    final backgroundColor = isUnavailable
        ? AppColors.background.withValues(alpha: 0.8)
        : AppColors.surface;
    final borderColor = isUnavailable ? AppColors.border : AppColors.border;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isUnavailable) ...[
                const SizedBox(height: 24),
                Center(
                  child: Icon(
                    iconData,
                    color: AppColors.inkMuted.withValues(alpha: 0.6),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    title,
                    style: montserrat.copyWith(
                      fontSize: 14,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ] else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ofType.first.imageUrl.isEmpty
                      ? Shimmer.fromColors(
                          baseColor: AppColors.border,
                          highlightColor: AppColors.surface,
                          child: Container(
                            height: 100,
                            color: AppColors.border,
                            child: Icon(
                              iconData,
                              color: AppColors.inkMuted,
                              size: 36,
                            ),
                          ),
                        )
                      : SizedBox(
                          height: 100,
                          width: double.infinity,
                          child: AppCachedImage(
                            imageUrl: ofType.first.imageUrl,
                            fit: BoxFit.cover,
                            errorIcon: iconData,
                            errorIconSize: 36,
                          ),
                        ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: montserrat.copyWith(
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.currencyIqd} ${formatPriceIqd(ofType.first.priceIqd)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                        fontSize: 12,
                      ),
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small badge above/beside each add-on category tile showing availability.
/// Green "Available" when the category has active items; pink "Not Available" otherwise.
class _AvailabilityBadge extends StatelessWidget {
  final bool isAvailable;

  const _AvailabilityBadge({required this.isAvailable});

  static const Color _availableColor = Color(0xFF4CAF50);
  static const Color _notAvailableColor = Color(0xFFE91E8C);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isAvailable ? _availableColor : _notAvailableColor,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        isAvailable ? 'Available' : 'Not Available',
        style: GoogleFonts.montserrat(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Circle indicator below each add-on category (Vase, Chocolate, Card).
/// Empty circle when no add-on selected; green tick inside when selected.
/// Positioned outside the card boundary.
class _CategoryCircleIndicator extends StatelessWidget {
  final bool isSelected;

  const _CategoryCircleIndicator({required this.isSelected});

  static const double _size = 28;
  static const Color _selectedGreen = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(
                color: isSelected ? _selectedGreen : AppColors.border,
                width: 2,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.check, size: 14, color: _selectedGreen),
        ],
      ),
    );
  }
}

class _FreeDeliveryProgressBar extends StatelessWidget {
  final int currentTotal;
  final int threshold;
  final AppLocalizations l10n;

  const _FreeDeliveryProgressBar({
    required this.currentTotal,
    required this.threshold,
    required this.l10n,
  });

  /// Motivating orange color for "add more" state
  static const Color _addMoreColor = Color(0xFFE67E22);
  /// Success green when free delivery unlocked
  static const Color _unlockedColor = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    final unlocked = currentTotal >= threshold;
    final progress = unlocked ? 1.0 : (currentTotal / threshold).clamp(0.0, 1.0);
    final remaining = threshold - currentTotal;
    final progressColor = unlocked ? _unlockedColor : _addMoreColor;
    final text = unlocked
        ? l10n.youUnlockedFreeDelivery
        : l10n.addAmountMoreForFreeDelivery(formatPriceIqd(remaining));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: progressColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: progressColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: progressColor.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: progressColor,
                  fontSize: 13,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

