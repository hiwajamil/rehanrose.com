import 'package:flutter/material.dart';

import '../../../core/constants/breakpoints.dart';

class SectionContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  const SectionContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding = const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width <= kMobileBreakpoint;
    final effectivePadding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
        : padding;
    final horizontalPadding = effectivePadding.left + effectivePadding.right;
    final maxContentWidth = (width - horizontalPadding).clamp(0.0, maxWidth);
    return Padding(
      padding: effectivePadding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: child,
        ),
      ),
    );
  }
}
