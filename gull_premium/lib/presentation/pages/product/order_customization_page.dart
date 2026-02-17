import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../controllers/controllers.dart';
import '../../../core/services/whatsapp_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_format_utils.dart';
import '../../../data/models/add_on_model.dart';
import '../../../data/models/flower_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/common/app_cached_image.dart';
import '../../widgets/common/order_via_whatsapp_button.dart';
import '../../widgets/layout/app_scaffold.dart';
import 'add_on_selection_sheet.dart';

/// Product Details & Customization (Upsell) page.
/// Flow: Order via WhatsApp -> this page -> user picks add-ons -> ORDER VIA WHATSAPP opens WhatsApp.
class OrderCustomizationPage extends ConsumerStatefulWidget {
  final String flowerId;

  const OrderCustomizationPage({super.key, required this.flowerId});

  @override
  ConsumerState<OrderCustomizationPage> createState() =>
      _OrderCustomizationPageState();
}

class _OrderCustomizationPageState extends ConsumerState<OrderCustomizationPage> {
  AddOnModel? _selectedVase;
  AddOnModel? _selectedChocolate;
  AddOnModel? _selectedCard;

  void _onAddOnSelected(AddOnModel addOn) {
    setState(() {
      switch (addOn.type) {
        case AddOnType.vase:
          _selectedVase = addOn;
          break;
        case AddOnType.chocolate:
          _selectedChocolate = addOn;
          break;
        case AddOnType.card:
          _selectedCard = addOn;
          break;
        case AddOnType.teddyBear:
          // Not in the three cards; could extend later.
          break;
      }
    });
  }

  int _totalPriceIqd(FlowerModel bouquet) {
    var total = bouquet.priceIqd;
    if (_selectedVase != null) total += _selectedVase!.priceIqd;
    if (_selectedChocolate != null) total += _selectedChocolate!.priceIqd;
    if (_selectedCard != null) total += _selectedCard!.priceIqd;
    return total;
  }

  List<AddOnModel> _selectedAddOnsList() {
    return [
      if (_selectedVase != null) _selectedVase!,
      if (_selectedChocolate != null) _selectedChocolate!,
      if (_selectedCard != null) _selectedCard!,
    ];
  }

  void _openAddOnSheet(AddOnType type, List<AddOnModel> addOns) {
    final filtered =
        addOns.where((a) => a.type == type && a.isActive).toList();
    if (filtered.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddOnSelectionSheet(
        addOns: filtered,
        onSelect: (addOn) {
          Navigator.of(context).pop();
          _onAddOnSelected(addOn);
        },
      ),
    );
  }

  void _orderViaWhatsApp(FlowerModel bouquet) {
    final l10n = AppLocalizations.of(context)!;
    final productUrl = '${Uri.base.origin}/p/${widget.flowerId}';
    launchOrderWhatsApp(
      flowerName: bouquet.name,
      flowerPrice: formatPriceWithCurrency(bouquet.priceIqd, l10n.currencyIqd),
      flowerId: widget.flowerId,
      flowerImageUrl: bouquet.imageUrls.isNotEmpty
          ? bouquet.imageUrls.first
          : '',
      bouquetCode:
          bouquet.bouquetCode.isNotEmpty ? bouquet.bouquetCode : null,
      selectedAddOns: _selectedAddOnsList().isEmpty ? null : _selectedAddOnsList(),
      totalPriceIqd: _totalPriceIqd(bouquet),
      productUrl: productUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bouquetAsync = ref.watch(bouquetDetailProvider(widget.flowerId));
    final addOnsAsync = ref.watch(addOnsProvider(null));
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    return AppScaffold(
      child: bouquetAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Product not found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
        data: (bouquet) {
          if (bouquet == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Product not found',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go back'),
                  ),
                ],
              ),
            );
          }

          final imageUrl = bouquet.imageUrls.isNotEmpty
              ? bouquet.imageUrls.first
              : 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80';
          final addOns = addOnsAsync.maybeWhen(
              data: (list) => list, orElse: () => <AddOnModel>[]);
          final total = _totalPriceIqd(bouquet);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top: large image + name + base price
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 4 / 5,
                          child: AppCachedImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 800,
                            memCacheHeight: 1000,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        bouquet.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        iqdPriceString(bouquet.priceIqd),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 28),
                      // Make it Special
                      Text(
                        l10n.makeItSpecialSectionTitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 400;
                          if (isNarrow) {
                            return Column(
                              children: [
                                _AddOnCard(
                                  type: AddOnType.vase,
                                  selected: _selectedVase,
                                  locale: locale,
                                  onTap: () =>
                                      _openAddOnSheet(AddOnType.vase, addOns),
                                ),
                                const SizedBox(height: 12),
                                _AddOnCard(
                                  type: AddOnType.chocolate,
                                  selected: _selectedChocolate,
                                  locale: locale,
                                  onTap: () => _openAddOnSheet(
                                      AddOnType.chocolate, addOns),
                                ),
                                const SizedBox(height: 12),
                                _AddOnCard(
                                  type: AddOnType.card,
                                  selected: _selectedCard,
                                  locale: locale,
                                  onTap: () =>
                                      _openAddOnSheet(AddOnType.card, addOns),
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: _AddOnCard(
                                  type: AddOnType.vase,
                                  selected: _selectedVase,
                                  locale: locale,
                                  onTap: () => _openAddOnSheet(
                                      AddOnType.vase, addOns),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _AddOnCard(
                                  type: AddOnType.chocolate,
                                  selected: _selectedChocolate,
                                  locale: locale,
                                  onTap: () => _openAddOnSheet(
                                      AddOnType.chocolate, addOns),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _AddOnCard(
                                  type: AddOnType.card,
                                  selected: _selectedCard,
                                  locale: locale,
                                  onTap: () => _openAddOnSheet(
                                      AddOnType.card, addOns),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom fixed bar
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.totalPriceLabel,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.inkMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            '${l10n.currencyIqd} ${formatPriceIqd(total)}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                          enabled: ref.watch(connectivityStatusProvider).value ?? true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AddOnCard extends StatelessWidget {
  final AddOnType type;
  final AddOnModel? selected;
  final String locale;
  final VoidCallback onTap;

  const _AddOnCard({
    required this.type,
    required this.selected,
    required this.locale,
    required this.onTap,
  });

  IconData get _icon {
    switch (type) {
      case AddOnType.vase:
        return Icons.local_florist_outlined;
      case AddOnType.chocolate:
        return Icons.card_giftcard_outlined;
      case AddOnType.card:
        return Icons.celebration_outlined;
      case AddOnType.teddyBear:
        return Icons.pets_outlined;
    }
  }

  String _label(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case AddOnType.vase:
        return l10n.addVaseLabel;
      case AddOnType.chocolate:
        return l10n.addChocolateLabel;
      case AddOnType.card:
        return l10n.addCardLabel;
      case AddOnType.teddyBear:
        return 'Teddy';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = selected != null;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.rosePrimary : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isSelected && selected!.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: AppCachedImage(
                      imageUrl: selected!.imageUrl,
                      fit: BoxFit.cover,
                      errorIcon: _icon,
                      errorIconSize: 40,
                    ),
                  ),
                )
              else
                Icon(_icon, size: 40, color: AppColors.inkMuted),
              const SizedBox(height: 8),
              Text(
                _label(context),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              if (isSelected)
                Text(
                  '${AppLocalizations.of(context)!.currencyIqd} ${formatPriceIqd(selected!.priceIqd)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                  textAlign: TextAlign.center,
                )
              else
                Text(
                  AppLocalizations.of(context)!.selectLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
