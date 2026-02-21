import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_format_utils.dart';
import '../../../data/models/add_on_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/common/app_cached_image.dart';

/// Bottom sheet showing add-ons of one type in a grid; each card has image, price, ADD button.
class AddOnSelectionSheet extends StatelessWidget {
  final List<AddOnModel> addOns;
  final ValueChanged<AddOnModel> onSelect;

  const AddOnSelectionSheet({
    super.key,
    required this.addOns,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final padding = MediaQuery.paddingOf(context);

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.montserratTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Choose an add-on',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
            ),
          ),
          const SizedBox(height: 20),
          Flexible(
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(24, 0, 24, padding.bottom + 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemCount: addOns.length,
              itemBuilder: (context, index) {
                final addOn = addOns[index];
                return _AddOnGridTile(
                  addOn: addOn,
                  locale: locale,
                  onAdd: () => onSelect(addOn),
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

class _AddOnGridTile extends StatelessWidget {
  final AddOnModel addOn;
  final String locale;
  final VoidCallback onAdd;

  const _AddOnGridTile({
    required this.addOn,
    required this.locale,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final name = addOn.nameForLocale(locale);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: addOn.imageUrl.isEmpty
                      ? Icon(Icons.card_giftcard, color: AppColors.inkMuted, size: 48)
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
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${AppLocalizations.of(context)!.currencyIqd} ${formatPriceIqd(addOn.priceIqd)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: FilledButton(
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rosePrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('ADD'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
