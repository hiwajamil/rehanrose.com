/// Parses structured WhatsApp order messages into separate fields.
/// Format expected:
/// Date & Time: 2026-03-09 14:30
/// Customer Phone: +964...
/// Flower: Bouquet - IQD 35,000
/// Bouquet Code: AN-2
/// Total Price: IQD 35,000
/// Voice Message (QR): https://...
/// Link: https://...
/// Delivery Location: http://...
class WhatsAppOrderExtract {
  final String customerPhone;
  final String orderDate;
  final String bouquetDetails;
  final String bouquetCode;
  final String totalPriceRaw;
  final String voiceMessageLink;
  final String deliveryLocationLink;

  const WhatsAppOrderExtract({
    this.customerPhone = '',
    this.orderDate = '',
    this.bouquetDetails = '',
    this.bouquetCode = '',
    this.totalPriceRaw = '',
    this.voiceMessageLink = '',
    this.deliveryLocationLink = '',
  });
}

/// Extracts order fields from a pasted WhatsApp message using line prefixes.
WhatsAppOrderExtract parseWhatsAppOrderMessage(String raw) {
  if (raw.trim().isEmpty) return const WhatsAppOrderExtract();

  final lines = raw.replaceAll('\r\n', '\n').split('\n');
  String customerPhone = '';
  String orderDate = '';
  String bouquetDetails = '';
  String bouquetCode = '';
  String totalPriceRaw = '';
  String voiceMessageLink = '';
  String deliveryLocationLink = '';
  String linkLine = ''; // "Link:" line - use if voice or delivery missing

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final dateMatch = _stripPrefix(trimmed, 'Date & Time:', orderDate);
    if (dateMatch.$1) {
      orderDate = dateMatch.$2;
      continue;
    }
    final phoneMatch = _stripPrefix(trimmed, 'Customer Phone:', customerPhone);
    if (phoneMatch.$1) {
      customerPhone = phoneMatch.$2;
      continue;
    }
    final flowerMatch = _stripPrefix(trimmed, 'Flower:', bouquetDetails);
    if (flowerMatch.$1) {
      bouquetDetails = flowerMatch.$2;
    } else {
      final codeMatch = _stripPrefix(trimmed, 'Bouquet Code:', bouquetCode);
      if (codeMatch.$1) {
        bouquetCode = codeMatch.$2;
      } else {
        final priceMatch = _stripPrefix(trimmed, 'Total Price:', totalPriceRaw);
        if (priceMatch.$1) {
          totalPriceRaw = priceMatch.$2;
        } else {
          final voiceMatch = _stripPrefix(trimmed, 'Voice Message (QR):', voiceMessageLink);
          if (voiceMatch.$1) {
            voiceMessageLink = voiceMatch.$2;
          } else {
            final linkMatch = _stripPrefix(trimmed, 'Link:', linkLine);
            if (linkMatch.$1) {
              linkLine = linkMatch.$2;
            } else {
              final locMatch = _stripPrefix(trimmed, 'Delivery Location:', deliveryLocationLink);
              if (locMatch.$1) {
                deliveryLocationLink = locMatch.$2;
              }
            }
          }
        }
      }
    }
  }

  // If "Link:" was provided but Voice or Delivery wasn't, use it
  if (linkLine.isNotEmpty) {
    if (voiceMessageLink.isEmpty) {
      voiceMessageLink = linkLine;
    } else if (deliveryLocationLink.isEmpty) {
      deliveryLocationLink = linkLine;
    }
  }

  return WhatsAppOrderExtract(
    customerPhone: customerPhone.trim(),
    orderDate: orderDate.trim(),
    bouquetDetails: bouquetDetails.trim(),
    bouquetCode: bouquetCode.trim(),
    totalPriceRaw: totalPriceRaw.trim(),
    voiceMessageLink: voiceMessageLink.trim(),
    deliveryLocationLink: deliveryLocationLink.trim(),
  );
}

(bool, String) _stripPrefix(String line, String prefix, String current) {
  final lower = line.toLowerCase();
  final prefixLower = prefix.toLowerCase();
  if (!lower.startsWith(prefixLower)) return (false, current);
  final value = line.substring(prefix.length).trim();
  return (true, value);
}

/// Parses "IQD 35,000" or "35000" to a number. Returns 0 if invalid.
num parseTotalPriceFromRaw(String totalPriceRaw) {
  if (totalPriceRaw.isEmpty) return 0;
  // Remove currency text and commas, then parse
  final digits = totalPriceRaw.replaceAll(RegExp(r'[^\d.]'), '');
  return num.tryParse(digits) ?? 0;
}
