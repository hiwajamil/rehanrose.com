import 'package:flutter/material.dart';

import '../../../core/constants/breakpoints.dart';

class SectionContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const SectionContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding = const EdgeInsetsDirectional.symmetric(horizontal: 48, vertical: 56),
  });

  /// Horizontal padding on very narrow phones (e.g. iPhone SE) for more content width.
  static const double _narrowPhonePadding = 12.0;
  static const double _mobilePadding = 16.0;
  static const double _narrowPhoneWidth = 380.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width <= kMobileBreakpoint;
    final effectivePadding = isMobile
        ? EdgeInsetsDirectional.symmetric(
            horizontal: width < _narrowPhoneWidth ? _narrowPhonePadding : _mobilePadding,
            vertical: 24,
          )
        : padding;
    final resolved = effectivePadding.resolve(Directionality.of(context));
    final horizontalPadding = resolved.left + resolved.right;
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
