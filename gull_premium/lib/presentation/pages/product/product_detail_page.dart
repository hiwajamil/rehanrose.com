import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:seo/seo.dart';

import '../../../controllers/controllers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_format_utils.dart';
import '../../../core/utils/seo_meta_helper.dart';
import '../../../l10n/app_localizations.dart';
import '../../../data/models/add_on_model.dart';
import '../../widgets/common/app_cached_image.dart';
import '../../widgets/common/make_it_perfect_section.dart';
import '../../widgets/common/order_via_whatsapp_button.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  final String flowerId;

  const ProductDetailPage({super.key, required this.flowerId});

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  final Set<String> _selectedAddOnIds = {};
  bool _hasLoggedViewItem = false;

  void _toggleAddOn(AddOnModel addOn) {
    setState(() {
      if (_selectedAddOnIds.contains(addOn.id)) {
        _selectedAddOnIds.remove(addOn.id);
      } else {
        _selectedAddOnIds.add(addOn.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bouquetAsync = ref.watch(bouquetDetailProvider(widget.flowerId));
    final addOnsAsync = ref.watch(addOnsProvider(null));
    final isOnline = ref.watch(connectivityStatusProvider).value ?? true;

    return AppScaffold(
      child: bouquetAsync.when(
        loading: () => const SectionContainer(
          padding: EdgeInsets.symmetric(vertical: 72),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => SectionContainer(
          padding: const EdgeInsets.symmetric(vertical: 72),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Product not found',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
        data: (bouquet) {
          final l10n = AppLocalizations.of(context)!;
          if (bouquet != null && !_hasLoggedViewItem) {
            _hasLoggedViewItem = true;
            final itemId = bouquet.id;
            final itemName = bouquet.name;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(analyticsServiceProvider).logViewItem(
                    itemId: itemId,
                    itemName: itemName,
                  );
              ref.read(bouquetRepositoryProvider).incrementViewCount(itemId);
            });
          }
          if (bouquet == null) {
            return SectionContainer(
              padding: const EdgeInsets.symmetric(vertical: 72),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Product not found',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Go back'),
                    ),
                  ],
                ),
              ),
            );
          }
          updatePageMeta(
            title: '${bouquet.name} - $kAppName',
            description: bouquet.description,
            keywords: 'flowers, bouquet, ${bouquet.name}, Rehan Rose',
          );
          final imageUrl = bouquet.imageUrls.isNotEmpty
              ? bouquet.imageUrls.first
              : 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80';
          final price = formatPriceWithCurrency(bouquet.priceIqd, l10n.currencyIqd);
          final bouquetCode = bouquet.bouquetCode.isNotEmpty
              ? bouquet.bouquetCode
              : null;
          final addOns = addOnsAsync.maybeWhen(
              data: (list) => list, orElse: () => <AddOnModel>[]);
          Widget makeItPerfectSection() {
            return addOnsAsync.when(
              data: (list) => MakeItPerfectSection(
                addOns: list,
                selectedAddOnIds: _selectedAddOnIds,
                onToggle: _toggleAddOn,
                bouquetPriceIqd: bouquet.priceIqd,
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            );
          }

          void onPlaceOrder() {
            ref.read(analyticsServiceProvider).logClickWhatsApp(
                  itemId: bouquet.id,
                  itemName: bouquet.name,
                );
            ref.read(bouquetRepositoryProvider).incrementOrderCount(bouquet.id);
            context.push('/flower/${widget.flowerId}/order');
          }

          return SectionContainer(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 780;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isNarrow) ...[
                      _buildImage(imageUrl, bouquet.name),
                      const SizedBox(height: 24),
                      _buildInfo(context, bouquet.name, bouquet.description,
                          price, bouquetCode),
                      const SizedBox(height: 24),
                      makeItPerfectSection(),
                      if (addOns.isNotEmpty) const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: OrderViaWhatsAppButton(
                          onPressed: onPlaceOrder,
                          enabled: isOnline,
                        ),
                      ),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildImage(imageUrl, bouquet.name),
                          ),
                          const SizedBox(width: 48),
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfo(context, bouquet.name,
                                    bouquet.description, price, bouquetCode),
                                const SizedBox(height: 28),
                                makeItPerfectSection(),
                                if (addOns.isNotEmpty) const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: OrderViaWhatsAppButton(
                                    onPressed: onPlaceOrder,
                                    enabled: isOnline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildImage(String imageUrl, String alt) {
    return Seo.image(
      alt: alt,
      src: imageUrl,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: AppCachedImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            memCacheWidth: 800,
            memCacheHeight: 1000,
          ),
        ),
      ),
    );
  }

  Widget _buildInfo(
    BuildContext context,
    String name,
    String description,
    String price,
    String? bouquetCode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Seo.text(
          text: name,
          style: TextTagStyle.h2,
          child: Text(
            name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        if (bouquetCode != null && bouquetCode.isNotEmpty) ...[
          const SizedBox(height: 6),
          Seo.text(
            text: bouquetCode,
            child: Text(
              bouquetCode,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Seo.text(
          text: description,
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
        ),
        const SizedBox(height: 20),
        Seo.text(
          text: price,
          child: Text(
            price,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}
