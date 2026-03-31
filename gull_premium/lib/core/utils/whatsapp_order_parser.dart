// Parses structured WhatsApp order messages into separate fields.
// Layouts match the WhatsApp bodies built in whatsapp_service.dart
// (greeting line, labeled rows, optional [Ref: <userId>]).

/// Parsed fields from a pasted WhatsApp order (bouquet or perfume).
class WhatsAppOrderExtract {
  final String customerPhone;
  final String orderDate;
  final String bouquetDetails;
  final String bouquetCode;
  final String totalPriceRaw;
  final String voiceMessageLink;
  final String deliveryLocationLink;
  final String userId;

  const WhatsAppOrderExtract({
    this.customerPhone = '',
    this.orderDate = '',
    this.bouquetDetails = '',
    this.bouquetCode = '',
    this.totalPriceRaw = '',
    this.voiceMessageLink = '',
    this.deliveryLocationLink = '',
    this.userId = '',
  });
}

/// First line (multiline) matching `Label: value` (case-insensitive label).
String? _labeledLine(String raw, String label) {
  final re = RegExp(
    '^\\s*${RegExp.escape(label)}\\s*:\\s*(.*)\$',
    caseSensitive: false,
    multiLine: true,
  );
  final m = re.firstMatch(raw);
  final v = m?.group(1)?.trim();
  if (v == null) return null;
  return v;
}

/// Strips leading `#` from product codes (e.g. `#PF-12` → `PF-12`).
String _normalizeProductCode(String code) {
  var c = code.trim();
  if (c.startsWith('#')) {
    c = c.substring(1).trim();
  }
  return c;
}

/// Normalizes captured Ref id (trim, strip zero-width / BOM).
String _normalizeRefToken(String raw) {
  var s = raw.trim();
  s = s.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
  return s.trim();
}

/// Extracts Firebase UID from `[Ref: …]` (ASCII or fullwidth brackets).
/// Matches messages built in [whatsapp_service.dart] and pasted from WhatsApp.
String extractRefUserIdFromWhatsAppPaste(String raw) {
  if (raw.trim().isEmpty) return '';
  final patterns = <RegExp>[
    RegExp(r'\[Ref:\s*([^\]]+)\]', caseSensitive: false),
    RegExp(r'［Ref:\s*([^］]+)］', caseSensitive: false),
  ];
  for (final re in patterns) {
    final m = re.firstMatch(raw);
    if (m == null) continue;
    final id = _normalizeRefToken(m.group(1) ?? '');
    if (id.isEmpty) continue;
    if (id.toLowerCase() == 'unknown') continue;
    return id;
  }
  return '';
}

/// `[Ref: uid]` may appear alone on a line or with trailing text.
String _extractUserId(String raw) => extractRefUserIdFromWhatsAppPaste(raw);

bool _isPlaceholderVoice(String v) {
  final t = v.trim().toLowerCase();
  return t.isEmpty || t == 'no' || t == 'none' || t == 'n/a';
}

bool _isPlaceholderDelivery(String v) {
  final t = v.trim().toLowerCase();
  return t.isEmpty || t == 'not provided' || t == 'none' || t == 'n/a';
}

/// `Item: Perfume - …` (value after the dash, no second colon).
String? _perfumeItemDetailLine(String raw) {
  final re = RegExp(
    r'^\s*Item:\s*Perfume\s*-\s*(.*)$',
    caseSensitive: false,
    multiLine: true,
  );
  final v = re.firstMatch(raw)?.group(1)?.trim();
  if (v == null || v.isEmpty) return null;
  return v;
}

String _normalizePastedText(String raw) {
  return raw
      .replaceAll('\r\n', '\n')
      .replaceFirst(RegExp(r'^\uFEFF'), '');
}

/// Uses a trailing `Link:` row when voice/delivery are missing (older templates).
(String voice, String delivery) _mergeLinkLine(
  String linkLine,
  String voiceMessageLink,
  String deliveryLocationLink,
) {
  if (linkLine.isEmpty) {
    return (voiceMessageLink, deliveryLocationLink);
  }
  final lower = linkLine.toLowerCase();
  final looksStorage = lower.contains('firebasestorage') ||
      (lower.contains('googleapis.com') && lower.contains('firebasestorage'));
  final looksMaps = lower.contains('google.com/maps') ||
      lower.contains('maps.google') ||
      lower.contains('googleusercontent.com');

  var voice = voiceMessageLink;
  var delivery = deliveryLocationLink;

  if (voice.isEmpty && looksStorage) {
    voice = linkLine;
  } else if (delivery.isEmpty && looksMaps) {
    delivery = linkLine;
  } else if (voice.isEmpty) {
    voice = linkLine;
  } else if (delivery.isEmpty) {
    delivery = linkLine;
  }
  return (voice, delivery);
}

/// Bouquet / flower WhatsApp body → fields.
WhatsAppOrderExtract parseWhatsAppOrderMessage(String raw) {
  if (raw.trim().isEmpty) return const WhatsAppOrderExtract();

  final normalized = _normalizePastedText(raw);

  String orderDate = _labeledLine(normalized, 'Date & Time') ?? '';
  String customerPhone = _labeledLine(normalized, 'Customer Phone') ?? '';

  String bouquetDetails = _labeledLine(normalized, 'Flower') ??
      _labeledLine(normalized, 'Perfume') ??
      '';

  String bouquetCode = _normalizeProductCode(
    _labeledLine(normalized, 'Bouquet Code') ??
        _labeledLine(normalized, 'Perfume Code') ??
        '',
  );

  String totalPriceRaw = _labeledLine(normalized, 'Total Price') ?? '';
  final discountedTotalLine = _labeledLine(normalized, 'Discounted Total');
  if (discountedTotalLine != null && discountedTotalLine.isNotEmpty) {
    totalPriceRaw = discountedTotalLine;
  } else {
    final finalDiscounted = _labeledLine(normalized, 'Final Discounted Price');
    if (finalDiscounted != null &&
        finalDiscounted.isNotEmpty &&
        totalPriceRaw.isEmpty) {
      totalPriceRaw = finalDiscounted;
    }
  }

  String voiceMessageLink = _labeledLine(normalized, 'Voice Message (QR)') ?? '';
  String deliveryLocationLink =
      _labeledLine(normalized, 'Delivery Location') ?? '';
  final linkLine = _labeledLine(normalized, 'Link') ?? '';
  final merged = _mergeLinkLine(linkLine, voiceMessageLink, deliveryLocationLink);
  voiceMessageLink = merged.$1;
  deliveryLocationLink = merged.$2;

  if (_isPlaceholderVoice(voiceMessageLink)) {
    voiceMessageLink = '';
  }
  if (_isPlaceholderDelivery(deliveryLocationLink)) {
    deliveryLocationLink = '';
  }

  final userId = _extractUserId(normalized);

  return WhatsAppOrderExtract(
    customerPhone: customerPhone.trim(),
    orderDate: orderDate.trim(),
    bouquetDetails: bouquetDetails.trim(),
    bouquetCode: bouquetCode.trim(),
    totalPriceRaw: totalPriceRaw.trim(),
    voiceMessageLink: voiceMessageLink.trim(),
    deliveryLocationLink: deliveryLocationLink.trim(),
    userId: userId,
  );
}

/// Perfume WhatsApp body → same [WhatsAppOrderExtract] shape (`bouquet*` fields reused).
WhatsAppOrderExtract parsePerfumeWhatsAppOrderMessage(String raw) {
  if (raw.trim().isEmpty) return const WhatsAppOrderExtract();

  final normalized = _normalizePastedText(raw);

  String orderDate = _labeledLine(normalized, 'Date & Time') ?? '';
  String customerPhone = _labeledLine(normalized, 'Customer Phone') ?? '';

  String perfumeDetails = '';
  final itemLine = _perfumeItemDetailLine(normalized);
  if (itemLine != null && itemLine.isNotEmpty) {
    perfumeDetails = 'Perfume - $itemLine';
  } else {
    final alt = _labeledLine(normalized, 'Perfume');
    if (alt != null && alt.isNotEmpty) {
      perfumeDetails = alt;
    }
  }

  String perfumeCode = _normalizeProductCode(
    _labeledLine(normalized, 'Perfume Code') ?? '',
  );

  String totalPriceRaw = _labeledLine(normalized, 'Total Price') ?? '';
  final perfumeDiscounted = _labeledLine(normalized, 'Discounted Total');
  if (perfumeDiscounted != null && perfumeDiscounted.isNotEmpty) {
    totalPriceRaw = perfumeDiscounted;
  }

  String voiceMessageLink = _labeledLine(normalized, 'Voice Message (QR)') ?? '';
  String deliveryLocationLink =
      _labeledLine(normalized, 'Delivery Location') ?? '';
  final linkLine = _labeledLine(normalized, 'Link') ?? '';
  final merged = _mergeLinkLine(linkLine, voiceMessageLink, deliveryLocationLink);
  voiceMessageLink = merged.$1;
  deliveryLocationLink = merged.$2;

  if (_isPlaceholderVoice(voiceMessageLink)) {
    voiceMessageLink = '';
  }
  if (_isPlaceholderDelivery(deliveryLocationLink)) {
    deliveryLocationLink = '';
  }

  final userId = _extractUserId(normalized);

  return WhatsAppOrderExtract(
    customerPhone: customerPhone.trim(),
    orderDate: orderDate.trim(),
    bouquetDetails: perfumeDetails.trim(),
    bouquetCode: perfumeCode.trim(),
    totalPriceRaw: totalPriceRaw.trim(),
    voiceMessageLink: voiceMessageLink.trim(),
    deliveryLocationLink: deliveryLocationLink.trim(),
    userId: userId,
  );
}

/// Parses "IQD 35,000" or "35000" to a number. Returns 0 if invalid.
num parseTotalPriceFromRaw(String totalPriceRaw) {
  if (totalPriceRaw.isEmpty) return 0;
  final digits = totalPriceRaw.replaceAll(RegExp(r'[^\d.]'), '');
  return num.tryParse(digits) ?? 0;
}
