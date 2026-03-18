import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'live_fleet_map_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../driver/driver_application_screen.dart';

/// Super Admin: Delivery Fleet / Drivers Management.
class DriversManagementScreen extends ConsumerWidget {
  const DriversManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef _) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LiveFleetBanner(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LiveFleetMapScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
            ),
            child: TabBar(
              labelColor: AppColors.rosePrimary,
              unselectedLabelColor: AppColors.inkMuted,
              indicatorColor: AppColors.rosePrimary,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
              unselectedLabelStyle: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: 'Pending applications'),
                Tab(text: 'Registered drivers'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Expanded(
            child: TabBarView(
              children: [
                _PendingDriverApplicationsTab(),
                _RegisteredDriversTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Stream<QuerySnapshot<Map<String, dynamic>>> _driversStream() {
  return FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'driver')
      .snapshots();
}

Stream<QuerySnapshot<Map<String, dynamic>>> _pendingDriverApplicationsStream() {
  return FirebaseFirestore.instance
      .collection('users')
      .where('applicationStatus', isEqualTo: 'pending_driver')
      .snapshots();
}

int _crossAxisCountForWidth(double width) {
  if (width > 1100) return 3;
  if (width > 700) return 2;
  return 1;
}

class _PendingDriverApplicationsTab extends StatelessWidget {
  const _PendingDriverApplicationsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _pendingDriverApplicationsStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.rosePrimary,
            ),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Unable to load pending applications.',
              style: GoogleFonts.montserrat(color: AppColors.inkMuted),
            ),
          );
        }
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mark_email_unread_outlined,
                  size: 56,
                  color: AppColors.inkMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No pending driver applications',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Applicants appear here after they submit the fleet form.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 32),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, i) {
            final doc = docs[i];
            return _PendingDriverApplicationCard(
              applicantId: doc.id,
              data: doc.data(),
            );
          },
        );
      },
    );
  }
}

class _PendingDriverApplicationCard extends StatefulWidget {
  const _PendingDriverApplicationCard({
    required this.applicantId,
    required this.data,
  });

  final String applicantId;
  final Map<String, dynamic> data;

  @override
  State<_PendingDriverApplicationCard> createState() =>
      _PendingDriverApplicationCardState();
}

class _PendingDriverApplicationCardState
    extends State<_PendingDriverApplicationCard> {
  bool _busy = false;

  String get _name =>
      widget.data[DriverApplicationFields.fullName]?.toString().trim() ?? '—';
  String get _phone =>
      widget.data[DriverApplicationFields.phone]?.toString().trim() ?? '—';
  String get _vehicle =>
      widget.data[DriverApplicationFields.vehicleModel]?.toString().trim() ??
      '—';
  String get _plate =>
      widget.data[DriverApplicationFields.vehiclePlate]?.toString().trim() ??
      '—';

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      final updates = <String, dynamic>{
        'role': 'driver',
        'applicationStatus': 'approved',
        'isOnline': false,
      };
      if (_name != '—') updates['fullName'] = _name;
      if (_phone != '—') updates['phoneNumber'] = _phone;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.applicantId)
          .set(updates, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Driver approved.',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: AppColors.forestGreen,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not approve. Try again.',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: AppColors.rosePrimary,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.applicantId)
          .set(
        {'applicationStatus': 'rejected'},
        SetOptions(merge: true),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Application rejected.',
              style: GoogleFonts.montserrat(),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not reject. Try again.',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: AppColors.rosePrimary,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final montserrat = GoogleFonts.montserrat();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.rosePrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.rosePrimary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      style: montserrat.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Applicant ID · ${widget.applicantId.length >= 8 ? widget.applicantId.substring(0, 8) : widget.applicantId}…',
                      style: montserrat.copyWith(
                        fontSize: 11,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.badgeGoldBackground,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.accentGold.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  'PENDING',
                  style: montserrat.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.accentGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _PendingInfoLine(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: _phone,
            montserrat: montserrat,
          ),
          const SizedBox(height: 10),
          _PendingInfoLine(
            icon: Icons.directions_car_outlined,
            label: 'Vehicle',
            value: _vehicle,
            montserrat: montserrat,
          ),
          const SizedBox(height: 10),
          _PendingInfoLine(
            icon: Icons.pin_outlined,
            label: 'Plate',
            value: _plate,
            montserrat: montserrat,
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _approve,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2D4A3E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Approve',
                          style: montserrat.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _reject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300, width: 1.4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Reject',
                    style: montserrat.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingInfoLine extends StatelessWidget {
  const _PendingInfoLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.montserrat,
  });

  final IconData icon;
  final String label;
  final String value;
  final TextStyle montserrat;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.inkMuted),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: montserrat.copyWith(
                fontSize: 14,
                color: AppColors.ink,
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: montserrat.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkMuted,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: montserrat.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RegisteredDriversTab extends StatelessWidget {
  const _RegisteredDriversTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _driversStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RegisteredDriversHeader(countText: '—'),
              const SizedBox(height: 16),
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.rosePrimary,
                  ),
                ),
              ),
            ],
          );
        }

        if (snap.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RegisteredDriversHeader(countText: '—'),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.two_wheeler_outlined,
                        size: 54,
                        color: AppColors.inkMuted.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Unable to load drivers.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final docs = snap.data?.docs ?? const [];
        final count = docs.length;

        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = _crossAxisCountForWidth(
              constraints.maxWidth,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RegisteredDriversHeader(countText: '$count'),
                const SizedBox(height: 16),
                Expanded(
                  child: docs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_shipping_outlined,
                                size: 54,
                                color:
                                    AppColors.inkMuted.withValues(alpha: 0.6),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No approved drivers yet.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.inkMuted),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            mainAxisExtent: 420,
                          ),
                          padding: const EdgeInsets.only(bottom: 32),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data();
                            return _DriverCard(
                              driverId: doc.id,
                              data: data,
                              onCallDriver: () {
                                final phone = _DriverCard.readPhone(data);
                                if (phone.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No phone number for this driver.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final normalized = phone.replaceAll(' ', '');
                                launchUrl(
                                  Uri.parse('tel:$normalized'),
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                              onManageDriver: () {
                                showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (sheetContext) {
                                    final name = _DriverCard.readName(data);
                                    return SafeArea(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          12,
                                          12,
                                          24,
                                        ),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 560,
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: AppColors.border
                                                    .withValues(alpha: 0.9),
                                              ),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .local_shipping_outlined,
                                                        color:
                                                            AppColors.rosePrimary,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(
                                                          name.isNotEmpty
                                                              ? name
                                                              : 'Driver',
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .titleMedium
                                                                  ?.copyWith(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w800,
                                                                    color: AppColors
                                                                        .ink,
                                                                  ),
                                                        ),
                                                      ),
                                                      IconButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                                    sheetContext)
                                                                .pop(),
                                                        icon: const Icon(
                                                          Icons.close,
                                                        ),
                                                        tooltip: 'Close',
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    'Assign orders to this driver, update availability, or view active route (coming soon).',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          color: AppColors
                                                              .inkMuted,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 18),
                                                  FilledButton(
                                                    onPressed: () {
                                                      Navigator.of(sheetContext)
                                                          .pop();
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Manage tools coming soon.',
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    style:
                                                        FilledButton.styleFrom(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        vertical: 14,
                                                        horizontal: 18,
                                                      ),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(14),
                                                      ),
                                                      backgroundColor:
                                                          AppColors.ink,
                                                      foregroundColor:
                                                          Colors.white,
                                                    ),
                                                    child: const Text(
                                                      'Acknowledge',
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _LiveFleetBanner extends StatelessWidget {
  const _LiveFleetBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.rosePrimary.withValues(alpha: 0.18),
                AppColors.sage.withValues(alpha: 0.14),
                const Color(0xFFF4F0E6),
              ],
            ),
            border: Border.all(
              color: AppColors.rosePrimary.withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.rosePrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.rosePrimary.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.map_rounded,
                  size: 24,
                  color: AppColors.rosePrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'View Live Fleet Map',
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink,
                                letterSpacing: -0.2,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track all active drivers in real-time to assign nearby orders',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 20,
                color: AppColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisteredDriversHeader extends StatelessWidget {
  const _RegisteredDriversHeader({required this.countText});

  final String countText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Registered Drivers',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.rosePrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.rosePrimary.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Text(
            countText,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.rosePrimary,
                ),
          ),
        ),
      ],
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.driverId,
    required this.data,
    required this.onCallDriver,
    required this.onManageDriver,
  });

  final String driverId;
  final Map<String, dynamic> data;
  final VoidCallback onCallDriver;
  final VoidCallback onManageDriver;

  static String readName(Map<String, dynamic> data) {
    final raw = data['fullName'] ??
        data['driverFullName'] ??
        data['name'] ??
        data['displayName'] ??
        data['userName'] ??
        data['username'];
    final s = raw?.toString().trim() ?? '';
    if (s.isNotEmpty) return s;
    final email = data['email']?.toString().trim() ?? '';
    if (email.isNotEmpty && email.contains('@')) return email.split('@').first;
    return '';
  }

  static String readPhone(Map<String, dynamic> data) {
    final raw = data['phoneNumber'] ??
        data['driverPhone'] ??
        data['phone'] ??
        data['contactPhone'] ??
        data['whatsapp'];
    return raw?.toString().trim() ?? '';
  }

  static String readVehicleInfo(Map<String, dynamic> data) {
    final dm = data['driverVehicleModel']?.toString().trim() ?? '';
    final dp = data['driverVehiclePlate']?.toString().trim() ?? '';
    if (dm.isNotEmpty || dp.isNotEmpty) {
      if (dm.isNotEmpty && dp.isNotEmpty) return '$dm · $dp';
      return dm.isNotEmpty ? dm : dp;
    }
    final direct = data['vehicleInfo'] ??
        data['vehicle'] ??
        data['carInfo'] ??
        data['vehicleDetails'];
    final directStr = direct?.toString().trim() ?? '';
    if (directStr.isNotEmpty) return directStr;

    final make = data['vehicleMake']?.toString().trim() ?? '';
    final model = data['vehicleModel']?.toString().trim() ?? '';
    final plate = data['vehiclePlate']?.toString().trim() ??
        data['plateNumber']?.toString().trim() ??
        data['registrationNumber']?.toString().trim() ??
        data['plate'];

    final name = [
      if (make.isNotEmpty) make,
      if (model.isNotEmpty) model,
    ].join(' ');

    if (name.isEmpty && plate.isEmpty) return '—';
    if (name.isNotEmpty && plate.isNotEmpty) return '$name - $plate';
    return name.isNotEmpty ? name : plate;
  }

  static String readActiveOrder(Map<String, dynamic> data) {
    final raw = data['activeOrder'] ??
        data['currentActiveOrder'] ??
        data['activeOrderId'] ??
        data['currentActiveOrderId'] ??
        data['activeOrderCode'] ??
        data['currentActiveOrderCode'];
    final s = raw?.toString().trim() ?? '';
    return s;
  }

  static bool _readOnline(Map<String, dynamic> data) {
    final v = data['isOnline'] ?? data['online'];
    // If online field isn't wired yet, assume "available" so the UI stays
    // usable during backend setup.
    if (v == null) return true;
    if (v is bool) return v;
    if (v is num) return v != 0;
    return v.toString().toLowerCase() == 'true';
  }

  static bool _statusIndicatesDelivery(Map<String, dynamic> data) {
    final statusRaw = data['availabilityStatus'] ??
        data['driverStatus'] ??
        data['status'] ??
        data['deliveryStatus'];
    final s = statusRaw?.toString().toLowerCase().trim() ?? '';
    if (s.isEmpty) return false;
    return s.contains('delivery') ||
        s.contains('on_delivery') ||
        s.contains('on delivery') ||
        s.contains('on-delivery') ||
        s.contains('running');
  }

  static bool _statusIndicatesOffline(Map<String, dynamic> data) {
    final statusRaw = data['availabilityStatus'] ??
        data['driverStatus'] ??
        data['status'] ??
        data['deliveryStatus'];
    final s = statusRaw?.toString().toLowerCase().trim() ?? '';
    if (s.isEmpty) return false;
    return s.contains('offline') || s.contains('unavailable');
  }

  static _DriverStatus _computeStatus(Map<String, dynamic> data) {
    final activeOrder = readActiveOrder(data);
    final hasActiveOrder = activeOrder.isNotEmpty;

    final offline = _statusIndicatesOffline(data) || (data['isOnline'] == false);
    if (offline) return _DriverStatus.offline;

    final onDelivery = _statusIndicatesDelivery(data) ||
        hasActiveOrder ||
        (data['onDelivery'] == true);

    if (onDelivery) return _DriverStatus.onDelivery;
    final online = _readOnline(data);
    if (!online) return _DriverStatus.offline;
    return _DriverStatus.available;
  }

  static String _initials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    String takeFirstChar(String s) => s.isNotEmpty ? s.substring(0, 1) : '';
    final a = takeFirstChar(parts.first).toUpperCase();
    final b = parts.length > 1 ? takeFirstChar(parts.last).toUpperCase() : '';
    return (a + b).trim();
  }

  static Color _avatarBg(String seed) {
    const colors = [
      Color(0xFFF4E7EC), // blush
      Color(0xFFE8EEF6), // mist blue
      Color(0xFFEAF4EF), // mint
      Color(0xFFF6F1E7), // champagne
      Color(0xFFEFEAF7), // lavender
    ];
    final hash = seed.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final name = readName(data);
    final phone = readPhone(data);
    final vehicleInfo = readVehicleInfo(data);
    final activeOrder = readActiveOrder(data);

    final status = _computeStatus(data);
    final statusLabel = switch (status) {
      _DriverStatus.available => 'Available',
      _DriverStatus.onDelivery => 'On Delivery',
      _DriverStatus.offline => 'Offline',
    };

    final badgeColors = switch (status) {
      _DriverStatus.available => (
          bg: AppColors.sage.withValues(alpha: 0.25),
          border: AppColors.sage.withValues(alpha: 0.55),
          text: AppColors.forestGreen,
        ),
      _DriverStatus.onDelivery => (
          bg: const Color(0xFFFFE0B2),
          border: const Color(0xFFFFA726),
          text: const Color(0xFFEF6C00),
        ),
      _DriverStatus.offline => (
          bg: AppColors.border.withValues(alpha: 0.75),
          border: AppColors.border,
          text: AppColors.inkMuted,
        ),
    };

    final theme = Theme.of(context);
    final avatarBg = _avatarBg(name.isNotEmpty ? name : driverId);
    final avatarFg = AppColors.inkCharcoal.withValues(alpha: 0.85);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarBg,
                  child: Text(
                    _initials(name.isNotEmpty ? name : 'Driver'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: avatarFg,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name.isNotEmpty ? name : 'Unnamed Driver',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColors.bg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: badgeColors.border, width: 1),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: badgeColors.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.75),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: phone.isNotEmpty ? phone : '—',
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.directions_car_outlined,
                    label: 'Vehicle',
                    value: vehicleInfo,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.assignment_outlined,
                    label: 'Active Order',
                    value: activeOrder.isNotEmpty ? activeOrder : '—',
                  ),
                ],
              ),
            ),
            const Spacer(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onCallDriver,
                    icon: const Icon(Icons.phone_outlined, size: 18),
                    label: const Text('Call Driver'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: AppColors.ink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onManageDriver,
                    icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                    label: const Text('Manage'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: AppColors.rosePrimary,
                      side: BorderSide(
                        color: AppColors.rosePrimary.withValues(alpha: 0.7),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.inkMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: $value',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

enum _DriverStatus { available, onDelivery, offline }

