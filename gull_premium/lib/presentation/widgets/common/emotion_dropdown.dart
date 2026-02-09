import 'package:flutter/material.dart';

import '../../../core/constants/breakpoints.dart';
import '../../../core/constants/emotion_category.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/emotion_category_l10n.dart';
import '../../../core/utils/rtl_utils.dart';
import '../../../l10n/app_localizations.dart';

/// Emotion-based dropdown for landing page. Uses new emotion categories (love, apology, etc.).
class EmotionDropdown extends StatelessWidget {
  final String? selectedEmotionValue;
  final ValueChanged<String?> onChanged;

  const EmotionDropdown({
    super.key,
    this.selectedEmotionValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    final selectedCategory = getEmotionCategoryById(selectedEmotionValue);
    final selectedLabel = selectedCategory != null
        ? localizedEmotionCategoryTitle(l10n, selectedCategory.titleKey)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.home_question,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w500,
                fontSize: isMobile ? 15 : 16,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: isValidEmotionCategoryId(selectedEmotionValue)
                  ? selectedEmotionValue
                  : null,
              hint: Text(
                l10n.chooseEmotion,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkMuted.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w400,
                    ),
              ),
              isExpanded: true,
              icon: directionalIcon(
                context,
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.inkMuted.withValues(alpha: 0.7),
              ),
              borderRadius: BorderRadius.circular(20),
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: isMobile ? 18 : 24,
                vertical: isMobile ? 14 : 18,
              ),
              dropdownColor: Colors.white,
              items: kEmotionCategories.map((c) {
                final label = localizedEmotionCategoryTitle(l10n, c.titleKey);
                return DropdownMenuItem<String>(
                  value: c.id,
                  child: Row(
                    textDirection: Directionality.of(context),
                    children: [
                      Icon(
                        c.icon,
                        size: 22,
                        color: AppColors.rose,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        if (selectedLabel != null && selectedLabel.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            l10n.microCopyBouquetsFor(selectedLabel),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: AppColors.inkMuted.withValues(alpha: 0.9),
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ],
    );
  }
}
