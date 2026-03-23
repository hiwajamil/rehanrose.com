import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';

/// Live Google Map for all active drivers.
///
/// Markers use [MarkerId] = Firestore document id (driver `uid`) so updates replace
/// the same marker and the map can move pins instead of duplicating them.
///
/// NOTE: Add the Google Maps API key later for map tiles to render correctly:
/// - AndroidManifest.xml
/// - AppDelegate.swift (iOS)
/// - index.html (Web)
class LiveFleetMapScreen extends StatelessWidget {
  const LiveFleetMapScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _driversStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .where('isOnline', isEqualTo: true)
        .snapshots();
  }

  LatLng? _extractLatLng(Map<String, dynamic> data) {
    final dynamic loc = data['location'];

    if (loc is GeoPoint) {
      return LatLng(loc.latitude, loc.longitude);
    }

    // Sometimes location might be stored as a map payload.
    if (loc is Map) {
      final latRaw = loc['latitude'] ?? loc['lat'];
      final lngRaw = loc['longitude'] ?? loc['lng'] ?? loc['lon'];
      final lat = _toDouble(latRaw);
      final lng = _toDouble(lngRaw);
      if (lat != null && lng != null) return LatLng(lat, lng);
    }

    // Or latitude/longitude might be stored at the root.
    final lat = _toDouble(data['latitude'] ?? data['lat']);
    final lng = _toDouble(
      data['longitude'] ?? data['lng'] ?? data['lon'],
    );
    if (lat != null && lng != null) return LatLng(lat, lng);

    return null;
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _readDriverName(Map<String, dynamic> data, {required String fallback}) {
    final raw = data['fullName'] ??
        data['name'] ??
        data['displayName'] ??
        data['userName'] ??
        data['username'];
    final s = raw?.toString().trim() ?? '';
    return s.isNotEmpty ? s : fallback;
  }

  String _readActiveOrder(Map<String, dynamic> data) {
    final raw = data['activeOrder'] ??
        data['currentActiveOrder'] ??
        data['activeOrderId'] ??
        data['currentActiveOrderId'] ??
        data['activeOrderCode'] ??
        data['currentActiveOrderCode'];
    return raw?.toString().trim() ?? '';
  }

  bool _statusIndicatesDelivery(Map<String, dynamic> data) {
    final statusRaw = data['availabilityStatus'] ??
        data['driverStatus'] ??
        data['status'] ??
        data['deliveryStatus'];
    final s = statusRaw?.toString().toLowerCase().trim() ?? '';
    return s.contains('delivery') ||
        s.contains('on_delivery') ||
        s.contains('on delivery') ||
        s.contains('on-delivery') ||
        s.contains('running');
  }

  bool _statusIndicatesOffline(Map<String, dynamic> data) {
    final statusRaw = data['availabilityStatus'] ??
        data['driverStatus'] ??
        data['status'] ??
        data['deliveryStatus'];
    final s = statusRaw?.toString().toLowerCase().trim() ?? '';
    return s.contains('offline') || s.contains('unavailable');
  }

  String _availabilityLabel(Map<String, dynamic> data) {
    // The query already filters for `isOnline == true`, but keep logic robust.
    if (_statusIndicatesOffline(data) || data['isOnline'] == false) {
      return 'Available';
    }

    final hasActiveOrder = _readActiveOrder(data).isNotEmpty;
    final onDelivery = _statusIndicatesDelivery(data) ||
        hasActiveOrder ||
        (data['onDelivery'] == true);
    return onDelivery ? 'On Delivery' : 'Available';
  }

  Set<Marker> _buildMarkers(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final markers = <Marker>{};

    for (final doc in docs) {
      final data = doc.data();
      final pos = _extractLatLng(data);
      if (pos == null) continue;

      final name = _readDriverName(data, fallback: 'Driver');
      final label = _availabilityLabel(data);

      // Marker styling: distinct colored pins (green for available, orange for on delivery).
      final hue = label == 'On Delivery' ? 30.0 : 120.0;

      // Stable MarkerId (driver uid) is required so position updates animate/move
      // the existing pin instead of stacking duplicates.
      markers.add(
        Marker(
          markerId: MarkerId(doc.id),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: name,
            snippet: label,
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    const initialTarget = LatLng(35.5558, 45.4351);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Live Fleet Tracking',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _driversStream(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? const [];
          final markers = _buildMarkers(docs);

          final isLoading = snap.connectionState == ConnectionState.waiting;
          final hasDrivers = docs.isNotEmpty && markers.isNotEmpty;

          return Stack(
            children: [
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: initialTarget,
                    zoom: 13.0,
                  ),
                  markers: markers,
                  mapType: MapType.normal,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                ),
              ),

              Positioned(
                left: 16,
                top: 16,
                child: _LegendPanel(isLoading: isLoading),
              ),

              if (isLoading)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x66000000),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),

              if (!isLoading && !hasDrivers)
                Positioned.fill(
                  child: Center(
                    child: Text(
                      'No active drivers right now.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.inkMuted,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LegendPanel extends StatelessWidget {
  const _LegendPanel({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isLoading ? 0.5 : 1,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.9),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LegendDot(
              label: 'Available',
            ),
            const SizedBox(width: 10),
            _LegendDot(
              label: 'On Delivery',
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label});

  final String label;

  Color _dotColor() {
    if (label == 'On Delivery') return const Color(0xFFFFA000);
    return const Color(0xFF2DBA4E);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _dotColor(),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

