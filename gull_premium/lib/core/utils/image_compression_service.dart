import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

/// Image compression and optimization for vendor uploads.
///
/// Converts JPG/PNG/HEIC to WebP, resizes to max 1080px with min 800px on
/// the shorter side, 85% quality (target ~100–150 KB). Thumbnails are
/// optional and larger (600px) for any grid use; Product Cards use full-size.
class ImageCompressionService {
  ImageCompressionService._();

  /// Max dimension for full-size images (product detail and cards). 1080px
  /// keeps a premium look while limiting file size.
  static const int fullSizeMaxWidth = 1080;

  /// Minimum dimension for full-size so we never shrink to a tiny thumbnail.
  /// Ensures output is at least 800px on the shorter side when source allows.
  static const int fullSizeMinDimension = 800;

  /// Optional higher-res max width for zoom (e.g. product detail zoom view).
  static const int fullSizeMaxWidthZoom = 1920;

  /// Compression quality (0–100). 85% for premium look, target ~100–150 KB.
  static const int quality = 85;

  /// Max size in bytes for add-on images (e.g. 500 KB).
  static const int addOnMaxBytes = 500 * 1024;

  /// Thumbnail max dimension (fit inside N×N). Used only for optional grid
  /// previews; Product Cards display full-size [imageUrls], not thumbnails.
  static const int thumbnailSize = 600;

  /// Compresses image bytes to WebP: max 1080px, min 800px on shorter side,
  /// [quality] 85%. Use for product detail and card display.
  ///
  /// [bytes] can be JPG, PNG, or HEIC (HEIC on iOS/Android when decoded by
  /// native compressor). On WebP unsupported platforms falls back to JPEG.
  static Future<Uint8List> compressToWebP(
    Uint8List bytes, {
    int maxWidth = fullSizeMaxWidth,
    int compressQuality = quality,
  }) async {
    final dimensions = _decodeDimensions(bytes);
    int targetWidth = maxWidth;
    int targetHeight = 1;
    if (dimensions != null) {
      final w = dimensions.$1;
      final h = dimensions.$2;
      if (w > 0 && h > 0) {
        final maxSide = w > h ? w : h;
        final minSide = w > h ? h : w;
        double scale = maxSide > maxWidth ? maxWidth / maxSide : 1.0;
        int tw = (w * scale).round().clamp(1, 0x7fffffff);
        int th = (h * scale).round().clamp(1, 0x7fffffff);
        // Ensure shorter side is at least fullSizeMinDimension when source allows
        if (minSide >= fullSizeMinDimension && (tw < fullSizeMinDimension || th < fullSizeMinDimension)) {
          final scaleMin = fullSizeMinDimension / minSide;
          final tw2 = (w * scaleMin).round().clamp(1, 0x7fffffff);
          final th2 = (h * scaleMin).round().clamp(1, 0x7fffffff);
          if (tw2 <= maxWidth && th2 <= maxWidth) {
            tw = tw2;
            th = th2;
          }
        }
        targetWidth = tw;
        targetHeight = th;
      }
    }
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: targetWidth,
        minHeight: targetHeight,
        quality: compressQuality,
        format: CompressFormat.webp,
        keepExif: false,
      );
      if (result.isEmpty) {
        return _compressJpegFallback(bytes, targetWidth, targetHeight, compressQuality);
      }
      return result;
    } on UnsupportedError {
      return _compressJpegFallback(bytes, targetWidth, targetHeight, compressQuality);
    }
  }

  /// Generates an optional thumbnail (fit inside [size]×[size]). Aspect ratio
  /// preserved. Product Cards use full-size [imageUrls]; this is for grids only.
  static Future<Uint8List> compressThumbnail(
    Uint8List bytes, {
    int size = thumbnailSize,
    int compressQuality = quality,
  }) async {
    final dimensions = _decodeDimensions(bytes);
    int targetWidth = size;
    int targetHeight = size;
    if (dimensions != null) {
      final w = dimensions.$1;
      final h = dimensions.$2;
      if (w > 0 && h > 0) {
        if (w >= h) {
          targetWidth = size;
          targetHeight = (h * size / w).round().clamp(1, 0x7fffffff);
        } else {
          targetHeight = size;
          targetWidth = (w * size / h).round().clamp(1, 0x7fffffff);
        }
      }
    }
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: targetWidth,
        minHeight: targetHeight,
        quality: compressQuality,
        format: CompressFormat.webp,
        keepExif: false,
      );
      if (result.isEmpty) {
        return _compressJpegFallback(bytes, targetWidth, targetHeight, compressQuality);
      }
      return result;
    } on UnsupportedError {
      return _compressJpegFallback(bytes, targetWidth, targetHeight, compressQuality);
    }
  }

  /// Decode image to read dimensions only (JPG/PNG/WebP/BMP/GIF).
  /// Returns null for HEIC or unsupported formats (caller uses default dimensions).
  static (int, int)? _decodeDimensions(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);
      if (image != null) return (image.width, image.height);
    } catch (_) {}
    return null;
  }

  static Future<Uint8List> _compressJpegFallback(
    Uint8List bytes,
    int minWidth,
    int minHeight,
    int compressQuality,
  ) async {
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: minWidth,
      minHeight: minHeight == 1 ? 1 : minHeight,
      quality: compressQuality,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    return result.isEmpty ? bytes : result;
  }

  /// Compresses image to WebP for add-on uploads: quality 85%, max [addOnMaxBytes] (500 KB).
  /// Reduces dimensions or quality iteratively until under the size limit.
  static Future<Uint8List> compressToWebPForAddOn(Uint8List bytes) async {
    const maxBytes = addOnMaxBytes;
    const targetQuality = 85;
    int maxWidth = 800;
    int quality = targetQuality;
    Uint8List result = await compressToWebP(
      bytes,
      maxWidth: maxWidth,
      compressQuality: quality,
    );
    while (result.length > maxBytes && (maxWidth > 320 || quality > 50)) {
      if (maxWidth > 320) {
        maxWidth = (maxWidth * 0.8).round().clamp(320, 2000);
      } else {
        quality = (quality - 10).clamp(50, 100);
      }
      result = await compressToWebP(
        bytes,
        maxWidth: maxWidth,
        compressQuality: quality,
      );
    }
    return result;
  }
}
