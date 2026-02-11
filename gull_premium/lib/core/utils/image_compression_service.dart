import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Image compression and optimization for vendor uploads.
///
/// Converts JPG/PNG/HEIC to WebP, resizes to max width, and optionally
/// generates thumbnails for listing grids.
class ImageCompressionService {
  ImageCompressionService._();

  /// Max width for full-size images (product detail / zoom). 1080px is enough
  /// for most displays; use 1920 only if you need higher zoom.
  static const int fullSizeMaxWidth = 1080;

  /// Compression quality (0-100). 80% reduces size with minimal visible loss.
  static const int quality = 80;

  /// Thumbnail size for listing grid (smaller dimension will be at least this).
  static const int thumbnailSize = 300;

  /// Compresses image bytes to WebP with max width [fullSizeMaxWidth] and
  /// [quality] 80%. Use for product detail / full-size display.
  ///
  /// [bytes] can be JPG, PNG, or HEIC (HEIC on iOS 11+ / Android API 28+).
  /// On WebP unsupported platforms falls back to JPEG.
  static Future<Uint8List> compressToWebP(
    Uint8List bytes, {
    int maxWidth = fullSizeMaxWidth,
    int compressQuality = quality,
  }) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxWidth,
        minHeight: 1,
        quality: compressQuality,
        format: CompressFormat.webp,
        keepExif: false,
      );
      if (result.isEmpty) return _compressJpegFallback(bytes, maxWidth, compressQuality);
      return result;
    } on UnsupportedError {
      return _compressJpegFallback(bytes, maxWidth, compressQuality);
    }
  }

  /// Generates a thumbnail suitable for listing grid (e.g. 300x300 area).
  /// Smaller dimension is at least [thumbnailSize]; aspect ratio preserved.
  static Future<Uint8List> compressThumbnail(
    Uint8List bytes, {
    int size = thumbnailSize,
    int compressQuality = quality,
  }) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: size,
        minHeight: size,
        quality: compressQuality,
        format: CompressFormat.webp,
        keepExif: false,
      );
      if (result.isEmpty) return _compressJpegFallback(bytes, size, compressQuality);
      return result;
    } on UnsupportedError {
      return _compressJpegFallback(bytes, size, compressQuality);
    }
  }

  static Future<Uint8List> _compressJpegFallback(
    Uint8List bytes,
    int minWidth,
    int compressQuality,
  ) async {
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: minWidth,
      minHeight: minWidth == fullSizeMaxWidth ? 1 : minWidth,
      quality: compressQuality,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    return result.isEmpty ? bytes : result;
  }
}
