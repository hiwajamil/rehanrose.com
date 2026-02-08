import 'package:flutter/material.dart';

import '../../../core/constants/breakpoints.dart';
import '../../../core/constants/emotion_categories.dart';
import '../../../core/theme/app_colors.dart';

/// Emotion-based dropdown for landing page.
/// Label: "What do you want to say today?"
/// Placeholder: "Choose an emotion"
/// Selecting immediately filters bouquets (no submit).
class EmotionDropdown extends StatelessWidget {
  final String? selectedEmotionLabel;
  final ValueChanged<String?> onChanged;

  const EmotionDropdown({
    super.key,
    this.selectedEmotionLabel,
    required this.onChanged,
  });

  /// Micro-copy for selected emotion: "Flowers that say Love" or "Bouquets for Gratitude"
  static String microCopyFor(String displayLabel) {
    final text = displayLabel.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (text.isEmpty) return '';
    if (['Love', 'Romance', 'Sympathy', 'Apology'].contains(text)) {
      return 'Flowers that say $text';
    }
    return 'Bouquets for $text';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'What do you want to say today?',
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
              value: selectedEmotionLabel,
              hint: Text(
                'Choose an emotion',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkMuted.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w400,
                    ),
              ),
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.inkMuted.withValues(alpha: 0.7),
              ),
              borderRadius: BorderRadius.circular(20),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 18 : 24,
                vertical: isMobile ? 14 : 18,
              ),
              dropdownColor: Colors.white,
              items: kEmotions.map((e) {
                return DropdownMenuItem<String>(
                  value: e.label,
                  child: Row(
                    children: [
                      if (e.icon != null) ...[
                        Icon(
                          e.icon,
                          size: 22,
                          color: AppColors.rose,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          e.label,
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
        if (selectedEmotionLabel != null && selectedEmotionLabel!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            microCopyFor(selectedEmotionLabel!),
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
