import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
/// Premium flow: Complete your gift (add-ons) → Personalize (voice message) → Sticky checkout bar.
void showAddOnPersonalizationModal(BuildContext context, String flowerId) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: _AddOnPersonalizationSheet(flowerId: flowerId),
          ),
        ),
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
  static const Color _luxuryGold = AppColors.accentGold;
  final List<AddOnModel> _selectedAddOns = [];
  String? _voiceMessageUrl;
  LatLng? _deliveryLatLng;
  final TextEditingController _promoCodeController = TextEditingController();
  final FocusNode _promoFocusNode = FocusNode();
  bool _isApplyingPromo = false;
  String? _appliedPromoCode;
  double? _appliedPromoDiscountPercentage;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _promoCodeController.dispose();
    _promoFocusNode.dispose();
    super.dispose();
  }

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

  static String _categoryTitle(AppLocalizations l10n, AddOnType type) {
    switch (type) {
      case AddOnType.vase:
        return l10n.addOnCategoryVases;
      case AddOnType.chocolate:
        return l10n.addOnCategoryChocolates;
      case AddOnType.card:
        return l10n.addOnCategoryCard;
      default:
        return l10n.addOnCategoryAddOns;
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

  int _discountedTotalIqd(FlowerModel bouquet) {
    final base = _totalPriceIqd(bouquet);
    final d = _appliedPromoDiscountPercentage;
    if (_appliedPromoCode == null || d == null || d <= 0) return base;
    return (base * ((100 - d) / 100)).round();
  }

  void _showPromoSnack(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (!isError) ...[
              Icon(Icons.auto_awesome_rounded, color: _luxuryGold, size: 22),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? const Color(0xFF8B1E3F) : const Color(0xFF1B3D2F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _applyPromoCode(FlowerModel bouquet) async {
    if (_isApplyingPromo) return;
    final code = _promoCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _showPromoSnack('Please enter a promo code.');
      return;
    }

    setState(() => _isApplyingPromo = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('coupons')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        _showPromoSnack('This promo code is invalid.');
        return;
      }

      final data = snapshot.docs.first.data();
      final isActive = data['isActive'] == true;
      final expiryTs = data['expiryDate'] as Timestamp?;
      final discount = (data['discountPercentage'] is num)
          ? (data['discountPercentage'] as num).toDouble()
          : -1.0;
      final isExpired =
          expiryTs == null || expiryTs.toDate().isBefore(DateTime.now());

      if (!isActive || isExpired || discount <= 0 || discount > 100) {
        _showPromoSnack('This promo code is inactive or expired.');
        return;
      }

      if (!mounted) return;
      setState(() {
        _appliedPromoCode = code;
        _appliedPromoDiscountPercentage = discount;
      });
      _showPromoSnack('✨ Promo Code Applied Successfully!', isError: false);
    } catch (_) {
      _showPromoSnack('Unable to verify promo code right now.');
    } finally {
      if (mounted) setState(() => _isApplyingPromo = false);
    }
  }

  Future<void> _openVoiceMessage() async {
    if (FirebaseAuth.instance.currentUser == null) {
      showVoiceMessageAuthRequired(context);
      return;
    }
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
    final checkoutTotal = _discountedTotalIqd(bouquet);
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
      promoCode: _appliedPromoCode,
      promoDiscountPercentage: _appliedPromoDiscountPercentage,
      discountedTotalPriceIqd:
          checkoutTotal != total ? checkoutTotal : null,
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
                final checkoutTotal = _discountedTotalIqd(bouquet);
                final hasPromo = _appliedPromoCode != null &&
                    _appliedPromoDiscountPercentage != null;
                final sectionTitleStyle = GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                );

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        children: [
                          Text(
                            bouquet.name,
                            style: montserrat.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${l10n.currencyIqd} ${formatPriceIqd(bouquet.priceIqd)}',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppColors.inkMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            l10n.completeYourGift,
                            style: sectionTitleStyle,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 220,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _addOnCategoryOrder.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final categoryType =
                                    _addOnCategoryOrder[index];
                                final ofType = addOns
                                    .where((a) => a.type == categoryType)
                                    .toList();
                                final isAvailable = ofType.isNotEmpty;
                                AddOnModel? sel;
                                for (final a in _selectedAddOns) {
                                  if (a.type == categoryType) {
                                    sel = a;
                                    break;
                                  }
                                }
                                return Opacity(
                                  opacity: isAvailable ? 1.0 : 0.55,
                                  child: AbsorbPointer(
                                    absorbing: !isAvailable,
                                    child: _PremiumAddOnCard(
                                      categoryType: categoryType,
                                      ofType: ofType,
                                      selected: sel,
                                      locale: locale,
                                      l10n: l10n,
                                      onTap: isAvailable
                                          ? () => _openVariantSelection(
                                                context,
                                                categoryType,
                                                ofType,
                                              )
                                          : null,
                                      onRemove: sel != null
                                          ? () => _removeAddOn(categoryType)
                                          : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            l10n.personalizeSectionTitle,
                            style: sectionTitleStyle,
                          ),
                          const SizedBox(height: 12),
                          Material(
                            color: _voiceMessageUrl != null
                                ? AppColors.blush.withValues(alpha: 0.2)
                                : AppColors.blush.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            elevation: 0,
                            child: InkWell(
                              onTap: _openVoiceMessage,
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 18,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.mic_none_rounded,
                                      size: 28,
                                      color: _voiceMessageUrl != null
                                          ? AppColors.rosePrimary
                                          : AppColors.inkMuted,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            l10n.addFreeVoiceMessage,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.ink,
                                                ),
                                          ),
                                          if (_voiceMessageUrl != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              l10n.voiceMessageAdded,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: AppColors.inkMuted,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppColors.inkMuted,
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _FreeDeliveryBanner(
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
                                child: _deliveryLatLng != null
                                    ? Text(
                                        '✅ ${l10n.locationSelectedTapToChange}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.ink,
                                            ),
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            l10n.selectDeliveryLocation,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.ink,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            l10n.locationRequiredSubtitle,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.orange.shade700,
                                                ) ??
                                                TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.orange.shade700,
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
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.85),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadow.withValues(alpha: 0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.tag,
                                  size: 22,
                                  color: AppColors.inkMuted,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _promoCodeController,
                                    focusNode: _promoFocusNode,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    onTap: () =>
                                        HapticFeedback.lightImpact(),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.6,
                                      color: AppColors.ink,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter Promo Code',
                                      isDense: true,
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      hintStyle: GoogleFonts.montserrat(
                                        fontSize: 14,
                                        color: AppColors.inkMuted
                                            .withValues(alpha: 0.75),
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_isApplyingPromo)
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: AppColors.accentGold,
                                      ),
                                    ),
                                  )
                                else
                                  TextButton(
                                    onPressed: () async {
                                      HapticFeedback.mediumImpact();
                                      await _applyPromoCode(bouquet);
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: _luxuryGold,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Apply',
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                        color: _luxuryGold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (hasPromo) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 18,
                                    color: const Color(0xFF166534),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Promo ${_appliedPromoCode!} (-${_appliedPromoDiscountPercentage!.toStringAsFixed(_appliedPromoDiscountPercentage! % 1 == 0 ? 0 : 1)}%) applied',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFF166534),
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    _StickyCheckoutBar(
                      subtotalIqd: total,
                      checkoutTotalIqd: checkoutTotal,
                      showDiscounted: hasPromo && checkoutTotal != total,
                      l10n: l10n,
                      onOrder: () {
                        if (_deliveryLatLng == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      l10n.locationRequiredSnackbar,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ) ??
                                          const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.red.shade400,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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

/// Sticky bottom bar: total on the left, Order via WhatsApp button on the right.
class _StickyCheckoutBar extends StatelessWidget {
  final int subtotalIqd;
  final int checkoutTotalIqd;
  final bool showDiscounted;
  final AppLocalizations l10n;
  final VoidCallback onOrder;
  final bool enabled;

  const _StickyCheckoutBar({
    required this.subtotalIqd,
    required this.checkoutTotalIqd,
    required this.showDiscounted,
    required this.l10n,
    required this.onOrder,
    required this.enabled,
  });

  static const Color _luxuryGold = AppColors.accentGold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.totalPriceLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.inkMuted,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 2),
                  if (showDiscounted)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${l10n.currencyIqd} ${formatPriceIqd(subtotalIqd)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AppColors.inkMuted,
                                decoration: TextDecoration.lineThrough,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${l10n.currencyIqd} ${formatPriceIqd(checkoutTotalIqd)}',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: _luxuryGold,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    )
                  else
                    Text(
                      '${l10n.currencyIqd} ${formatPriceIqd(subtotalIqd)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: OrderViaWhatsAppButton(
                label: l10n.orderViaWhatsApp,
                valueProposition: '',
                onPressed: onOrder,
                enabled: enabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Premium horizontal add-on card: fixed size, white background, image top half, label/price/add.
class _PremiumAddOnCard extends StatelessWidget {
  static const double cardWidth = 150;
  static const double cardHeight = 220;
  static const double imageHeight = 110;

  final AddOnType categoryType;
  final List<AddOnModel> ofType;
  final AddOnModel? selected;
  final String locale;
  final AppLocalizations l10n;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const _PremiumAddOnCard({
    required this.categoryType,
    required this.ofType,
    required this.selected,
    required this.locale,
    required this.l10n,
    this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final title =
        _AddOnPersonalizationSheetState._categoryTitle(l10n, categoryType);
    final iconData =
        _AddOnPersonalizationSheetState._categoryIcon(categoryType);
    final isUnavailable = ofType.isEmpty;
    final displayModel = selected ?? (ofType.isNotEmpty ? ofType.first : null);
    final isSelected = selected != null;

    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: cardWidth,
            height: cardHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: SizedBox(
                    height: imageHeight,
                    width: double.infinity,
                    child: Container(
                      color: const Color(0xFFF0F0F0),
                      child: isUnavailable || displayModel == null
                          ? Center(
                              child: Icon(
                                iconData,
                                color: AppColors.inkMuted.withValues(alpha: 0.5),
                                size: 32,
                              ),
                            )
                          : displayModel.imageUrl.isEmpty
                              ? Shimmer.fromColors(
                                  baseColor: AppColors.border,
                                  highlightColor: Colors.white,
                                  child: Center(
                                    child: Icon(
                                      iconData,
                                      color: AppColors.inkMuted,
                                      size: 28,
                                    ),
                                  ),
                                )
                              : AppCachedImage(
                                  imageUrl: displayModel.imageUrl,
                                  fit: BoxFit.cover,
                                  errorIcon: iconData,
                                  errorIconSize: 28,
                                ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                displayModel != null
                                    ? '${l10n.currencyIqd} ${formatPriceIqd(displayModel.priceIqd)}'
                                    : '—',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.inkMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected && onRemove != null)
                              GestureDetector(
                                onTap: onRemove,
                                child: Text(
                                  l10n.remove,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: AppColors.inkMuted,
                                        decoration: TextDecoration.underline,
                                        fontSize: 11,
                                      ),
                                ),
                              )
                            else if (!isUnavailable)
                              Material(
                                color: AppColors.rosePrimary,
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  onTap: onTap,
                                  borderRadius: BorderRadius.circular(20),
                                  child: const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium free-delivery banner: progress bar with gift icon, rewarding feel.
class _FreeDeliveryBanner extends StatelessWidget {
  final int currentTotal;
  final int threshold;
  final AppLocalizations l10n;

  const _FreeDeliveryBanner({
    required this.currentTotal,
    required this.threshold,
    required this.l10n,
  });

  static const Color _addMoreColor = Color(0xFFE67E22);
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: progressColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: progressColor.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: progressColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            unlocked ? Icons.card_giftcard_rounded : Icons.redeem_rounded,
            size: 28,
            color: progressColor,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: progressColor.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  borderRadius: BorderRadius.circular(6),
                  minHeight: 8,
                ),
                const SizedBox(height: 10),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: progressColor,
                        fontSize: 13,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

