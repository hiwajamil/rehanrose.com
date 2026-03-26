import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../utils/price_format_utils.dart';

/// Generates a vendor Thermal-Receipt PDF and sends it to the printer.
class ReceiptPrinterService {
  /// Prints a receipt for a vendor given a denormalized [orderData] map.
  ///
  /// Expected keys (best-effort; missing keys are handled gracefully):
  /// - `orderId` (String)
  /// - `vendorName` (String)
  /// - `dateTime` or `orderDate` (String)
  /// - `customerPhone` (String)
  /// - `bouquetName`/`bouquetDetails` (String)
  /// - `bouquetCode` (String)
  /// - `addons` (String - free-form; may include IQD prices)
  /// - `totalPrice` (num/int/String)
  static Future<void> printReceipt(Map<String, dynamic> orderData) async {
    final orderId = _asString(orderData['orderId'] ?? orderData['id']);
    final vendorName = _asString(orderData['vendorName']);
    final dateTimeStr = _asString(orderData['dateTime'] ?? orderData['orderDate']);
    final customerPhone = _asString(orderData['customerPhone']);

    final bouquetName = _asString(orderData['bouquetName']);
    final bouquetDetails = _asString(orderData['bouquetDetails']);
    final bouquetCode = _asString(orderData['bouquetCode']);

    final addonsRaw = _asString(orderData['addons']);
    final totalPrice = _toInt(orderData['totalPrice']);

    final itemLabel = _asString(orderData['itemLabel']) //
        .trim()
        .isNotEmpty
        ? _asString(orderData['itemLabel'])
        : (bouquetName.isNotEmpty || bouquetDetails.isNotEmpty) ? 'Bouquet' : 'Order Item';

    final receiptItemName = bouquetName.isNotEmpty ? bouquetName : _stripPriceFromText(bouquetDetails);
    final receiptItemPrice = _extractIqdPrice(bouquetDetails);

    // QR at the very bottom (verification link fallback to orderId).
    final qrUrl = orderId.isNotEmpty ? 'https://rehanrose.com/order/$orderId' : orderId;

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Rehan Rose',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (vendorName.isNotEmpty) ...[
                      pw.SizedBox(height: 1),
                      pw.Text(
                        vendorName,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Receipt',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              _divider(),
              _kvRow('Order ID', orderId),
              if (dateTimeStr.isNotEmpty) _kvRow('Date & Time', dateTimeStr),
              if (customerPhone.isNotEmpty) _kvRow('Customer', customerPhone),
              _divider(),
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 2),
                child: pw.Text(
                  'Items',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              _itemPriceRow(
                name: receiptItemName.isNotEmpty ? receiptItemName : itemLabel,
                priceIqd: receiptItemPrice,
              ),
              if (addonsRaw.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(
                    'Add-ons',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                ..._buildAddonLines(addonsRaw).map(
                  (line) => _itemPriceRow(name: line.name, priceIqd: line.priceIqd),
                ),
              ],
              _divider(),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    totalPrice != null ? 'IQD ${formatPriceIqd(totalPrice)}' : '—',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              if (bouquetCode.isNotEmpty) _kvRow('Code', bouquetCode),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Thank you for choosing Rehan Rose.',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 6),
              // QR at the very bottom.
              if (qrUrl.isNotEmpty)
                pw.Center(
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrUrl,
                    width: 90,
                    height: 90,
                  ),
                ),
            ],
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: orderId.isNotEmpty ? 'Receipt_$orderId.pdf' : 'Receipt.pdf',
    );
  }

  static pw.Widget _divider() {
    return pw.Container(height: 1, margin: const pw.EdgeInsets.symmetric(vertical: 8), color: PdfColors.grey300);
  }

  static pw.Widget _kvRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.isEmpty ? '—' : value,
              style: pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _itemPriceRow({required String name, int? priceIqd}) {
    final priceStr = priceIqd != null ? 'IQD ${formatPriceIqd(priceIqd)}' : '—';
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              name,
              style: pw.TextStyle(fontSize: 10.5),
            ),
          ),
          pw.Text(
            priceStr,
            style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static List<_AddonLine> _buildAddonLines(String addonsRaw) {
    // Heuristic parsing: try splitting by comma/semicolon/newline.
    final rawLines = addonsRaw
        .split(RegExp(r'[,;\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (rawLines.isEmpty) return [];

    // If the raw data is a single line, try splitting by " - " as a second fallback.
    if (rawLines.length == 1 && rawLines.first.contains(' - ')) {
      final byDash = rawLines.first.split(' - ').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (byDash.length >= 2) {
        final first = byDash[0];
        final maybePriceText = byDash.sublist(1).join(' - ');
        final priceIqd = _extractIqdPrice(maybePriceText);
        return [(_AddonLine(name: first, priceIqd: priceIqd))];
      }
    }

    return rawLines
        .map((line) {
          final priceIqd = _extractIqdPrice(line);
          final name = _stripPriceFromText(line);
          return _AddonLine(name: name.isEmpty ? line : name, priceIqd: priceIqd);
        })
        .toList();
  }

  static int? _extractIqdPrice(String text) {
    if (text.isEmpty) return null;
    // Common formats:
    // - "IQD 35,000"
    // - "35,000 IQD"
    final m1 = RegExp(r'IQD\s*([\d,]+)', caseSensitive: false).firstMatch(text);
    if (m1 != null) return _parseIqdGroup(m1.group(1));

    final m2 = RegExp(r'([\d,]+)\s*IQD', caseSensitive: false).firstMatch(text);
    if (m2 != null) return _parseIqdGroup(m2.group(1));

    return null;
  }

  static int? _parseIqdGroup(String? group) {
    if (group == null) return null;
    final normalized = group.replaceAll(',', '').trim();
    if (normalized.isEmpty) return null;
    final value = int.tryParse(normalized);
    return value;
  }

  static String _stripPriceFromText(String text) {
    if (text.isEmpty) return text;
    final withoutIqdPrefix = text.replaceAll(RegExp(r'IQD\s*[\d,]+', caseSensitive: false), '').trim();
    if (withoutIqdPrefix.isNotEmpty) return withoutIqdPrefix;
    final withoutIqdSuffix = text.replaceAll(RegExp(r'[\d,]+\s*IQD', caseSensitive: false), '').trim();
    return withoutIqdSuffix;
  }

  static String _asString(dynamic v) {
    if (v == null) return '';
    return v.toString().trim();
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    // Allow "35,000" or "IQD 35,000"
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }
}

class _AddonLine {
  final String name;
  final int? priceIqd;

  const _AddonLine({required this.name, this.priceIqd});
}

