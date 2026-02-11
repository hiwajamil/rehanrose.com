import 'package:url_launcher/url_launcher.dart';

import '../utils/price_format_utils.dart';
import '../../data/models/add_on_model.dart';

/// Hardcoded Super Admin WhatsApp number (no '00' or '+').
const String kWhatsAppOrderNumber = '9647501149414';

/// Greeting lines for the pre-filled order message (Kurdish + Arabic).
const String kWhatsAppOrderGreetingKurdish =
    'سڵاو بەڕێزم، دەمەوێت ئەم گوڵە داوا بکەم';
const String kWhatsAppOrderGreetingArabic =
    'مرحباً عزيزي، أريد طلب هذه الزهور.';

/// Opens WhatsApp with a pre-filled order message.
/// [selectedAddOns] appear as "Add-on: [Name] - [Price]".
/// [totalPriceIqd] is flower + add-ons when provided.
/// [productUrl] optional link to product page (e.g. https://rehanrose.com/flower/123).
Future<bool> launchOrderWhatsApp({
  required String flowerName,
  required String flowerPrice,
  required String flowerId,
  required String flowerImageUrl,
  String? bouquetCode,
  List<AddOnModel>? selectedAddOns,
  int? totalPriceIqd,
  String? productUrl,
}) async {
  final lines = <String>[
    'Hello, I would like to order:',
    '',
    'Flower: $flowerName - $flowerPrice',
    if (selectedAddOns != null && selectedAddOns.isNotEmpty) ...[
      for (final a in selectedAddOns) 'Add-on: ${a.nameEn} - ${iqdPriceString(a.priceIqd)}',
    ],
    if (totalPriceIqd != null) 'Total Price: ${iqdPriceString(totalPriceIqd)}',
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
