import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seo/seo.dart';

import '../../../core/theme/app_colors.dart';

/// Product info displayed in a vertical column: Badge (Code) → Hero (Name) → Value (Price).
/// Handles RTL/LTR mixed content with [CrossAxisAlignment.start].
class ProductInfoColumn extends StatelessWidget {
  /// Product code (e.g. R-102). Shown as badge at top. Null = hidden.
  final String? code;
  /// Product name. Hero text, large and bold.
  final String name;
  /// Display price string (e.g. "IQD 25,000").
  final String price;
  /// Optional original price for sale strikethrough. Shown above [price] when set.
  final String? originalPrice;
  /// Optional description/note. Shown between name and price.
  final String? description;
  /// When true, name uses 22px (detail page). When false, 16px (card).
  final bool isDetailPage;

  const ProductInfoColumn({
    super.key,
    this.code,
    required this.name,
    required this.price,
    this.originalPrice,
    this.description,
    this.isDetailPage = false,
  });

  @override
  Widget build(BuildContext context) {
    final nameFontSize = isDetailPage ? 22.0 : 16.0;
    final primaryColor = Theme.of(context).primaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Badge (Code)
        if (code != null && code!.isNotEmpty) ...[
          Seo.text(
            text: '#$code',
            style: TextTagStyle.p,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '#$code',
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        // 2. Hero (Name)
        Seo.text(
          text: name,
          style: TextTagStyle.h2,
          child: Text(
            name,
            style: TextStyle(
              fontSize: nameFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: isDetailPage ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        // 3. Description (optional)
        if (description != null && description!.isNotEmpty) ...[
          Seo.text(
            text: description!,
            style: TextTagStyle.p,
            child: Text(
              description!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.inkMuted,
                  ),
              maxLines: isDetailPage ? null : 1,
              overflow: isDetailPage ? null : TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
        ],
        // 4. Original price (strikethrough, optional)
        if (originalPrice != null && originalPrice!.isNotEmpty) ...[
          Seo.text(
            text: originalPrice!,
            style: TextTagStyle.p,
            child: Text(
              originalPrice!,
              style: (isDetailPage
                      ? Theme.of(context).textTheme.bodyMedium
                      : Theme.of(context).textTheme.bodySmall)
                  ?.copyWith(
                color: AppColors.inkMuted,
                decoration: TextDecoration.lineThrough,
                decorationColor: AppColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        // 5. Value (Price)
        Seo.text(
          text: price,
          style: TextTagStyle.p,
          child: Text(
            price,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w600,
              color: primaryColor,
              fontSize: isDetailPage ? 20 : 16,
            ),
          ),
        ),
      ],
    );
  }
}
