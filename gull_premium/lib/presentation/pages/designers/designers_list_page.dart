import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../controllers/controllers.dart';
import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/vendor_list_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/common/app_cached_image.dart';
import '../../widgets/layout/app_scaffold.dart';

/// Designers (Florists) list page. Shows all approved vendors in a grid.
/// Header "Designers" / "Florists" links here. Tapping a card opens [VendorProfilePage].
class DesignersListPage extends ConsumerWidget {
  const DesignersListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final vendorsAsync = ref.watch(vendorsListProvider);

    return AppScaffold(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.navFlorists,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.inkCharcoal,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.trustedLocalFlorists,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.inkMuted,
                  ),
            ),
            const SizedBox(height: 48),
            vendorsAsync.when(
              loading: () => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    l10n.loadingBouquets,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                  ),
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.couldNotLoadBouquets,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.inkMuted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => ref.invalidate(vendorsListProvider),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(l10n.retry),
                      ),
                    ],
                  ),
                ),
              ),
              data: (vendors) {
                if (vendors.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.noBouquetsYet,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.inkMuted),
                      ),
                    ),
                  );
                }
                return _VendorGrid(vendors: vendors);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorGrid extends StatelessWidget {
  final List<VendorListModel> vendors;

  const _VendorGrid({required this.vendors});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width < kMobileBreakpoint
        ? 2
        : width < kTabletBreakpoint
            ? 3
            : 4;
    final gap = width < kMobileBreakpoint ? 12.0 : 20.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final gapTotal = (crossAxisCount - 1) * gap;
        final childWidth = (constraints.maxWidth - gapTotal) / crossAxisCount;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: vendors
              .map((v) => SizedBox(
                    width: childWidth,
                    child: _VendorCard(vendor: v),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _VendorCard extends StatelessWidget {
  final VendorListModel vendor;

  const _VendorCard({required this.vendor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/florist/${vendor.id}'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: vendor.logoUrl != null && vendor.logoUrl!.isNotEmpty
                      ? AppCachedImage(
                          imageUrl: vendor.logoUrl!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorIcon: Icons.store_rounded,
                          errorIconSize: 40,
                        )
                      : Container(
                          color: AppColors.background,
                          child: Icon(Icons.store_rounded, size: 40, color: AppColors.inkMuted),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                vendor.shopName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.inkCharcoal,
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (vendor.rating != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded,
                        size: 18, color: AppColors.rose),
                    const SizedBox(width: 4),
                    Text(
                      vendor.rating!.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.inkMuted,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
