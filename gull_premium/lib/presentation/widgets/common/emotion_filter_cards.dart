import 'package:flutter/material.dart';

import '../../../core/constants/emotion_categories.dart';
import '../../../core/theme/app_colors.dart';

/// Emotion-based category cards. Soft colors, no animation overload.
/// Selecting a card filters bouquets by the corresponding occasion.
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
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _EmotionCard(
          label: 'All Feelings',
          isSelected: selectedOccasion == 'All',
          onTap: () => onSelected('All'),
        ),
        ...kEmotions.map((e) {
          final isSelected = selectedOccasion == e.value;
          return _EmotionCard(
            label: e.label,
            isSelected: isSelected,
            onTap: () => onSelected(e.value),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(28),
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
