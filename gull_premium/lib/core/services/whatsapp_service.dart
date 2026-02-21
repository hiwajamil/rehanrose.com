import 'package:url_launcher/url_launcher.dart';

import '../utils/price_format_utils.dart';
import '../../data/models/add_on_model.dart';

/// Hardcoded Super Admin WhatsApp number (no '00' or '+').
const String kWhatsAppOrderNumber = '9647709818181';

/// Placeholder number for WhatsApp ordering (replace with real number when ready).
const String kWhatsAppOrderPlaceholderNumber = '9647700000000';

/// Greeting lines for the pre-filled order message (Kurdish + Arabic).
const String kWhatsAppOrderGreetingKurdish =
    'سڵاو بەڕێزم، دەمەوێت ئەم گوڵە داوا بکەم';
const String kWhatsAppOrderGreetingArabic =
    'مرحباً عزيزي، أريد طلب هذه الزهور.';

/// Opens WhatsApp with a pre-filled order message.
/// [selectedAddOns] appear as "Add-on: [Name] - [Price]".
/// [totalPriceIqd] is flower + add-ons when provided.
/// [productUrl] optional link to product page (e.g. https://rehanrose.com/flower/123).
/// [voiceMessageUrl] optional URL of the recorded voice message (for vendor to print QR).
/// [freeDeliveryUnlocked] when true, adds "Delivery: FREE" to the message.
Future<bool> launchOrderWhatsApp({
  required String flowerName,
  required String flowerPrice,
  required String flowerId,
  required String flowerImageUrl,
  String? bouquetCode,
  List<AddOnModel>? selectedAddOns,
  int? totalPriceIqd,
  String? productUrl,
  String? voiceMessageUrl,
  bool freeDeliveryUnlocked = false,
}) async {
  final lines = <String>[
    'Hello, I would like to order:',
    '',
    'Flower: $flowerName - $flowerPrice',
    if (bouquetCode != null && bouquetCode.isNotEmpty) 'Bouquet Code: $bouquetCode',
    if (selectedAddOns != null && selectedAddOns.isNotEmpty) ...[
      for (final a in selectedAddOns) 'Add-on: ${a.nameEn} - ${iqdPriceString(a.priceIqd)}',
    ],
    if (totalPriceIqd != null) 'Total Price: ${iqdPriceString(totalPriceIqd)}',
    if (freeDeliveryUnlocked) 'Delivery: FREE',
    if (voiceMessageUrl != null && voiceMessageUrl.isNotEmpty)
      'Voice Message (QR): $voiceMessageUrl',
    if (productUrl != null && productUrl.isNotEmpty) 'Link: $productUrl',
  ];
  final body = lines.join('\n');

  // WhatsApp API: https://wa.me/<number>?text=<encoded>
  final uri = Uri.parse(
    'https://wa.me/$kWhatsAppOrderNumber?text=${Uri.encodeComponent(body)}',
  );

  if (await canLaunchUrl(uri)) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}

/// Greeting line for the WhatsApp order message.
/// [languageCode] must be one of: 'en', 'ku', 'ar'.
String _whatsAppOrderGreeting(String languageCode) {
  switch (languageCode) {
    case 'ku':
      return 'سڵاو رێحان ڕۆز، دەمەوێت ئەم بڕگەیە داوا بکەم';
    case 'ar':
      return 'مرحباً ريهان روز، أود طلب هذا المنتج';
    default:
      return 'Hello Rehan Rose, I would like to order this item:';
  }
}

/// Opens WhatsApp with a simple pre-filled order message (name, code, price, link).
/// Works on Android/iOS (opens WhatsApp app) and Web (opens in new tab).
/// [languageCode] affects the greeting sentence (en/ku/ar).
/// [productUrl] optional link to the bouquet product page.
Future<bool> launchWhatsAppOrder({
  required String name,
  required String code,
  required String price,
  String? imageUrl,
  String? productUrl,
  String languageCode = 'en',
}) async {
  final greeting = _whatsAppOrderGreeting(languageCode);
  final lines = <String>[
    greeting,
    '',
    '🌹 Name: $name',
    '🆔 Code: $code',
    '💰 Price: $price',
    if (productUrl != null && productUrl.isNotEmpty) 'Link: $productUrl',
  ];
  final body = lines.join('\n');

  final uri = Uri.parse(
    'https://wa.me/$kWhatsAppOrderNumber?text=${Uri.encodeComponent(body)}',
  );

  if (await canLaunchUrl(uri)) {
    return launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  }
  return false;
}
