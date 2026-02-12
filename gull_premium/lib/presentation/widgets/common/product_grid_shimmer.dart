import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';

/// Skeleton placeholder for a product card in the grid.
/// Matches [FlowerCard] layout: image area (aspect 0.65), title line, price line.
/// Uses shimmer package for a moving gradient effect.
class ProductGridShimmer extends StatelessWidget {
  /// When true, uses compact layout (smaller padding/radii) to match mobile grid.
  final bool isCompact;

  const ProductGridShimmer({super.key, this.isCompact = false});

  /// Same aspect ratio as [FlowerCard] image area.
  static const double _imageAspectRatio = 0.65;

  @override
  Widget build(BuildContext context) {
    final borderRadius = isCompact ? 14.0 : 24.0;
    final contentPadding = isCompact ? 8.0 : 20.0;

    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.surface,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image placeholder
              AspectRatio(
                aspectRatio: _imageAspectRatio,
                child: Container(
                  color: AppColors.border,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: contentPadding,
                  vertical: isCompact ? 8 : 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title line
                    Container(
                      height: isCompact ? 18 : 22,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(height: isCompact ? 4 : 6),
                    // Price line (smaller)
                    Container(
                      height: isCompact ? 14 : 18,
                      width: 80,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid of [ProductGridShimmer] placeholders (e.g. 6 items) using the same
/// responsive layout as the product grid (crossAxisCount, gap, childWidth).
class ProductGridShimmerGrid extends StatelessWidget {
  /// Number of shimmer cards to show.
  final int itemCount;

  const ProductGridShimmerGrid({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < kMobileBreakpoint;
    final crossAxisCount = width < kMobileBreakpoint
        ? 2
        : width < kTabletBreakpoint
            ? 3
            : 4;
    final gap = width < kMobileBreakpoint ? (width < 380 ? 8.0 : 10.0) : 16.0;
    final gapTotal = (crossAxisCount - 1) * gap;

    return LayoutBuilder(
      builder: (context, constraints) {
        final childWidth = (constraints.maxWidth - gapTotal) / crossAxisCount;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(
            itemCount,
            (_) => SizedBox(
              width: childWidth,
              child: ProductGridShimmer(isCompact: isMobile),
            ),
          ),
        );
      },
    );
  }
}
