import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/price_format_utils.dart';
import '../../data/models/add_on_model.dart';

/// Formats current date/time as "YYYY-MM-DD HH:mm" for WhatsApp order messages.
String _orderDateTimeString() {
  return DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
}

String _displayPerfumeCode(String? raw) {
  final t = raw?.trim() ?? '';
  if (t.isEmpty) return 'Not provided';
  if (t.startsWith('#')) return t;
  return '#$t';
}

/// Hardcoded Super Admin WhatsApp number (no '00' or '+').
const String kWhatsAppOrderNumber = '9647709818181';

Uri _whatsAppOrderUri(String body) {
  return Uri.https('wa.me', '/$kWhatsAppOrderNumber', <String, String>{
    'text': body,
  });
}

/// Placeholder number for WhatsApp ordering (replace with real number when ready).
const String kWhatsAppOrderPlaceholderNumber = '9647700000000';

/// Greeting lines for the pre-filled order message (Kurdish + Arabic).
const String kWhatsAppOrderGreetingKurdish =
    'سڵاو بەڕێزم، دەمەوێت ئەم گوڵە داوا بکەم';
const String kWhatsAppOrderGreetingArabic =
    'مرحباً عزيزي، أريد طلب هذه الزهور.';

/// Optional delivery location; when set, a Google Maps URL is appended to the message.
class DeliveryLatLng {
  const DeliveryLatLng(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
  String get googleMapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
}

/// Opens WhatsApp with a pre-filled order message.
/// [selectedAddOns] appear as "Add-on: [Name] - [Price]".
/// [totalPriceIqd] is flower + add-ons when provided.
/// [productUrl] optional link to product page (e.g. https://rehanrose.com/flower/123).
/// [voiceMessageUrl] optional URL of the recorded voice message (for vendor to print QR).
/// [freeDeliveryUnlocked] when true, adds "Delivery: FREE" to the message.
/// [deliveryLocation] when set, appends "Delivery Location: &lt;Google Maps URL&gt;" to the message.
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
  DeliveryLatLng? deliveryLocation,
  String? promoCode,
  double? promoDiscountPercentage,
  int? discountedTotalPriceIqd,
}) async {
  final dateTimeStr = _orderDateTimeString();
  final customerPhone =
      FirebaseAuth.instance.currentUser?.phoneNumber ?? 'Not provided';
  final lines = <String>[
    'Hello, I would like to order:',
    'Date & Time: $dateTimeStr',
    'Customer Phone: $customerPhone',
    '',
    'Flower: $flowerName - $flowerPrice',
    if (bouquetCode != null && bouquetCode.isNotEmpty) 'Bouquet Code: $bouquetCode',
    if (selectedAddOns != null && selectedAddOns.isNotEmpty) ...[
      for (final a in selectedAddOns) 'Add-on: ${a.nameEn} - ${iqdPriceString(a.priceIqd)}',
    ],
    if (promoCode != null &&
        promoCode.trim().isNotEmpty &&
        promoDiscountPercentage != null)
      'Promo Code Applied: ${promoCode.trim().toUpperCase()} (-${promoDiscountPercentage.toStringAsFixed(promoDiscountPercentage % 1 == 0 ? 0 : 1)}%)',
    if (totalPriceIqd != null) 'Total Price: ${iqdPriceString(totalPriceIqd)}',
    if (discountedTotalPriceIqd != null)
      'Final Discounted Price: ${iqdPriceString(discountedTotalPriceIqd)}',
    if (freeDeliveryUnlocked) 'Delivery: FREE',
    if (voiceMessageUrl != null && voiceMessageUrl.isNotEmpty)
      'Voice Message (QR): $voiceMessageUrl',
    if (productUrl != null && productUrl.isNotEmpty) 'Link: $productUrl',
    if (deliveryLocation != null)
      'Delivery Location: ${deliveryLocation.googleMapsUrl}',
  ];
  final body = lines.join('\n');

  final uri = _whatsAppOrderUri(body);

  if (await canLaunchUrl(uri)) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}

/// Opens WhatsApp with a perfume order message (aligned with bouquet [launchOrderWhatsApp] layout).
///
/// [perfumeCodeRaw] is typically [FlowerModel.bouquetCode] (e.g. PF-12 → displayed as #PF-12).
/// [addOnBouquetName] / [addOnBouquetPriceIqd]: include the add-on line only when a bouquet is selected.
Future<bool> launchPerfumeOrderWhatsApp({
  required String perfumeName,
  required String brand,
  required int perfumePriceIqd,
  required String perfumeCodeRaw,
  required int totalPriceIqd,
  String? addOnBouquetName,
  int? addOnBouquetPriceIqd,
  String? productUrl,
  String? voiceMessageUrl,
  DeliveryLatLng? deliveryLocation,
}) async {
  final dateTimeStr = _orderDateTimeString();
  final customerPhone =
      FirebaseAuth.instance.currentUser?.phoneNumber ?? 'Not provided';
  final voiceTrimmed = voiceMessageUrl?.trim() ?? '';
  final voiceLine = voiceTrimmed.isNotEmpty ? voiceTrimmed : 'No';
  final addOnNameTrimmed = addOnBouquetName?.trim() ?? '';
  final int? addOnIqd = addOnBouquetPriceIqd;

  final lines = <String>[
    'Hello, I would like to order:',
    'Date & Time: $dateTimeStr',
    'Customer Phone: $customerPhone',
    '',
    'Item: Perfume - $perfumeName by $brand (IQD ${formatPriceIqd(perfumePriceIqd)})',
    'Perfume Code: ${_displayPerfumeCode(perfumeCodeRaw)}',
    if (addOnNameTrimmed.isNotEmpty && addOnIqd != null)
      'Add-on Bouquet: $addOnNameTrimmed (IQD ${formatPriceIqd(addOnIqd)})',
    'Total Price: IQD ${formatPriceIqd(totalPriceIqd)}',
    'Voice Message (QR): $voiceLine',
    if (productUrl != null && productUrl.trim().isNotEmpty)
      'Link: ${productUrl.trim()}',
    'Delivery Location: ${deliveryLocation != null ? deliveryLocation.googleMapsUrl : 'Not provided'}',
  ];
  final body = lines.join('\n');

  final uri = _whatsAppOrderUri(body);

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

  final uri = _whatsAppOrderUri(body);

  if (await canLaunchUrl(uri)) {
    return launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  }
  return false;
}
