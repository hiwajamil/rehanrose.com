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
import '../pages/product/add_on_selection_sheet.dart';
import 'common/order_via_whatsapp_button.dart';
import 'voice_message_dialog.dart';

/// Opens the Add-on & Personalization dialog (centered) for the given bouquet.
/// Step 1: Add-ons (multi-select). Step 2: Voice message QR. Step 3: Order via WhatsApp.
void showAddOnPersonalizationModal(BuildContext context, String flowerId) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
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

  /// Opens a window listing all add-ons of this type (e.g. Vase) with price and Add button.
  void _openAddOnDetail(AddOnModel addOn, List<AddOnModel> allAddOns) {
    final ofType =
        allAddOns.where((a) => a.type == addOn.type && a.isActive).toList();
    if (ofType.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddOnSelectionSheet(
        addOns: ofType,
        onSelect: (selected) {
          Navigator.of(ctx).pop();
          setState(() {
            _selectedAddOns.removeWhere((a) => a.type == selected.type);
            _selectedAddOns.add(selected);
          });
        },
      ),
    );
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
    launchOrderWhatsApp(
      flowerName: bouquet.name,
      flowerPrice: formatPriceWithCurrency(bouquet.priceIqd, l10n.currencyIqd),
      flowerId: bouquet.id,
      flowerImageUrl: bouquet.imageUrls.isNotEmpty ? bouquet.imageUrls.first : '',
      bouquetCode:
          bouquet.bouquetCode.isNotEmpty ? bouquet.bouquetCode : null,
      selectedAddOns:
          _selectedAddOns.isEmpty ? null : List.from(_selectedAddOns),
      totalPriceIqd: _totalPriceIqd(bouquet),
      productUrl: productUrl,
      voiceMessageUrl: _voiceMessageUrl,
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
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 112,
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(right: 24),
                          itemCount: addOns.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                          final addOn = addOns[index];
                          final selected = _isSelected(addOn);
                          final name = addOn.nameForLocale(locale);
                          return _AddOnChip(
                            name: name,
                            priceIqd: addOn.priceIqd,
                            selected: selected,
                            onTap: () => _openAddOnDetail(addOn, addOns),
                          );
                        },
                        ),
                      ),
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

class _AddOnChip extends StatelessWidget {
  final String name;
  final int priceIqd;
  final bool selected;
  final VoidCallback onTap;

  const _AddOnChip({
    required this.name,
    required this.priceIqd,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.rosePrimary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    selected ? Icons.check_circle : Icons.add_circle_outline,
                    size: 20,
                    color: selected ? AppColors.rosePrimary : AppColors.inkMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${AppLocalizations.of(context)!.currencyIqd} ${formatPriceIqd(priceIqd)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
