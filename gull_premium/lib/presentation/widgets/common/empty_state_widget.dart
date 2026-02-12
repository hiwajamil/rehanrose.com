import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// A reusable empty state widget for when lists or content are empty.
///
/// Use for "No flowers found", "No results", empty cart, etc.
/// Optionally show an action button (e.g. "Go Back", "Clear Filters").
class EmptyStateWidget extends StatelessWidget {
  /// Short message shown below the illustration (e.g. "No flowers found in this category").
  final String message;

  /// Optional icon. Ignored if [image] is non-null. Defaults to a neutral empty-state icon.
  final IconData? icon;

  /// Optional custom image/illustration widget. If set, [icon] is ignored.
  final Widget? image;

  /// Optional label for the action button.
  final String? buttonText;

  /// Optional callback when the action button is pressed. Button is only shown when both [buttonText] and [onPressed] are set.
  final VoidCallback? onPressed;

  const EmptyStateWidget({
    super.key,
    required this.message,
    this.icon,
    this.image,
    this.buttonText,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showButton = buttonText != null && buttonText!.isNotEmpty && onPressed != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (image != null) ...[
              image!,
            ] else ...[
              Icon(
                icon ?? Icons.inbox_outlined,
                size: 80,
                color: AppColors.inkMuted.withValues(alpha: 0.5),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.inkMuted,
                height: 1.4,
              ),
            ),
            if (showButton) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(buttonText!),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rosePrimary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
