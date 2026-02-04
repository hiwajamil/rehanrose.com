import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../common/primary_button.dart';

class AppScaffold extends StatelessWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const _TopBar(),
            child,
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/'),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                'Rehan Rose',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          const Spacer(),
          const _NavItem(label: 'Flowers'),
          const _NavItem(label: 'Occasions'),
          const _NavItem(label: 'Vendors'),
          const _NavItem(label: 'About'),
          PrimaryButton(
            label: 'Become a Vendor',
            onPressed: () => context.go('/vendor'),
            variant: PrimaryButtonVariant.outline,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final String label;

  const _NavItem({required this.label});

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: _hovered ? AppColors.rose : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
        child: Text(
          widget.label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
