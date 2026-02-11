import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../controllers/controllers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/add_on_model.dart';
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
          final imageUrl = bouquet.imageUrls.isNotEmpty
              ? bouquet.imageUrls.first
              : 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80';
          final price = 'IQD ${bouquet.priceIqd}';
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
                      _buildImage(imageUrl),
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
                        ),
                      ),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildImage(imageUrl),
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

  Widget _buildImage(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          cacheWidth: 800,
          cacheHeight: 1000,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.border,
            child: const Center(child: Icon(Icons.local_florist, size: 48)),
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
        Text(
          name,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (bouquetCode != null && bouquetCode.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            bouquetCode,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.inkMuted,
              ),
        ),
        const SizedBox(height: 20),
        Text(
          price,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
