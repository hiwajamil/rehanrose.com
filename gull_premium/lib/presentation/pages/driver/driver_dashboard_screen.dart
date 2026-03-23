import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_format_utils.dart';

/// Driver dashboard with live location updates while online.
///
/// **Location permissions (configure for continuous tracking):**
/// - **Android:** `android/app/src/main/AndroidManifest.xml` — `ACCESS_FINE_LOCATION` /
///   `ACCESS_COARSE_LOCATION` for in-app / foreground updates; for **Always** /
///   background tracking (Android 10+), also declare `ACCESS_BACKGROUND_LOCATION`
///   and follow Play policy (often a foreground service). See Geolocator docs.
/// - **iOS:** `ios/Runner/Info.plist` — `NSLocationWhenInUseUsageDescription` for
///   **Allow While Using**; for **Always Allow** / background, add
///   `NSLocationAlwaysAndWhenInUseUsageDescription` and `UIBackgroundModes` → `location`.
class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  bool _updatingStatus = false;
  String? _updatingOrderId;
  StreamSubscription<Position>? _positionStream;

  static const _activeStatuses = [
    'ready_for_pickup',
    'picked_up',
    'on_the_way',
  ];

  static const _deliveredStatus = 'delivered';

  static const _mainAction = {
    'ready_for_pickup': 'Confirm Pickup',
    'picked_up': 'Start Delivery / On The Way',
    'on_the_way': 'Complete Delivery',
  };

  Future<void> _setOnline(bool online) async {
    final user = fa.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _updatingStatus = true);
    try {
      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      if (!online) {
        _positionStream?.cancel();
        _positionStream = null;

        await userDoc.set(
          {'isOnline': false},
          SetOptions(merge: true),
        );
        return;
      }

      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Location permission denied. Go online aborted.',
                style: GoogleFonts.montserrat(),
              ),
              backgroundColor: AppColors.rosePrimary,
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await userDoc.set(
        {
          'isOnline': true,
          'location': GeoPoint(position.latitude, position.longitude),
        },
        SetOptions(merge: true),
      );

      // Start live location updates: 100 m distance filter limits Firestore writes
      // and device wakeups (battery + cost).
      await _positionStream?.cancel();
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100,
        ),
      ).listen(
        (Position position) {
          userDoc
              .set(
                {
                  'location': GeoPoint(
                    position.latitude,
                    position.longitude,
                  ),
                },
                SetOptions(merge: true),
              )
              .catchError((_) {
            // Ignore individual update failures.
          });
        },
        onError: (Object _) {
          // Ignore stream errors for now; the user can toggle offline/online again.
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not update status. Try again.',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: AppColors.rosePrimary,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _signOut() async {
    await fa.FirebaseAuth.instance.signOut();
  }

  String _resolveVendorName(Map<String, dynamic> data) {
    final candidates = <dynamic>[
      data['vendorName'],
      data['pickupVendorName'],
      data['restaurantName'],
      data['storeName'],
      data['vendor'] is Map<String, dynamic>
          ? (data['vendor'] as Map<String, dynamic>)['name']
          : null,
      data['pickup'] is Map<String, dynamic>
          ? (data['pickup'] as Map<String, dynamic>)['name']
          : null,
    ];
    for (final c in candidates) {
      if (c is String && c.trim().isNotEmpty) return c.trim();
    }
    return 'Vendor';
  }

  String _resolveCustomerAddress(Map<String, dynamic> data) {
    final candidates = <dynamic>[
      data['customerAddress'],
      data['deliveryAddress'],
      data['dropOffAddress'],
      data['address'],
      data['customer'] is Map<String, dynamic>
          ? (data['customer'] as Map<String, dynamic>)['address']
          : null,
      data['dropOff'] is Map<String, dynamic>
          ? (data['dropOff'] as Map<String, dynamic>)['address']
          : null,
    ];
    for (final c in candidates) {
      if (c is String && c.trim().isNotEmpty) return c.trim();
    }
    return 'Customer address not available';
  }

  String _normalizeStatus(String? status) {
    return (status ?? '').trim().toLowerCase().replaceAll(' ', '_');
  }

  bool _isActiveStatus(String status) => _activeStatuses.contains(status);

  num _numFromDynamic(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString().trim().replaceAll(',', '')) ?? 0;
  }

  String _resolveVendorAddress(Map<String, dynamic> data) {
    final candidates = <dynamic>[
      data['pickupAddress'],
      data['vendorAddress'],
      data['pickupVendorAddress'],
      data['restaurantAddress'],
      data['storeAddress'],
      data['vendorAddressLine'],
      data['pickupAddressLine'],
      data['vendor'] is Map<String, dynamic>
          ? (data['vendor'] as Map<String, dynamic>)['address']
          : null,
      data['pickup'] is Map<String, dynamic>
          ? (data['pickup'] as Map<String, dynamic>)['address']
          : null,
      data['pickupVendor'] is Map<String, dynamic>
          ? (data['pickupVendor'] as Map<String, dynamic>)['address']
          : null,
    ];
    for (final c in candidates) {
      if (c is String && c.trim().isNotEmpty) return c.trim();
    }
    return 'Vendor address not available';
  }

  String _resolveVendorPhone(Map<String, dynamic> data) {
    final candidates = <dynamic>[
      data['vendorPhone'],
      data['pickupVendorPhone'],
      data['restaurantPhone'],
      data['storePhone'],
      data['phoneNumber'],
      data['pickupPhone'],
      data['vendorPhoneNumber'],
      data['pickupVendorPhoneNumber'],
      data['vendor'] is Map<String, dynamic>
          ? (data['vendor'] as Map<String, dynamic>)['phoneNumber'] ??
              (data['vendor'] as Map<String, dynamic>)['phone']
          : null,
      data['pickup'] is Map<String, dynamic>
          ? (data['pickup'] as Map<String, dynamic>)['phoneNumber'] ??
              (data['pickup'] as Map<String, dynamic>)['phone']
          : null,
      data['pickupVendor'] is Map<String, dynamic>
          ? (data['pickupVendor'] as Map<String, dynamic>)['phoneNumber'] ??
              (data['pickupVendor'] as Map<String, dynamic>)['phone']
          : null,
    ];
    for (final c in candidates) {
      final s = c?.toString().trim() ?? '';
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  String _resolveCustomerPhone(Map<String, dynamic> data) {
    final candidates = <dynamic>[
      data['userPhone'],
      data['customerPhone'],
      data['phoneNumber'],
      data['deliveryPhone'],
      data['dropOffPhone'],
      data['user'] is Map<String, dynamic>
          ? (data['user'] as Map<String, dynamic>)['phoneNumber'] ??
              (data['user'] as Map<String, dynamic>)['phone']
          : null,
      data['customer'] is Map<String, dynamic>
          ? (data['customer'] as Map<String, dynamic>)['phoneNumber'] ??
              (data['customer'] as Map<String, dynamic>)['phone']
          : null,
      data['dropOff'] is Map<String, dynamic>
          ? (data['dropOff'] as Map<String, dynamic>)['phoneNumber'] ??
              (data['dropOff'] as Map<String, dynamic>)['phone']
          : null,
    ];
    for (final c in candidates) {
      final s = c?.toString().trim() ?? '';
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  (double lat, double lng)? _parseLatLng(dynamic v) {
    if (v is Map) {
      final latRaw = v['latitude'] ?? v['lat'];
      final lngRaw = v['longitude'] ?? v['lng'] ?? v['lon'];
      final lat = _numFromDynamic(latRaw).toDouble();
      final lng = _numFromDynamic(lngRaw).toDouble();
      if (lat != 0 && lng != 0) return (lat, lng);
    }
    return null;
  }

  (double lat, double lng)? _extractVendorLatLng(Map<String, dynamic> data) {
    final candidates = <dynamic>[
      data['pickupLatLng'],
      data['pickupLocation'],
      data['vendorLatLng'],
      data['vendorLocation'],
      data['vendor'] is Map<String, dynamic> ? data['vendor'] : null,
      data['pickup'] is Map<String, dynamic> ? data['pickup'] : null,
      data['pickupVendor'] is Map<String, dynamic> ? data['pickupVendor'] : null,
      data['pickupLocationLink'],
      data['latitude'],
      data['longitude'],
    ];
    for (final c in candidates) {
      final res = _parseLatLng(c);
      if (res != null) return res;
    }
    // Some payloads store lat/lng directly at root.
    final lat = _numFromDynamic(data['pickupLatitude']).toDouble();
    final lng = _numFromDynamic(data['pickupLongitude']).toDouble();
    if (lat != 0 && lng != 0) return (lat, lng);
    return null;
  }

  (double lat, double lng)? _extractCustomerLatLng(Map<String, dynamic> data) {
    final candidates = <dynamic>[
      data['dropOffLatLng'],
      data['dropOffLocation'],
      data['deliveryLatLng'],
      data['deliveryLocation'],
      data['dropOff'] is Map<String, dynamic> ? data['dropOff'] : null,
      data['delivery'] is Map<String, dynamic> ? data['delivery'] : null,
      data['customer'] is Map<String, dynamic> ? data['customer'] : null,
      data['latitude'],
      data['longitude'],
    ];
    for (final c in candidates) {
      final res = _parseLatLng(c);
      if (res != null) return res;
    }
    // Some payloads store lat/lng directly at root.
    final lat = _numFromDynamic(data['deliveryLatitude']).toDouble();
    final lng = _numFromDynamic(data['deliveryLongitude']).toDouble();
    if (lat != 0 && lng != 0) return (lat, lng);
    return null;
  }

  Future<void> _callPhone(BuildContext context, String phone) async {
    final sanitized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (sanitized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Phone number not available.'),
          backgroundColor: AppColors.rosePrimary,
        ),
      );
      return;
    }

    final uri = Uri.parse('tel:$sanitized');
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _googleMapsSearchUrl({double? lat, double? lng, String? address}) {
    if (lat != null && lng != null) {
      return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    }
    final a = (address ?? '').trim();
    if (a.isEmpty) return '';
    return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(a)}';
  }

  Future<void> _navigateTo(
    BuildContext context, {
    double? lat,
    double? lng,
    required String addressFallback,
  }) async {
    final url = _googleMapsSearchUrl(lat: lat, lng: lng, address: addressFallback);
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Destination not available.'),
          backgroundColor: AppColors.rosePrimary,
        ),
      );
      return;
    }

    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _updateOrderStatus({
    required String orderId,
    required String newStatus,
    bool includeDeliveryDate = false,
  }) async {
    final update = <String, dynamic>{'status': newStatus};
    if (includeDeliveryDate) {
      // Used by the "Today's Stats" card for delivery completion attribution.
      update['deliveryDate'] = FieldValue.serverTimestamp();
    }

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update(update);
  }

  @override
  Widget build(BuildContext context) {
    final user = fa.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text('Sign in required', style: GoogleFonts.montserrat()),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Driver Dashboard',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(
              'Sign out',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(foregroundColor: AppColors.inkCharcoal),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          final isOnline = userSnapshot.data?.data()?['isOnline'] == true;
          final now = DateTime.now();
          final startOfToday = DateTime(now.year, now.month, now.day);
          final endOfTomorrow = startOfToday.add(const Duration(days: 1));

          final deliveredTodayStream = FirebaseFirestore.instance
              .collection('orders')
              .where('driverId', isEqualTo: user.uid)
              .where('status', isEqualTo: _deliveredStatus)
              .where('deliveryDate',
                  isGreaterThanOrEqualTo:
                      Timestamp.fromDate(startOfToday))
              .where('deliveryDate',
                  isLessThan: Timestamp.fromDate(endOfTomorrow))
              .snapshots();

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Availability',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w700,
                        color: AppColors.rosePrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isOnline
                          ? 'You are currently visible for assignment.'
                          : 'Go online to start receiving deliveries.',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: AppColors.inkMuted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isOnline
                              ? [
                                  AppColors.forestGreen,
                                  AppColors.sage.withValues(alpha: 0.95),
                                ]
                              : [AppColors.inkMuted, const Color(0xFF8E8E8E)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ElevatedButton(
                        onPressed: _updatingStatus
                            ? null
                            : () => _setOnline(!isOnline),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          minimumSize: const Size.fromHeight(58),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _updatingStatus
                              ? 'Updating...'
                              : (isOnline ? 'Go Offline' : 'Go Online'),
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Today's Stats (premium summary card)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: deliveredTodayStream,
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? const [];

                  final deliveriesToday = docs.length;
                  final totalPriceSum = docs.fold<num>(0, (acc, d) {
                    final data = d.data();
                    return acc + _numFromDynamic(data['totalPrice']);
                  });
                  final estimatedEarnings = totalPriceSum * 0.15;

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const SizedBox(
                        height: 76,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Today's Stats",
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 0.2,
                            color: AppColors.rosePrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _StatMetric(
                                icon: Icons.local_shipping_rounded,
                                label: 'Deliveries Today',
                                value: '$deliveriesToday',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatMetric(
                                icon: Icons.savings_outlined,
                                label: 'Estimated Earnings',
                                value: iqdPriceString(
                                  estimatedEarnings.toInt(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Estimated at 15% driver cut from delivered orders.',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: AppColors.inkMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              Text(
                'My Active Deliveries',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkCharcoal,
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('driverId', isEqualTo: user.uid)
                    .where('status', whereIn: _activeStatuses)
                    .snapshots(),
                builder: (context, ordersSnapshot) {
                  if (ordersSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (ordersSnapshot.hasError) {
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        'Could not load active deliveries right now.',
                        style: GoogleFonts.montserrat(
                          color: AppColors.inkMuted,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }

                  final docs = ordersSnapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            color: AppColors.inkMuted.withValues(alpha: 0.8),
                            size: 34,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No active deliveries.\nGo online to receive orders.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              height: 1.45,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data();
                      final status = _normalizeStatus(data['status']?.toString());
                      if (!_isActiveStatus(status)) return const SizedBox.shrink();

                      final vendorName = _resolveVendorName(data);
                      final vendorAddress = _resolveVendorAddress(data);
                      final vendorPhone = _resolveVendorPhone(data);

                      final customerAddress = _resolveCustomerAddress(data);
                      final customerPhone = _resolveCustomerPhone(data);

                      final vendorCoords = _extractVendorLatLng(data);
                      final customerCoords = _extractCustomerLatLng(data);

                      final isUpdatingThisCard = _updatingOrderId == doc.id;
                      final mainLabel = _mainAction[status] ?? 'Update Delivery';

                      final isCompletion = status == 'on_the_way';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.local_shipping_outlined,
                                  size: 18,
                                  color: isCompletion ? AppColors.forestGreen : AppColors.rosePrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Status: $status',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: isCompletion
                                        ? AppColors.forestGreen.withValues(alpha: 0.12)
                                        : AppColors.accentGold.withValues(alpha: 0.12),
                                    border: Border.all(
                                      color: AppColors.border.withValues(alpha: 0.9),
                                    ),
                                  ),
                                  child: Text(
                                    isCompletion ? 'Ready to deliver' : 'In progress',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isCompletion
                                          ? AppColors.forestGreen
                                          : AppColors.accentGold,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Pickup (Vendor)',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.rosePrimary,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _SectionRow(
                              titleIcon: Icons.storefront_outlined,
                              titleColor: AppColors.forestGreen,
                              titleText: vendorName,
                              subtitleText: vendorAddress,
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  IconButton(
                                    tooltip: 'Call vendor',
                                    onPressed: vendorPhone.isEmpty
                                        ? null
                                        : () => _callPhone(context, vendorPhone),
                                    icon: const Icon(
                                      Icons.call_rounded,
                                      size: 18,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppColors.forestGreen
                                          .withValues(alpha: 0.12),
                                      foregroundColor: AppColors.forestGreen,
                                      shape: const CircleBorder(),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Navigate to pickup',
                                    onPressed: () => _navigateTo(
                                      context,
                                      lat: vendorCoords?.$1,
                                      lng: vendorCoords?.$2,
                                      addressFallback: vendorAddress,
                                    ),
                                    icon: const Icon(
                                      Icons.navigation_rounded,
                                      size: 18,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppColors.accentGold
                                          .withValues(alpha: 0.12),
                                      foregroundColor: AppColors.accentGold,
                                      shape: const CircleBorder(),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Divider(
                              color: AppColors.border.withValues(alpha: 0.8),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Drop-off (Customer)',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.rosePrimary,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _SectionRow(
                              titleIcon: Icons.location_on_outlined,
                              titleColor: AppColors.rosePrimary,
                              titleText: 'Customer',
                              subtitleText: customerAddress,
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  IconButton(
                                    tooltip: 'Call customer',
                                    onPressed: customerPhone.isEmpty
                                        ? null
                                        : () =>
                                            _callPhone(context, customerPhone),
                                    icon: const Icon(
                                      Icons.call_rounded,
                                      size: 18,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppColors.rosePrimary
                                          .withValues(alpha: 0.12),
                                      foregroundColor: AppColors.rosePrimary,
                                      shape: const CircleBorder(),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Navigate to destination',
                                    onPressed: () => _navigateTo(
                                      context,
                                      lat: customerCoords?.$1,
                                      lng: customerCoords?.$2,
                                      addressFallback: customerAddress,
                                    ),
                                    icon: const Icon(
                                      Icons.navigation_rounded,
                                      size: 18,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppColors.forestGreen
                                          .withValues(alpha: 0.12),
                                      foregroundColor: AppColors.forestGreen,
                                      shape: const CircleBorder(),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 62,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: isCompletion
                                      ? LinearGradient(
                                          colors: [
                                            AppColors.accentGold,
                                            AppColors.forestGreen,
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        )
                                      : LinearGradient(
                                          colors: [
                                            AppColors.rosePrimary
                                                .withValues(alpha: 0.95),
                                            AppColors.accentGold
                                                .withValues(alpha: 0.85),
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 18,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: isUpdatingThisCard
                                      ? null
                                      : () async {
                                          setState(
                                            () => _updatingOrderId = doc.id,
                                          );
                                          try {
                                            if (status == 'ready_for_pickup') {
                                              await _updateOrderStatus(
                                                orderId: doc.id,
                                                newStatus: 'picked_up',
                                              );
                                            } else if (status ==
                                                'picked_up') {
                                              await _updateOrderStatus(
                                                orderId: doc.id,
                                                newStatus: 'on_the_way',
                                              );
                                            } else if (status == 'on_the_way') {
                                              final picker = ImagePicker();
                                              final xfile =
                                                  await picker.pickImage(
                                                source: ImageSource.camera,
                                              );

                                              if (xfile == null) {
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Proof of Delivery capture cancelled.',
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }

                                              // Upload PoD image (xfile) to Firebase Storage
                                              // and persist the download URL under this order.
                                              await _updateOrderStatus(
                                                orderId: doc.id,
                                                newStatus: _deliveredStatus,
                                                includeDeliveryDate: true,
                                              );

                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Delivery Completed Successfully!',
                                                    style: GoogleFonts.montserrat(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                  backgroundColor:
                                                      AppColors.forestGreen,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Could not update delivery status. Try again.',
                                                ),
                                                backgroundColor:
                                                    AppColors.rosePrimary,
                                              ),
                                            );
                                          } finally {
                                            if (mounted) {
                                              setState(
                                                () => _updatingOrderId = null,
                                              );
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: isUpdatingThisCard
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          mainLabel,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    final sub = _positionStream;
    _positionStream = null;
    if (sub != null) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }
}

class _StatMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        color: AppColors.background.withValues(alpha: 0.45),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.rosePrimary,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.inkCharcoal,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.inkMuted,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  final IconData titleIcon;
  final Color titleColor;
  final String titleText;
  final String subtitleText;
  final Widget trailing;

  const _SectionRow({
    required this.titleIcon,
    required this.titleColor,
    required this.titleText,
    required this.subtitleText,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            titleIcon,
            size: 18,
            color: titleColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titleText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitleText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: AppColors.inkMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}
