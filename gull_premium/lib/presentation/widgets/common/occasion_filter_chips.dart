import 'package:flutter/material.dart';

import '../../../core/constants/occasions.dart';

class OccasionFilterChips extends StatefulWidget {
  final String selectedOccasion;
  final ValueChanged<String> onSelected;

  const OccasionFilterChips({
    super.key,
    required this.selectedOccasion,
    required this.onSelected,
  });

  @override
  State<OccasionFilterChips> createState() => _OccasionFilterChipsState();
}

class _OccasionFilterChipsState extends State<OccasionFilterChips> {
  @override
  Widget build(BuildContext context) {
    final filterOptions = ['All', ...kOccasions];
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < filterOptions.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              _FilterChip(
                label: filterOptions[i],
                isSelected: widget.selectedOccasion == filterOptions[i],
                onTap: () => widget.onSelected(filterOptions[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _hovered = false;

  static const Color _selectedBg = Color(0xFF1A1A1A);
  static const Color _unselectedBg = Color(0xFFE0E0E0);

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final bgColor = isSelected
        ? _selectedBg
        : (_hovered ? _unselectedBg.withValues(alpha: 0.85) : _unselectedBg);
    final textColor = isSelected ? Colors.white : Colors.black;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
          ),
        ),
      ),
    );
  }
}
