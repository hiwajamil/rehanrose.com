import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/add_on_model.dart';
import '../../../l10n/app_localizations.dart';

/// Cross-sell section before Place Order: "Make it Perfect?" with add-ons.
/// Shows horizontal scrollable list; selection updates via [onSelectionChanged].
class MakeItPerfectSection extends StatelessWidget {
  final List<AddOnModel> addOns;
  final Set<String> selectedAddOnIds;
  final ValueChanged<AddOnModel> onToggle;
  final int bouquetPriceIqd;

  const MakeItPerfectSection({
    super.key,
    required this.addOns,
    required this.selectedAddOnIds,
    required this.onToggle,
    required this.bouquetPriceIqd,
  });

  int get _addOnsTotal =>
      addOns
          .where((a) => selectedAddOnIds.contains(a.id))
          .fold<int>(0, (s, a) => s + a.priceIqd);

  int get totalPriceIqd => bouquetPriceIqd + _addOnsTotal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    if (addOns.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.makeItPerfectSectionTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: addOns.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final addOn = addOns[index];
              final isSelected = selectedAddOnIds.contains(addOn.id);
              return _AddOnChip(
                addOn: addOn,
                locale: locale,
                isSelected: isSelected,
                onTap: () => onToggle(addOn),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _totalLabel(context),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.inkMuted,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  String _totalLabel(BuildContext context) {
    if (selectedAddOnIds.isEmpty) {
      return 'IQD $bouquetPriceIqd';
    }
    return 'IQD $bouquetPriceIqd + ${selectedAddOnIds.length} add-on(s) = IQD $totalPriceIqd';
  }
}

class _AddOnChip extends StatelessWidget {
  final AddOnModel addOn;
  final String locale;
  final bool isSelected;
  final VoidCallback onTap;

  const _AddOnChip({
    required this.addOn,
    required this.locale,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = addOn.nameForLocale(locale);
    return Material(
      color: isSelected ? AppColors.blush.withValues(alpha: 0.4) : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.rosePrimary : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: addOn.imageUrl.isEmpty
                      ? Icon(Icons.card_giftcard, color: AppColors.inkMuted)
                      : Image.network(
                          addOn.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.card_giftcard,
                            color: AppColors.inkMuted,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'IQD ${addOn.priceIqd}',
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
