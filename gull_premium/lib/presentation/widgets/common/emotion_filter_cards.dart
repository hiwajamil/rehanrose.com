import 'package:flutter/material.dart';

import '../../../core/constants/emotion_category.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/emotion_category_l10n.dart';
import '../../../l10n/app_localizations.dart';

/// Emotion-based category filter cards. Uses new emotion categories (love, apology, etc.).
class EmotionFilterCards extends StatelessWidget {
  final String selectedOccasion;
  final ValueChanged<String> onSelected;

  const EmotionFilterCards({
    super.key,
    required this.selectedOccasion,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      textDirection: Directionality.of(context),
      children: [
        _EmotionCard(
          label: l10n.filterAll,
          isSelected: selectedOccasion == 'All',
          onTap: () => onSelected('All'),
        ),
        ...kEmotionCategories.map((c) {
          final isSelected = selectedOccasion == c.id;
          return _EmotionCard(
            label: localizedEmotionCategoryTitle(l10n, c.titleKey),
            isSelected: isSelected,
            onTap: () => onSelected(c.id),
          );
        }),
      ],
    );
  }
}

class _EmotionCard extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _EmotionCard({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_EmotionCard> createState() => _EmotionCardState();
}

class _EmotionCardState extends State<_EmotionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isSelected
        ? AppColors.rose.withValues(alpha: 0.12)
        : (_hovered
            ? AppColors.border.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.9));
    final borderColor = widget.isSelected
        ? AppColors.rose.withValues(alpha: 0.4)
        : AppColors.border;
    final textColor = widget.isSelected ? AppColors.ink : AppColors.inkMuted;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 15,
                ),
          ),
        ),
      ),
    );
  }
}
