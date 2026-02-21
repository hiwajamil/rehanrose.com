import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_format_utils.dart';
import '../../../data/models/add_on_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/common/app_cached_image.dart';

/// Dedicated screen for selecting an add-on variant within a category (Vase, Chocolate, Card).
/// User taps their preferred item, then clicks "Add" to confirm and return to the Add-on screen.
class AddOnVariantSelectionPage extends StatefulWidget {
  final AddOnType categoryType;
  final List<AddOnModel> variants;

  const AddOnVariantSelectionPage({
    super.key,
    required this.categoryType,
    required this.variants,
  });

  static Future<AddOnModel?> open(
    BuildContext context, {
    required AddOnType categoryType,
    required List<AddOnModel> variants,
  }) {
    if (variants.isEmpty) return Future.value(null);
    return Navigator.of(context).push<AddOnModel?>(
      MaterialPageRoute<AddOnModel?>(
        builder: (context) => AddOnVariantSelectionPage(
          categoryType: categoryType,
          variants: variants,
        ),
      ),
    );
  }

  @override
  State<AddOnVariantSelectionPage> createState() =>
      _AddOnVariantSelectionPageState();
}

class _AddOnVariantSelectionPageState extends State<AddOnVariantSelectionPage> {
  AddOnModel? _selected;

  String _title(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (widget.categoryType) {
      case AddOnType.vase:
        return l10n.addOnChooseVases;
      case AddOnType.chocolate:
        return l10n.addOnChooseChocolates;
      case AddOnType.card:
        return l10n.addOnChooseCards;
      case AddOnType.teddyBear:
        return l10n.addOnChooseAddOn;
    }
  }

  void _onAdd() {
    if (_selected != null) {
      Navigator.of(context).pop(_selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _title(context),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.82,
              ),
              itemCount: widget.variants.length,
              itemBuilder: (context, index) {
                final addOn = widget.variants[index];
                final isSelected = _selected?.id == addOn.id;
                final name = addOn.nameForLocale(locale);

                return Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => setState(() => _selected = addOn),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.rosePrimary
                              : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: addOn.imageUrl.isEmpty
                                  ? Container(
                                      color: AppColors.background,
                                      child: Icon(
                                        Icons.card_giftcard,
                                        color: AppColors.inkMuted,
                                        size: 48,
                                      ),
                                    )
                                  : AppCachedImage(
                                      imageUrl: addOn.imageUrl,
                                      fit: BoxFit.cover,
                                      errorIcon: Icons.card_giftcard,
                                      errorIconSize: 48,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            name,
                            style:
                                Theme.of(context).textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink,
                                    ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${l10n.currencyIqd} ${formatPriceIqd(addOn.priceIqd)}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.inkMuted,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
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
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected != null ? _onAdd : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rosePrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(l10n.addOnAddButton),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
