import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_format_utils.dart';
import '../../../data/models/order_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/oms/oms_order_card.dart';

/// Customer-facing OMS order detail with live map when [status] is out for delivery.
class CustomerOmsOrderDetailScreen extends StatefulWidget {
  const CustomerOmsOrderDetailScreen({
    super.key,
    required this.orderDocId,
  });

  /// Firestore document id (same as [OmsOrderModel.orderId]).
  final String orderDocId;

  @override
  State<CustomerOmsOrderDetailScreen> createState() =>
      _CustomerOmsOrderDetailScreenState();
}

class _CustomerOmsOrderDetailScreenState
    extends State<CustomerOmsOrderDetailScreen> {
  GoogleMapController? _mapController;
  String? _lastAnimatedDriverLocationKey;

  /// Custom delivery marker; null after load if asset failed.
  BitmapDescriptor? _driverMarkerIcon;
  bool _driverMarkerIconReady = false;

  static const LatLng _fallbackCenter = LatLng(33.3152, 44.3661);
  static const String _driverMarkerAsset = 'assets/images/delivery_car.png';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadDriverMarkerIcon();
    });
  }

  Future<void> _loadDriverMarkerIcon() async {
    if (!mounted) return;
    final configuration = createLocalImageConfiguration(context);
    try {
      final icon = await BitmapDescriptor.asset(
        configuration,
        _driverMarkerAsset,
        width: 56,
        height: 56,
      );
      if (!mounted) return;
      setState(() {
        _driverMarkerIcon = icon;
        _driverMarkerIconReady = true;
      });
    } catch (e) {
      debugPrint('Driver marker icon load failed: $e');
      if (!mounted) return;
      setState(() {
        _driverMarkerIcon = null;
        _driverMarkerIconReady = true;
      });
    }
  }

  Future<void> _callDriver(String phone) async {
    final sanitized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (sanitized.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver phone not available.')),
        );
      }
      return;
    }
    final uri = Uri.parse('tel:$sanitized');
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('oms_orders')
        .doc(widget.orderDocId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Order details',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: AppColors.inkCharcoal,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData || !snap.data!.exists) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load this order.',
                  style: GoogleFonts.montserrat(color: AppColors.inkMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = snap.data!.data()!;
          final model = OmsOrderModel.fromFirestore(snap.data!.id, data);
          if (model == null) {
            return const Center(child: Text('Invalid order data.'));
          }

          final isLive = model.status == OmsOrderStatus.outForDelivery;
          final driverPhone = model.driverPhone?.trim() ?? '';
          final driverLoc = model.driverLocation;

          final locKey = driverLoc == null
              ? null
              : '${driverLoc.latitude.toStringAsFixed(5)}_${driverLoc.longitude.toStringAsFixed(5)}';
          if (locKey != null && locKey != _lastAnimatedDriverLocationKey) {
            final loc = driverLoc!;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _lastAnimatedDriverLocationKey = locKey;
              _mapController?.animateCamera(
                CameraUpdate.newLatLng(
                  LatLng(loc.latitude, loc.longitude),
                ),
              );
            });
          }

          final initial = driverLoc != null
              ? LatLng(driverLoc.latitude, driverLoc.longitude)
              : _fallbackCenter;

          final driverMarkerDescriptor = _driverMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              );

          final markers = <Marker>{
            if (driverLoc != null)
              Marker(
                markerId: const MarkerId('driver'),
                position: LatLng(driverLoc.latitude, driverLoc.longitude),
                icon: driverMarkerDescriptor,
                infoWindow: InfoWindow(
                  title: 'Your delivery',
                  snippet: model.bouquetName ?? 'On the way',
                ),
              ),
          };

          final l10n = AppLocalizations.of(context);

          final orderDetails = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isLive)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Live map appears when your order is out for delivery.',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: AppColors.inkMuted,
                      height: 1.4,
                    ),
                  ),
                ),
              Text(
                model.bouquetName ?? 'Order',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkCharcoal,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '#${model.orderId}',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 12),
              OmsDetailRow(
                label: 'Status',
                value: model.status.value.replaceAll('_', ' '),
              ),
              OmsDetailRow(
                label: 'Total',
                value: l10n != null
                    ? '${l10n.currencyIqd} ${formatPriceIqd(model.totalPrice.toInt())}'
                    : 'IQD ${formatPriceIqd(model.totalPrice.toInt())}',
              ),
              if (model.vendorName != null && model.vendorName!.isNotEmpty)
                OmsDetailRow(
                  label: 'Vendor',
                  value: model.vendorName!,
                ),
              if (model.customerPhone.isNotEmpty)
                OmsDetailRow(
                  label: 'Phone',
                  value: model.customerPhone,
                ),
            ],
          );

          final driverCard = Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Material(
              color: AppColors.surface,
              elevation: 0,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.phone_in_talk_rounded,
                          color: AppColors.rosePrimary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Driver',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                driverPhone.isEmpty
                                    ? 'Phone not available yet'
                                    : driverPhone,
                                style: GoogleFonts.montserrat(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.inkCharcoal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed:
                          driverPhone.isEmpty ? null : () => _callDriver(driverPhone),
                      icon: const Icon(Icons.call_rounded),
                      label: const Text('Call driver'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forestGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          if (!isLive) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: orderDetails,
            );
          }

          return Column(
            children: [
              Expanded(
                child: !_driverMarkerIconReady
                    ? ColoredBox(
                        color: AppColors.background,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: initial,
                          zoom: 14,
                        ),
                        markers: markers,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: true,
                        onMapCreated: (c) => _mapController = c,
                      ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 12, bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      driverCard,
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: orderDetails,
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
