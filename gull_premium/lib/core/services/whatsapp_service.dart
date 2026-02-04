import 'package:url_launcher/url_launcher.dart';

/// Hardcoded Super Admin WhatsApp number (no '00' or '+').
const String kWhatsAppOrderNumber = '9647501149414';

/// Greeting lines for the pre-filled order message (Kurdish + Arabic).
const String kWhatsAppOrderGreetingKurdish =
    'سڵاو بەڕێزم، دەمەوێت ئەم گوڵە داوا بکەم';
const String kWhatsAppOrderGreetingArabic =
    'مرحباً عزيزي، أريد طلب هذه الزهور.';

/// Opens WhatsApp with a pre-filled order message.
/// Works on Android, iOS, and Web. Uses [Uri.encodeComponent] for the body.
Future<bool> launchOrderWhatsApp({
  required String flowerName,
  required String flowerPrice,
  required String flowerId,
  required String flowerImageUrl,
  String? bouquetCode,
}) async {
  final body = [
    kWhatsAppOrderGreetingKurdish,
    kWhatsAppOrderGreetingArabic,
    '',
    'Flower: $flowerName',
    'Price: $flowerPrice',
    if (bouquetCode != null && bouquetCode.isNotEmpty) 'Code: $bouquetCode',
    'Ref ID: $flowerId',
    'Image: $flowerImageUrl',
  ].join('\n');

  // WhatsApp API: https://wa.me/<number>?text=<encoded>
  final uri = Uri.parse(
    'https://wa.me/$kWhatsAppOrderNumber?text=${Uri.encodeComponent(body)}',
  );

  if (await canLaunchUrl(uri)) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}
