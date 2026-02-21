import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/controllers.dart';
import '../../core/services/whatsapp_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/price_format_utils.dart';
import '../../data/models/add_on_model.dart';
import '../../data/models/flower_model.dart';
import '../../l10n/app_localizations.dart';
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

  bool _isSelected(AddOnModel addOn) =>
      _selectedAddOns.any((a) => a.id == addOn.id);

  void _toggleAddOn(AddOnModel addOn) {
    setState(() {
      _selectedAddOns.removeWhere((a) => a.type == addOn.type);
      if (!_isSelected(addOn)) {
        _selectedAddOns.add(addOn);
      }
    });
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
        return 'Cards';
      default:
        return 'Add-ons';
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
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bouquetAsync = ref.watch(bouquetDetailProvider(widget.flowerId));
    final addOnsAsync = ref.watch(addOnsProvider(null));
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final playfair = GoogleFonts.playfairDisplay(
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    );

    final maxH = MediaQuery.of(context).size.height * 0.85;
    return Container(
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
            style: playfair.copyWith(fontSize: 22),
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
                      style: playfair.copyWith(fontSize: 18),
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
                      style: playfair.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _addOnCategoryOrder.map((categoryType) {
                        final ofType = addOns
                            .where((a) => a.type == categoryType)
                            .toList();
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: categoryType != _addOnCategoryOrder.last
                                  ? 12
                                  : 0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _categoryTitle(categoryType),
                                  style: playfair.copyWith(
                                    fontSize: 14,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 132,
                                  child: ofType.isEmpty
                                      ? Center(
                                          child: Icon(
                                            Icons.card_giftcard,
                                            color: AppColors.inkMuted
                                                .withValues(alpha: 0.5),
                                            size: 32,
                                          ),
                                        )
                                      : ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: ofType.length,
                                          itemBuilder: (context, index) {
                                            final addOn = ofType[index];
                                            final selected =
                                                _isSelected(addOn);
                                            final name = addOn
                                                .nameForLocale(locale);
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: _AddOnModalCard(
                                                addOn: addOn,
                                                name: name,
                                                selected: selected,
                                                onTap: () =>
                                                    _toggleAddOn(addOn),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      l10n.step2VoiceMessage,
                      style: playfair.copyWith(fontSize: 16),
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
                      style: playfair.copyWith(fontSize: 16),
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
                    SizedBox(
                      width: double.infinity,
                      child: OrderViaWhatsAppButton(
                        label: l10n.orderViaWhatsApp,
                        onPressed: () {
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

class _AddOnModalCard extends StatelessWidget {
  final AddOnModel addOn;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _AddOnModalCard({
    required this.addOn,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.rosePrimary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: addOn.imageUrl.isEmpty
                    ? Container(
                        height: 56,
                        color: AppColors.background,
                        child: Icon(
                          Icons.card_giftcard,
                          color: AppColors.inkMuted,
                          size: 28,
                        ),
                      )
                    : SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: AppCachedImage(
                          imageUrl: addOn.imageUrl,
                          fit: BoxFit.cover,
                          errorIcon: Icons.card_giftcard,
                          errorIconSize: 28,
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${l10n.currencyIqd} ${formatPriceIqd(addOn.priceIqd)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 24,
                child: Checkbox(
                  value: selected,
                  onChanged: (_) => onTap(),
                  activeColor: AppColors.rosePrimary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
