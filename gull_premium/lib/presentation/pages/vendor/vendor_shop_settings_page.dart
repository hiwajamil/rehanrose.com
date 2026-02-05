import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/layout/section_container.dart';

/// Shop settings: name, description, logo, contact, online/offline.
class VendorShopSettingsPage extends StatelessWidget {
  const VendorShopSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SectionContainer(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shop Settings',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Update your shop name, description, and contact info.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SettingsField(
                    label: 'Shop name',
                    hint: 'Your studio name',
                  ),
                  const SizedBox(height: 20),
                  _SettingsField(
                    label: 'Description',
                    hint: 'Short description of your shop',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  _SettingsField(
                    label: 'Contact (phone or email)',
                    hint: 'Contact info for customers',
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Save changes',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsField extends StatelessWidget {
  final String label;
  final String hint;
  final int maxLines;

  const _SettingsField({
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.rose),
            ),
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.ink,
              ),
        ),
      ],
    );
  }
}
