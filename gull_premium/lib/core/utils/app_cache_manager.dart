import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// App-wide cache manager for network images.
/// Images are stored for at least 7 days to reduce bandwidth.
final appCacheManager = CacheManager(
  Config(
    'appImageCache',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 500,
  ),
);
