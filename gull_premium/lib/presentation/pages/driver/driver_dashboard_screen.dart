import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../widgets/layout/app_scaffold.dart';

/// Live driver dashboard: map + online toggle (only for approved drivers).
class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  static const LatLng _defaultCenter = LatLng(33.3152, 44.3661);
  GoogleMapController? _mapController;
  bool _toggling = false;

  Future<void> _setOnline(bool online) async {
    final user = fa.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _toggling = true);
    try {
      final ref =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      if (!online) {
        await ref.set({'isOnline': false}, SetOptions(merge: true));
        if (mounted) setState(() => _toggling = false);
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final updates = <String, dynamic>{'isOnline': true};
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 15),
            ),
          );
          updates['location'] = GeoPoint(pos.latitude, pos.longitude);
          updates['latitude'] = pos.latitude;
          updates['longitude'] = pos.longitude;
          await _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(pos.latitude, pos.longitude),
              14,
            ),
          );
        } catch (_) {
          /* location optional */
        }
      }
      await ref.set(updates, SetOptions(merge: true));
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
      if (mounted) setState(() => _toggling = false);
    }
  }

  Set<Marker> _markersFromData(Map<String, dynamic>? data) {
    if (data == null) return {};
    final loc = data['location'];
    if (loc is GeoPoint) {
      return {
        Marker(
          markerId: const MarkerId('me'),
          position: LatLng(loc.latitude, loc.longitude),
          infoWindow: const InfoWindow(title: 'Your position'),
        ),
      };
    }
    final lat = data['latitude'];
    final lng = data['longitude'];
    if (lat is num && lng is num) {
      return {
        Marker(
          markerId: const MarkerId('me'),
          position: LatLng(lat.toDouble(), lng.toDouble()),
        ),
      };
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    final user = fa.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return AppScaffold(
        child: Center(child: Text('Sign in required', style: GoogleFonts.montserrat())),
      );
    }

    return AppScaffold(
      title: 'Driver',
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data();
          final online = data?['isOnline'] == true;
          final markers = _markersFromData(data);
          LatLng center = _defaultCenter;
          for (final m in markers) {
            center = m.position;
            break;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Live fleet',
                        style: GoogleFonts.montserrat(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.inkCharcoal,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: online
                            ? AppColors.sage.withValues(alpha: 0.35)
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        online ? 'Online' : 'Offline',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: online
                              ? AppColors.forestGreen
                              : AppColors.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: center,
                        zoom: markers.isEmpty ? 11 : 14,
                      ),
                      markers: markers,
                      myLocationButtonEnabled: true,
                      myLocationEnabled: true,
                      onMapCreated: (c) => _mapController = c,
                      mapToolbarEnabled: false,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Availability',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: AppColors.rosePrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Go online only when you are ready to accept deliveries. '
                        'Your approximate location may be shared with dispatch while online.',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          height: 1.45,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: online,
                        onChanged: _toggling ? null : _setOnline,
                        activeThumbColor: AppColors.forestGreen,
                        title: Text(
                          'I am online for deliveries',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.ink,
                          ),
                        ),
                        subtitle: Text(
                          _toggling ? 'Updating…' : 'Toggle to appear on the live fleet map',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                    ],
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
