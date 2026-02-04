import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum PrimaryButtonVariant { primary, filled, outline }

class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final PrimaryButtonVariant variant;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PrimaryButtonVariant.filled,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isOutline = widget.variant == PrimaryButtonVariant.outline;
    final isPrimary = widget.variant == PrimaryButtonVariant.primary;
    final fillColor = isPrimary
        ? AppColors.rosePrimary
        : (widget.variant == PrimaryButtonVariant.filled
            ? AppColors.rose
            : Colors.transparent);
    final baseColor = isOutline ? Colors.transparent : fillColor;
    final hoverColor = isOutline
        ? AppColors.rose.withValues(alpha:0.04)
        : fillColor;
    final borderColor =
        isOutline ? AppColors.border : fillColor;
    final textColor = isOutline ? AppColors.inkMuted : Colors.white;
    final scale = (isPrimary && _hovered) ? 1.03 : 1.0;
    final List<BoxShadow> softShadow = isPrimary
        ? [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha:0.12),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            if (_hovered)
              BoxShadow(
                color: AppColors.shadow.withValues(alpha:0.18),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
          ]
        : <BoxShadow>[];

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _hovered ? hoverColor : baseColor,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: isOutline && !_hovered
                  ? AppColors.border
                  : (isOutline ? AppColors.rose.withValues(alpha:0.4) : borderColor),
              width: isOutline ? 1.0 : 1.2,
            ),
            boxShadow: softShadow,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(40),
              onTap: widget.onPressed,
              hoverColor: Colors.transparent,
              splashColor: isOutline
                  ? AppColors.rose.withValues(alpha:0.08)
                  : Colors.white.withValues(alpha:0.2),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                child: Text(
                  widget.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isOutline && !_hovered
                            ? AppColors.inkMuted
                            : (isOutline ? AppColors.rose : textColor),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
