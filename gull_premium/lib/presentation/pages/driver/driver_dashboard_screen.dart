import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_format_utils.dart';
import '../../../data/repositories/order_repository.dart';

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
  Timer? _deliveryLocationTimer;
  String? _activeTrackingOrderId;

  final OmsOrderRepository _omsOrderRepository = OmsOrderRepository();

  static const _omsOutForDelivery = 'out_for_delivery';
  static const _omsDelivered = 'delivered';

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
        _stopDeliveryLocationBroadcast();

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

  num _numFromDynamic(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString().trim().replaceAll(',', '')) ?? 0;
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

  void _stopDeliveryLocationBroadcast() {
    _deliveryLocationTimer?.cancel();
    _deliveryLocationTimer = null;
    _activeTrackingOrderId = null;
  }

  Future<void> _startDeliveryLocationBroadcast(String orderId) async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location permission is required to share live tracking.',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: AppColors.rosePrimary,
          ),
        );
      }
      return;
    }

    _stopDeliveryLocationBroadcast();
    _activeTrackingOrderId = orderId;

    Future<void> pushOnce() async {
      if (_activeTrackingOrderId != orderId) return;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        await _omsOrderRepository.updateOmsDriverLiveLocation(
          orderId: orderId,
          location: GeoPoint(pos.latitude, pos.longitude),
        );
      } catch (_) {
        // Ignore intermittent GPS / network failures.
      }
    }

    await pushOnce();
    _deliveryLocationTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => pushOnce(),
    );
    if (mounted) setState(() {});
  }

  Future<void> _markOmsOrderDelivered(String orderId) async {
    _stopDeliveryLocationBroadcast();
    await _omsOrderRepository.markOmsOrderDeliveredByDriver(
      orderId: orderId,
    );
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
              .collection('oms_orders')
              .where('driverId', isEqualTo: user.uid)
              .where('status', isEqualTo: _omsDelivered)
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
                    .collection('oms_orders')
                    .where('driverId', isEqualTo: user.uid)
                    .where('status', isEqualTo: _omsOutForDelivery)
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
                            'No active OMS deliveries.\nWhen an admin assigns you a ready order, it appears here.',
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
                      final orderId = doc.id;
                      final bouquetName =
                          data['bouquetName']?.toString().trim().isNotEmpty == true
                              ? data['bouquetName'].toString().trim()
                              : 'Order';
                      final vendorName =
                          data['vendorName']?.toString().trim().isNotEmpty == true
                              ? data['vendorName'].toString().trim()
                              : 'Vendor';
                      final customerPhone =
                          data['customerPhone']?.toString().trim() ?? '';
                      final deliveryLink =
                          data['deliveryLocationLink']?.toString().trim() ?? '';
                      final isUpdatingThisCard = _updatingOrderId == orderId;
                      final isLive = _activeTrackingOrderId == orderId;

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
                                  color: AppColors.rosePrimary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    bouquetName,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.inkCharcoal,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: isLive
                                        ? AppColors.forestGreen
                                            .withValues(alpha: 0.12)
                                        : AppColors.accentGold
                                            .withValues(alpha: 0.12),
                                    border: Border.all(
                                      color: AppColors.border.withValues(alpha: 0.9),
                                    ),
                                  ),
                                  child: Text(
                                    isLive ? 'Live tracking on' : 'Out for delivery',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isLive
                                          ? AppColors.forestGreen
                                          : AppColors.accentGold,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Order $orderId · $vendorName',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: AppColors.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SectionRow(
                              titleIcon: Icons.phone_outlined,
                              titleColor: AppColors.rosePrimary,
                              titleText: 'Customer',
                              subtitleText: customerPhone.isEmpty
                                  ? 'Phone not on order'
                                  : customerPhone,
                              trailing: IconButton(
                                tooltip: 'Call customer',
                                onPressed: customerPhone.isEmpty
                                    ? null
                                    : () => _callPhone(context, customerPhone),
                                icon: const Icon(Icons.call_rounded, size: 18),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.rosePrimary
                                      .withValues(alpha: 0.12),
                                  foregroundColor: AppColors.rosePrimary,
                                  shape: const CircleBorder(),
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                            ),
                            if (deliveryLink.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final uri = Uri.tryParse(deliveryLink);
                                    if (uri == null || !await canLaunchUrl(uri)) {
                                      return;
                                    }
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  },
                                  icon: const Icon(Icons.map_outlined, size: 18),
                                  label: const Text('Open delivery location link'),
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: isUpdatingThisCard
                                        ? null
                                        : () async {
                                            if (isLive) {
                                              _stopDeliveryLocationBroadcast();
                                              setState(() {});
                                              return;
                                            }
                                            setState(
                                              () => _updatingOrderId = orderId,
                                            );
                                            try {
                                              await _startDeliveryLocationBroadcast(
                                                orderId,
                                              );
                                            } finally {
                                              if (mounted) {
                                                setState(
                                                  () => _updatingOrderId = null,
                                                );
                                              }
                                            }
                                          },
                                    child: Text(
                                      isLive ? 'Pause live tracking' : 'Start live tracking',
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.accentGold,
                                          AppColors.forestGreen,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ElevatedButton(
                                      onPressed: isUpdatingThisCard
                                          ? null
                                          : () async {
                                              setState(
                                                () => _updatingOrderId = orderId,
                                              );
                                              try {
                                                await _markOmsOrderDelivered(
                                                  orderId,
                                                );
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Marked as delivered.',
                                                      style: GoogleFonts.montserrat(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                    backgroundColor:
                                                        AppColors.forestGreen,
                                                  ),
                                                );
                                              } on FirebaseException catch (e) {
                                                debugPrint(
                                                  'Mark delivered failed: code=${e.code}, message=${e.message}',
                                                );
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      e.message?.isNotEmpty == true
                                                          ? 'Could not complete delivery (${e.code}): ${e.message}'
                                                          : 'Could not complete delivery (${e.code}).',
                                                    ),
                                                    backgroundColor:
                                                        AppColors.rosePrimary,
                                                  ),
                                                );
                                              } catch (e) {
                                                debugPrint(
                                                  'Mark delivered failed: $e',
                                                );
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Could not complete delivery. Try again.',
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
                                        shadowColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
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
                                              'Mark as delivered',
                                              style: GoogleFonts.montserrat(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
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
    _stopDeliveryLocationBroadcast();
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
