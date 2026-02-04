import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/whatsapp_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/common/order_via_whatsapp_button.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';

class ProductDetailPage extends StatelessWidget {
  final String flowerId;

  const ProductDetailPage({super.key, required this.flowerId});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('bouquets')
            .doc(flowerId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SectionContainer(
              padding: EdgeInsets.symmetric(vertical: 72),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (!snapshot.hasData || snapshot.data!.data() == null) {
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

          final data = snapshot.data!.data()!;
          final imageUrls =
              (data['imageUrls'] as List?)?.cast<String>() ?? [];
          final imageUrl = imageUrls.isNotEmpty
              ? imageUrls.first
              : 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80';
          final name = data['name']?.toString() ?? 'Untitled bouquet';
          final priceIqd = data['priceIqd']?.toString() ?? '--';
          final price = 'IQD $priceIqd';
          final description =
              data['description']?.toString() ?? 'Vendor bouquet';
          final bouquetCode = data['bouquetCode']?.toString();

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
                      _buildInfo(context, name, description, price, bouquetCode),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OrderViaWhatsAppButton(
                          onPressed: () => launchOrderWhatsApp(
                            flowerName: name,
                            flowerPrice: price,
                            flowerId: flowerId,
                            flowerImageUrl: imageUrl,
                            bouquetCode: bouquetCode,
                          ),
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
                                _buildInfo(context, name, description, price, bouquetCode),
                                const SizedBox(height: 28),
                                SizedBox(
                                  width: double.infinity,
                                  child: OrderViaWhatsAppButton(
                                    onPressed: () => launchOrderWhatsApp(
                                      flowerName: name,
                                      flowerPrice: price,
                                      flowerId: flowerId,
                                      flowerImageUrl: imageUrl,
                                      bouquetCode: bouquetCode,
                                    ),
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
