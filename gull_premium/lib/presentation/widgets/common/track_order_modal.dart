import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/controllers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/order_model.dart';
import '../../../l10n/app_localizations.dart';
import 'primary_button.dart';

/// Shows a modal where the user can enter an Order ID to check status.
/// Queries Firebase Orders collection and displays a timeline (Received → Preparing → On the Way → Delivered).
void showTrackOrderModal(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        l10n.trackOrderTitle,
        style: const TextStyle(color: AppColors.inkCharcoal),
      ),
      content: SizedBox(
        width: 360,
        child: const _TrackOrderModalContent(),
      ),
    ),
  );
}

class _TrackOrderModalContent extends ConsumerStatefulWidget {
  const _TrackOrderModalContent();

  @override
  ConsumerState<_TrackOrderModalContent> createState() =>
      _TrackOrderModalContentState();
}

class _TrackOrderModalContentState extends ConsumerState<_TrackOrderModalContent>
    with SingleTickerProviderStateMixin {
  final TextEditingController _orderIdController = TextEditingController();
  bool _loading = false;
  String? _error;
  OrderModel? _order;
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orderIdController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = _orderIdController.text.trim();
    if (id.isEmpty) return;

    setState(() {
      _error = null;
      _order = null;
      _loading = true;
    });

    final repo = ref.read(orderRepositoryProvider);
    final order = await repo.getByOrderId(id);

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (order != null) {
        _order = order;
        _error = null;
      } else {
        _error = AppLocalizations.of(context)!.orderNotFound;
      }
    });
  }

  void _reset() {
    setState(() {
      _error = null;
      _order = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_order != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OrderTimeline(order: _order!, blinkAnimation: _blinkController),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: 8),
              PrimaryButton(
                label: l10n.trackOrderButton,
                onPressed: _reset,
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.trackOrderHint,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.inkMuted,
              ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _orderIdController,
          decoration: InputDecoration(
            labelText: l10n.orderIdLabel,
            hintText: '#ORD-123',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
            errorText: _error,
          ),
          textDirection: Directionality.of(context),
          onSubmitted: (_) => _submit(),
        ),
        if (_loading) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _loading
                  ? null
                  : () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            const SizedBox(width: 8),
            PrimaryButton(
              label: l10n.trackOrderButton,
              onPressed: _loading ? () {} : _submit,
            ),
          ],
        ),
      ],
    );
  }
}

class _OrderTimeline extends StatelessWidget {
  const _OrderTimeline({
    required this.order,
    required this.blinkAnimation,
  });

  final OrderModel order;
  final Animation<double> blinkAnimation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentStep = order.status.stepIndex;
    final labels = [
      l10n.orderStatusReceived,
      l10n.orderStatusPreparing,
      l10n.orderStatusOnTheWay,
      l10n.orderStatusDelivered,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        final isCompleted = currentStep > index;
        final isActive = currentStep == index;
        final isPending = currentStep < index;

        return _TimelineRow(
          stepIndex: index,
          label: labels[index],
          isCompleted: isCompleted,
          isActive: isActive,
          isPending: isPending,
          blinkAnimation: blinkAnimation,
          isLast: index == 3,
        );
      }),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.stepIndex,
    required this.label,
    required this.isCompleted,
    required this.isActive,
    required this.isPending,
    required this.blinkAnimation,
    required this.isLast,
  });

  final int stepIndex;
  final String label;
  final bool isCompleted;
  final bool isActive;
  final bool isPending;
  final Animation<double> blinkAnimation;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    Widget icon;
    if (isCompleted) {
      icon = Icon(
        Icons.check_circle,
        color: AppColors.sage,
        size: 28,
      );
    } else if (isActive) {
      // Only "On the Way" (index 2) blinks; others show solid in-progress.
      final iconWidget = Icon(
        stepIndex == 2 ? Icons.local_shipping_outlined : Icons.hourglass_empty,
        color: AppColors.rosePrimary,
        size: 28,
      );
      icon = stepIndex == 2
          ? FadeTransition(opacity: blinkAnimation, child: iconWidget)
          : iconWidget;
    } else {
      icon = Icon(
        Icons.radio_button_unchecked,
        color: AppColors.inkMuted.withValues(alpha: 0.5),
        size: 28,
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              icon,
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: isCompleted
                        ? AppColors.sage
                        : AppColors.inkMuted.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isPending
                        ? AppColors.inkMuted.withValues(alpha: 0.7)
                        : AppColors.inkCharcoal,
                    fontWeight: isActive ? FontWeight.w600 : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
