import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../controllers/controllers.dart';
import '../../../data/models/add_on_model.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';
import 'add_on_category_inventory_page.dart';

/// Landing page for Manage Add-ons: displays three category cards (Vase, Chocolates, Cards)
/// that navigate to their respective inventory screens.
class ManageAddOnsLandingPage extends ConsumerWidget {
  const ManageAddOnsLandingPage({super.key});

  static const List<({AddOnType type, String label, IconData icon})>
      _categories = [
    (type: AddOnType.vase, label: 'Vases', icon: Icons.local_florist_outlined),
    (
      type: AddOnType.chocolate,
      label: 'Chocolates',
      icon: Icons.card_giftcard_outlined,
    ),
    (type: AddOnType.card, label: 'Cards', icon: Icons.celebration_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;

    return AppScaffold(
      child: SectionContainer(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 20 : 48,
          vertical: isMobile ? 24 : 40,
        ),
        child: authAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _buildAccessDenied(context),
          data: (user) {
            if (user == null) return _buildAccessDenied(context);
            return FutureBuilder<bool>(
              future: ref.read(authRepositoryProvider).isAdmin(user.uid),
              builder: (context, adminSnapshot) {
                if (adminSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (adminSnapshot.data != true) return _buildAccessDenied(context);
                return _buildContent(context, isMobile);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildAccessDenied(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Access restricted. Sign in as admin.',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => context.pop(),
          child: const Text('Back to Admin'),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, bool isMobile) {
    final playfair = GoogleFonts.playfairDisplay(
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
              tooltip: 'Back to dashboard',
              style: IconButton.styleFrom(
                foregroundColor: AppColors.ink,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Manage Add-ons',
                style: playfair.copyWith(fontSize: isMobile ? 22 : 26),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Select a category to manage inventory',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.inkMuted,
                fontSize: 15,
              ),
        ),
        SizedBox(height: isMobile ? 28 : 40),
        isMobile
            ? _buildCategoryColumn(context)
            : _buildCategoryGrid(context),
      ],
    );
  }

  Widget _buildCategoryColumn(BuildContext context) {
    return Column(
      children: _categories
          .map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _CategoryCard(
                  label: c.label,
                  icon: c.icon,
                  onTap: () => AddOnCategoryInventoryPage.navigate(context, c.type),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildCategoryGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            constraints.maxWidth > 700 ? 3 : (constraints.maxWidth > 450 ? 2 : 1);
        return GridView.count(
          shrinkWrap: true,
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: 1.4,
          children: _categories
              .map((c) => _CategoryCard(
                    label: c.label,
                    icon: c.icon,
                    onTap: () =>
                        AddOnCategoryInventoryPage.navigate(context, c.type),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        elevation: _hovered ? 6 : 2,
        shadowColor: AppColors.shadow.withValues(alpha: 0.15),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          hoverColor: AppColors.rose.withValues(alpha: 0.04),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _hovered
                    ? AppColors.rose.withValues(alpha: 0.5)
                    : AppColors.border,
                width: _hovered ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.rose.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icon,
                    size: 48,
                    color: AppColors.rose,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Manage',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: AppColors.inkMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
