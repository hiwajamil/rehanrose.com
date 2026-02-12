import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

/// Image compression and optimization for vendor uploads.
///
/// Converts JPG/PNG/HEIC to WebP, resizes to max width (1080px), 80% quality,
/// and optionally generates thumbnails (300x300) for listing grids.
class ImageCompressionService {
  ImageCompressionService._();

  /// Max width for full-size images (product detail). 1080px is enough for
  /// most displays; use [fullSizeMaxWidthZoom] only if you need higher zoom.
  static const int fullSizeMaxWidth = 1080;

  /// Optional higher-res max width for zoom (e.g. product detail zoom view).
  static const int fullSizeMaxWidthZoom = 1920;

  /// Compression quality (0-100). 80% reduces size with minimal visible loss.
  static const int quality = 80;

  /// Thumbnail max dimension for listing grid (fit inside 300x300).
  static const int thumbnailSize = 300;

  /// Compresses image bytes to WebP: max width [fullSizeMaxWidth], [quality] 80%.
  /// Use for product detail / full-size display.
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
      if (w > 0) {
        targetWidth = w > maxWidth ? maxWidth : w;
        targetHeight = (h * targetWidth / w).round().clamp(1, 0x7fffffff);
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

  /// Generates a thumbnail for the listing grid (fit inside [size]x[size]).
  /// Aspect ratio preserved; smaller dimension at least 1 so the compressor
  /// produces a small image.
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
}
