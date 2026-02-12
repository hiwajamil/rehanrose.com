import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_cache_manager.dart';

/// Cached network image with shimmer placeholder and flower/placeholder error widget.
/// Uses app-wide 7-day cache.
class AppCachedImage extends StatelessWidget {
  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
    this.borderRadius,
    this.errorIcon = Icons.local_florist,
    this.errorIconSize = 48,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final BorderRadius? borderRadius;
  final IconData errorIcon;
  final double errorIconSize;

  /// Placeholder shown while the image is loading (shimmer).
  static Widget shimmerPlaceholder(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.surface,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.border,
      ),
    );
  }

  /// Error widget when the image fails to load (flower placeholder).
  static Widget flowerErrorWidget(BuildContext context, {IconData icon = Icons.local_florist, double size = 48}) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.border,
      child: Center(
        child: Icon(icon, size: size, color: AppColors.inkMuted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget child = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      cacheManager: appCacheManager,
      placeholder: (_, __) => shimmerPlaceholder(context),
      errorWidget: (_, __, ___) => flowerErrorWidget(context, icon: errorIcon, size: errorIconSize),
    );
    if (borderRadius != null) {
      child = ClipRRect(
        borderRadius: borderRadius!,
        child: child,
      );
    }
    return child;
  }
}
