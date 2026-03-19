import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final faqs = _faqItemsFor(languageCode);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l10n.helpFaq,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: faqs.length,
          itemBuilder: (context, index) {
            final item = faqs[index];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                elevation: 1,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: Colors.black.withValues(alpha: 0.06),
                    width: 1,
                  ),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: EdgeInsets.zero,
                  collapsedBackgroundColor: Colors.white,
                  backgroundColor: Colors.white,
                  iconColor: AppColors.inkMuted,
                  collapsedIconColor: AppColors.inkMuted,
                  title: Text(
                    item.question,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: AppColors.inkCharcoal,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(
                        item.answer,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FaqItem {
  const _FaqItem({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;
}

List<_FaqItem> _faqItemsFor(String languageCode) {
  switch (languageCode) {
    case 'ku':
      return const [
        _FaqItem(
          question: 'چۆن دەتوانم چاودێری گەیاندنی داواکارییەکەم بکەم؟',
          answer:
              'هەر کە داواکارییەکەت دەرچوو، دەتوانیت لە بەشی \'داواکارییەکانم\' لەناو ئەپەکەدا بە شێوەی ڕاستەوخۆ (لەیڤ) چاودێری بکەیت.',
        ),
        _FaqItem(
          question: 'ئایا دەتوانم کاتی گەیاندن بۆ ڕۆژێکی دیاریکراو دابنێم؟',
          answer:
              'بەڵێ، لە کاتی کڕیندا دەتوانیت ڕۆژ و کاتی گەیاندن هەڵبژێریت بۆ ئەوەی دیارییەکەت لە کاتی گونجاودا بگات.',
        ),
        _FaqItem(
          question: 'ئایا دەتوانم نامەیەک یان تێبینییەک لەگەڵ گوڵەکەدا بنێرم؟',
          answer:
              'بێگومان! دەتوانیت پێش پارەدان نامەیەکی تایبەت بنووسیت کە بە شێوەیەکی زۆر جوان چاپ دەکرێت و لەگەڵ گوڵەکەدا دەگەیەنرێت.',
        ),
        _FaqItem(
          question: 'چی ڕوودەدات ئەگەر کەسی وەرگر لە ماڵ نەبێت؟',
          answer:
              'تیمی گەیاندنی ئێمە پەیوەندی بە وەرگرەکەوە دەکات بۆ ئەوەی لە شوێنێکی پارێزراو دایبنێت یان کاتێکی تر ڕێکبخات بۆ گەیاندن.',
        ),
        _FaqItem(
          question: 'ئایا گوڵەکان ڕێک وەک وێنەکانن؟',
          answer:
              'ئێمە لەگەڵ باشترین گوڵفرۆشەکان کاردەکەین بۆ ئەوەی ڕێک وەک دیزاینەکە دەربچێت. لەوانەیە گۆڕانکارییەکی زۆر بچووک هەبێت بەپێی وەرزەکان، بەڵام جوانی و بەهای گوڵەکە وەک خۆی دەمێنێتەوە.',
        ),
      ];
    case 'ar':
      return const [
        _FaqItem(
          question: 'كيف يمكنني تتبع طلبي؟',
          answer:
              'بمجرد خروج طلبك للتوصيل، يمكنك تتبع حالته مباشرة عبر قسم "طلباتي" في التطبيق.',
        ),
        _FaqItem(
          question: 'هل يمكنني جدولة التوصيل لتاريخ معين؟',
          answer:
              'نعم، أثناء إتمام الطلب، يمكنك اختيار تاريخ ووقت التوصيل المفضل لضمان وصول هديتك في الوقت المثالي.',
        ),
        _FaqItem(
          question: 'هل يمكنني إضافة رسالة خاصة مع الباقة؟',
          answer:
              'بالتأكيد! يمكنك إضافة رسالة مخصصة ستُطبع بأناقة وتُرفق مع طلبك قبل إتمام الدفع.',
        ),
        _FaqItem(
          question: 'ماذا يحدث إذا لم يكن المستلم في المنزل؟',
          answer:
              'سيقوم فريق التوصيل الخاص بنا بالتواصل مع المستلم للاتفاق على مكان آمن لترك الهدية أو تحديد موعد بديل للتوصيل.',
        ),
        _FaqItem(
          question: 'هل الزهور مطابقة تماماً للصور؟',
          answer:
              'نحن نتعاون مع نخبة من بائعي الزهور لضمان تطابق التصاميم. قد تحدث اختلافات بسيطة جداً حسب توفر الزهور في الموسم، لكن الجمالية والقيمة ستبقى دائماً بأعلى مستوى.',
        ),
      ];
    case 'en':
    default:
      return const [
        _FaqItem(
          question: 'How do I track my flower delivery?',
          answer:
              'Once your order is dispatched, you can track its status in real-time through the \'My Orders\' section in the app.',
        ),
        _FaqItem(
          question: 'Can I schedule a delivery for a future date?',
          answer:
              'Yes, during checkout, you can select your preferred delivery date and time slot to ensure your flowers arrive perfectly on time.',
        ),
        _FaqItem(
          question: 'Can I add a personalized message to my bouquet?',
          answer:
              'Absolutely! You can add a custom, beautifully printed message card to any order before checkout.',
        ),
        _FaqItem(
          question: 'What happens if the recipient is not at home?',
          answer:
              'Our delivery team will contact the recipient to arrange a safe drop-off or reschedule the delivery at a convenient time.',
        ),
        _FaqItem(
          question: 'Are the flowers exactly as shown in the pictures?',
          answer:
              'We work with premium florists who strive to replicate the designs exactly. Minor variations may occur based on seasonal availability, but the overall value and aesthetic will always be maintained.',
        ),
      ];
  }
}

