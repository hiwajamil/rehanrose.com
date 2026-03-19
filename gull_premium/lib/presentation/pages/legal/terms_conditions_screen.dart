import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// Terms & Conditions screen for Rehan Rose.
///
class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  // i18n: These texts are provided by the user (per language) and will display
  // based on the current locale languageCode.
  (String intro, List<String> bullets) _legalContentFor(String languageCode) {
    switch (languageCode) {
      case 'ku':
        return (
          'بەخێربێن بۆ ڕەیحان ڕۆز. بەکارهێنانی ئەم ئەپڵیکەیشنە لەلایەن ئێوەوە، واتای ڕازیبوونە بەم مەرجانەی خوارەوە:',
          const [
            'کوالیتی و گەیاندن: ئێمە و هاوبەشەکانمان (گوڵفرۆشەکان) بەڵێنی بەرزترین کوالێتی دەدەین. کاتی گەیاندن پشت دەبەستێت بە شوێن و دۆخی هاتوچۆ، بەڵام تیمەکانمان هەوڵی تەواو دەدەن لە کاتی دیاریکراودا داواکارییەکانتان بگەیەنن.',
            'پارەدان و گەڕاندنەوە: هەموو مامەڵە داراییەکان پارێزراون. گەڕاندنەوەی پارە تەنها لە کاتی بوونی کێشەیەکی سەلمێنراودا دەبێت لە کوالێتی گوڵەکەدا پێش وەرگرتنی.',
            'پاراستنی زانیارییەکان: زانیارییە کەسییەکانتان لای ئێمە پارێزراوە و تەنها بۆ مەبەستی گەیاندنی خزمەتگوزارییەکانمان بەکاردەهێنرێت.',
          ],
        );
      case 'ar':
        return (
          'مرحباً بكم في ريحان روز. باستخدامكم لهذا التطبيق، فإنكم توافقون على الشروط التالية:',
          const [
            'الجودة والتوصيل: نتعهد نحن وشركاؤنا (بائعو الزهور) بتقديم أعلى مستويات الجودة. تعتمد أوقات التوصيل على الموقع وحالة المرور، لكن فرقنا تبذل قصارى جهدها لتوصيل طلباتكم في الوقت المحدد.',
            'الدفع والاسترجاع: جميع المعاملات المالية آمنة ومحمية. يتم استرجاع الأموال فقط في حال وجود مشكلة مثبتة في جودة الزهور قبل استلامها.',
            'حماية الخصوصية: بياناتكم الشخصية محفوظة لدينا بأمان، وتُستخدم فقط لغرض تحسين تجربة الإهداء وتقديم خدماتنا.',
          ],
        );
      case 'en':
      default:
        return (
          'Welcome to Rehan Rose. By accessing or using our app, you agree to be bound by these terms:',
          const [
            'Quality & Delivery: We partner with elite florists to ensure premium quality. Delivery times are estimates, and our fleet strives for punctuality.',
            'Payments & Refunds: All transactions are secure. Refunds are only issued in the event of verified quality issues prior to acceptance.',
            'Privacy: Your personal data is strictly protected and used solely to enhance your gifting experience.',
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    const appBarTitle = 'Terms & Conditions';
    final languageCode = Localizations.localeOf(context).languageCode;
    final content = _legalContentFor(languageCode);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          'Rehan Rose Legal Terms',
                          style: GoogleFonts.montserrat(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.inkCharcoal,
                            letterSpacing: -0.4,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          content.$1,
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            height: 1.6,
                            fontWeight: FontWeight.w500,
                            color: AppColors.inkMuted,
                          ),
                          textAlign: TextAlign.start,
                        ),
                        const SizedBox(height: 18),
                        _BulletList(
                          items: content.$2,
                        ),
                        const SizedBox(height: 8),
                        // i18n: Add additional paragraphs/sections once you have
                        // further localized text beyond the 3 terms above.
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '•',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.rosePrimary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

