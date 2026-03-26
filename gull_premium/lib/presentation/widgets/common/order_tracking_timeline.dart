import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

class OrderTrackingTimeline extends StatelessWidget {
  const OrderTrackingTimeline({
    super.key,
    required this.orderStatus,
  });

  final String orderStatus;

  @override
  Widget build(BuildContext context) {
    final currentIndex = _stepIndexForStatus(orderStatus);

    return Column(
      children: List.generate(_steps.length, (index) {
        final step = _steps[index];
        final isReached = currentIndex >= 0 && index <= currentIndex;
        final isLast = index == _steps.length - 1;

        final titleColor =
            isReached ? AppColors.forestGreen : AppColors.inkMuted.withValues(alpha: 0.72);
        final subtitleColor =
            isReached ? AppColors.inkMuted : AppColors.inkMuted.withValues(alpha: 0.56);
        final lineColor = isReached
            ? AppColors.forestGreen.withValues(alpha: 0.75)
            : AppColors.border.withValues(alpha: 0.9);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isReached
                          ? AppColors.forestGreen.withValues(alpha: 0.12)
                          : AppColors.background,
                      border: Border.all(
                        color: isReached
                            ? AppColors.forestGreen.withValues(alpha: 0.6)
                            : AppColors.border,
                      ),
                    ),
                    child: Icon(
                      isReached ? step.filledIcon : step.outlinedIcon,
                      color: isReached ? AppColors.forestGreen : AppColors.inkMuted,
                      size: 20,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: lineColor,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3, bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: GoogleFonts.montserrat(
                          fontSize: 13.5,
                          fontWeight: isReached ? FontWeight.w800 : FontWeight.w600,
                          color: titleColor,
                          letterSpacing: 0.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        step.subtitle,
                        style: GoogleFonts.montserrat(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: subtitleColor,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _TimelineStep {
  const _TimelineStep({
    required this.statusKeys,
    required this.title,
    required this.subtitle,
    required this.outlinedIcon,
    required this.filledIcon,
  });

  final List<String> statusKeys;
  final String title;
  final String subtitle;
  final IconData outlinedIcon;
  final IconData filledIcon;
}

const _steps = [
  _TimelineStep(
    statusKeys: ['pending', 'received', 'new'],
    title: 'Order Placed',
    subtitle: 'Your luxury order has been received.',
    outlinedIcon: Icons.receipt_long_outlined,
    filledIcon: Icons.receipt_long,
  ),
  _TimelineStep(
    statusKeys: ['preparing', 'accepted'],
    title: 'Preparing',
    subtitle: 'Your luxury item is being arranged.',
    outlinedIcon: Icons.local_florist_outlined,
    filledIcon: Icons.local_florist,
  ),
  _TimelineStep(
    statusKeys: ['ready', 'out_for_delivery', 'on_the_way', 'ontheway', 'on-the-way'],
    title: 'Out for Delivery / Ready',
    subtitle: 'Final checks complete and heading your way.',
    outlinedIcon: Icons.local_shipping_outlined,
    filledIcon: Icons.local_shipping,
  ),
  _TimelineStep(
    statusKeys: ['delivered'],
    title: 'Delivered',
    subtitle: 'Delivered with care. Enjoy your moment.',
    outlinedIcon: Icons.check_circle_outline,
    filledIcon: Icons.check_circle,
  ),
];

int _stepIndexForStatus(String status) {
  final normalized = status.trim().toLowerCase().replaceAll(' ', '_');
  for (var i = 0; i < _steps.length; i++) {
    if (_steps[i].statusKeys.contains(normalized)) return i;
  }
  return -1;
}
