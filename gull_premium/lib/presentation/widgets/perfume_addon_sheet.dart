import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../controllers/controllers.dart';
import '../../core/services/whatsapp_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/price_format_utils.dart';
import '../../data/models/flower_model.dart';
import '../../l10n/app_localizations.dart';
import '../pages/product/delivery_map_picker.dart';
import 'add_on_personalization_modal.dart';
import 'common/app_cached_image.dart';
import 'common/order_via_whatsapp_button.dart';
import 'voice_message_dialog.dart';

/// Payload for [PerfumeAddonBottomSheet] (luxury perfumes on the landing page).
class PerfumeAddonData {
  PerfumeAddonData({required this.product, required this.brand});

  final FlowerModel product;
  final String brand;

  factory PerfumeAddonData.fromItemMap(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final copy = Map<String, dynamic>.from(item)..remove('id');
    final brandRaw = item['brand']?.toString().trim() ?? '';
    return PerfumeAddonData(
      product: FlowerModel.fromJson(id, copy),
      brand: brandRaw.isNotEmpty ? brandRaw : 'Luxury Brand',
    );
  }
}

int _effectiveFlowerPriceIqd(FlowerModel b) {
  if (b.isOnSaleEffective && b.discountPrice != null && b.discountPrice! > 0) {
    return b.discountPrice!;
  }
  return b.priceIqd;
}

/// Checkout / add-on bottom sheet for perfumes (bouquet flow stays on [showAddOnPersonalizationModal]).
class PerfumeAddonBottomSheet extends ConsumerStatefulWidget {
  const PerfumeAddonBottomSheet({super.key, required this.perfume});

  final PerfumeAddonData perfume;

  @override
  ConsumerState<PerfumeAddonBottomSheet> createState() =>
      _PerfumeAddonBottomSheetState();
}

class _PerfumeAddonBottomSheetState extends ConsumerState<PerfumeAddonBottomSheet> {
  final List<FlowerModel> _bouquetChoices = [];
  FlowerModel? _selectedBouquet;
  String? _voiceMessageUrl;
  LatLng? _deliveryLatLng;
  bool _bouquetsLoading = true;
  bool _bouquetsFailed = false;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadBouquetSuggestions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBouquetSuggestions() async {
    setState(() {
      _bouquetsLoading = true;
      _bouquetsFailed = false;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bouquets')
          .where('approvalStatus', isEqualTo: 'approved')
          .limit(10)
          .get();
      if (!mounted) return;
      final list =
          snap.docs.map((d) => FlowerModel.fromJson(d.id, d.data())).toList();
      list.shuffle(Random());
      setState(() {
        _bouquetChoices.clear();
        _bouquetChoices.addAll(list.take(4));
        _bouquetsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bouquetsLoading = false;
        _bouquetsFailed = true;
      });
    }
  }

  int _totalIqd() {
    var t = _effectiveFlowerPriceIqd(widget.perfume.product);
    if (_selectedBouquet != null) {
      t += _effectiveFlowerPriceIqd(_selectedBouquet!);
    }
    return t;
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

  void _toggleBouquet(FlowerModel b) {
    setState(() {
      if (_selectedBouquet?.id == b.id) {
        _selectedBouquet = null;
      } else {
        _selectedBouquet = b;
      }
    });
  }

  void _orderViaWhatsApp() {
    final p = widget.perfume.product;
    final total = _totalIqd();
    ref.read(analyticsServiceProvider).logClickWhatsApp(
          itemId: p.id,
          itemName: p.name,
        );
    if (_selectedBouquet != null) {
      ref.read(bouquetRepositoryProvider).incrementOrderCount(_selectedBouquet!.id);
    }
    launchPerfumeOrderWhatsApp(
      perfumeName: p.name,
      brand: widget.perfume.brand,
      totalPriceIqd: total,
      addOnBouquetName: _selectedBouquet?.name,
      hasVoiceMessage: _voiceMessageUrl != null && _voiceMessageUrl!.isNotEmpty,
      deliveryLocation: _deliveryLatLng != null
          ? DeliveryLatLng(_deliveryLatLng!.latitude, _deliveryLatLng!.longitude)
          : null,
      voiceMessageUrl: _voiceMessageUrl,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = widget.perfume.product;
    final total = _totalIqd();
    final montserrat = GoogleFonts.montserrat(
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    );
    final sectionTitleStyle = GoogleFonts.montserrat(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    );
    final maxH = MediaQuery.of(context).size.height * 0.88;

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.montserratTextTheme(Theme.of(context).textTheme),
      ),
      child: SizedBox(
        height: maxH,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.addOnPersonalizationTitle,
              style: montserrat.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                children: [
                  Text(
                    p.name,
                    style: montserrat.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.perfume.brand,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF9A7A2D),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${l10n.currencyIqd} ${formatPriceIqd(_effectiveFlowerPriceIqd(p))}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.inkMuted,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.perfumeCheckoutWithBouquetSection,
                    style: sectionTitleStyle,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 210,
                    child: _bouquetsLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _bouquetsFailed || _bouquetChoices.isEmpty
                            ? Center(
                                child: Text(
                                  l10n.couldNotLoadBouquets,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: AppColors.inkMuted),
                                ),
                              )
                            : ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _bouquetChoices.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final b = _bouquetChoices[index];
                                  final selected =
                                      _selectedBouquet?.id == b.id;
                                  return _BouquetSuggestCard(
                                    bouquet: b,
                                    l10n: l10n,
                                    selected: selected,
                                    onTap: () => _toggleBouquet(b),
                                  );
                                },
                              ),
                  ),
                  const SizedBox(height: 24),
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
                  _PerfumeFreeDeliveryBanner(
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
                  const SizedBox(height: 16),
                ],
              ),
            ),
              _StickyPerfumeCheckoutBar(
                total: total,
                l10n: l10n,
                onOrder: () {
                  if (_deliveryLatLng == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(
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
                  _orderViaWhatsApp();
                },
                enabled: ref.watch(connectivityStatusProvider).value ?? true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickyPerfumeCheckoutBar extends StatelessWidget {
  const _StickyPerfumeCheckoutBar({
    required this.total,
    required this.l10n,
    required this.onOrder,
    required this.enabled,
  });

  final int total;
  final AppLocalizations l10n;
  final VoidCallback onOrder;
  final bool enabled;

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
                  Text(
                    '${l10n.currencyIqd} ${formatPriceIqd(total)}',
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

class _BouquetSuggestCard extends StatelessWidget {
  const _BouquetSuggestCard({
    required this.bouquet,
    required this.l10n,
    required this.selected,
    required this.onTap,
  });

  static const double cardWidth = 150;
  static const double cardHeight = 200;
  static const double imageHeight = 108;

  final FlowerModel bouquet;
  final AppLocalizations l10n;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = bouquet.listingImageUrl.isNotEmpty
        ? bouquet.listingImageUrl
        : '';
    final price = _effectiveFlowerPriceIqd(bouquet);

    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.rosePrimary : AppColors.border,
                width: selected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(15)),
                  child: SizedBox(
                    height: imageHeight,
                    width: double.infinity,
                    child: url.isEmpty
                        ? Center(
                            child: Icon(
                              Icons.local_florist_outlined,
                              color: AppColors.inkMuted.withValues(alpha: 0.5),
                              size: 32,
                            ),
                          )
                        : AppCachedImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            errorIcon: Icons.local_florist_outlined,
                            errorIconSize: 28,
                          ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          bouquet.name,
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${l10n.currencyIqd} ${formatPriceIqd(price)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.inkMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              size: 22,
                              color: selected
                                  ? AppColors.rosePrimary
                                  : AppColors.inkMuted,
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

class _PerfumeFreeDeliveryBanner extends StatelessWidget {
  const _PerfumeFreeDeliveryBanner({
    required this.currentTotal,
    required this.threshold,
    required this.l10n,
  });

  final int currentTotal;
  final int threshold;
  final AppLocalizations l10n;

  static const Color _addMoreColor = Color(0xFFE67E22);
  static const Color _unlockedColor = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    final unlocked = currentTotal >= threshold;
    final progress =
        unlocked ? 1.0 : (currentTotal / threshold).clamp(0.0, 1.0);
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
