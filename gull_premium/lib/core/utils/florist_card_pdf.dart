import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr/qr.dart';

import '../../data/models/order_model.dart';

/// Gift / occasion text for the physical tag (no price). Prefer add-ons; fall back to bouquet line.
String giftMessageOccasionNote(OmsOrderModel order) {
  final addons = order.addons.trim();
  final details = (order.bouquetDetails ?? '').trim();
  if (addons.isNotEmpty && details.isNotEmpty && addons != details) {
    return '$addons\n\n$details';
  }
  if (addons.isNotEmpty) return addons;
  if (details.isNotEmpty) return details;
  return '—';
}

/// Delivery / ready-by time for the vendor tag.
String deliveryDateTimeForTag(OmsOrderModel order) {
  final createdAtStr = order.createdAt != null
      ? '${order.createdAt!.day}/${order.createdAt!.month}/${order.createdAt!.year} '
          '${order.createdAt!.hour.toString().padLeft(2, '0')}:'
          '${order.createdAt!.minute.toString().padLeft(2, '0')}'
      : '—';
  if (order.orderDate != null && order.orderDate!.trim().isNotEmpty) {
    return order.orderDate!.trim();
  }
  return createdAtStr;
}

/// Vendor-facing PDF document for a bouquet tag (no price; recipient-safe).
Future<pw.Document> buildVendorOrderCardDocument(OmsOrderModel order) async {
  final pdf = pw.Document();
  final hasVoiceLink = order.voiceMessageLink != null &&
      order.voiceMessageLink!.trim().isNotEmpty;

  pw.Widget? qrWidget;
  if (hasVoiceLink) {
    try {
      final qrCode = QrCode.fromData(
        data: order.voiceMessageLink!,
        errorCorrectLevel: QrErrorCorrectLevel.L,
      );
      final qrImage = QrImage(qrCode);
      const qrSize = 72.0;
      qrWidget = pw.SizedBox(
        width: qrSize,
        height: qrSize,
        child: pw.Table(
          children: List.generate(
            qrImage.moduleCount,
            (r) => pw.TableRow(
              children: List.generate(
                qrImage.moduleCount,
                (c) => pw.Container(
                  color: qrImage.isDark(r, c) ? PdfColors.black : PdfColors.white,
                ),
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      qrWidget = null;
    }
  }

  final orderCode =
      order.bouquetCode.trim().isNotEmpty ? '#${order.bouquetCode.trim()}' : order.orderId;
  final productName = order.bouquetName?.trim().isNotEmpty == true
      ? order.bouquetName!.trim()
      : 'Bouquet';
  const quantity = 1;
  final giftNote = giftMessageOccasionNote(order);
  final whenStr = deliveryDateTimeForTag(order);

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a6,
      margin: const pw.EdgeInsets.all(20),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Rehan Rose — Order Card',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    orderCode,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 13,
                      color: PdfColors.grey800,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            _pdfRow('Product', '$productName  ·  ×$quantity'),
            pw.SizedBox(height: 10),
            pw.Text(
              'Gift message / Occasion note',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey700,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Text(
                giftNote,
                style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.3),
              ),
            ),
            pw.SizedBox(height: 12),
            _pdfRow('Delivery date & time', whenStr),
            if (qrWidget != null) ...[
              pw.Spacer(),
              pw.Center(
                child: pw.Column(
                  children: [
                    qrWidget,
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Voice message',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    ),
  );

  return pdf;
}

pw.Widget _pdfRow(String label, String value) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 9,
          color: PdfColors.grey700,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
      pw.SizedBox(height: 3),
      pw.Text(
        value,
        style: const pw.TextStyle(fontSize: 11),
      ),
    ],
  );
}

/// Opens the system print dialog with the vendor order card PDF.
Future<void> printOrderCard(OmsOrderModel order) async {
  final pdf = await buildVendorOrderCardDocument(order);
  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => pdf.save(),
    name: 'Rehan_Rose_Order_${order.orderId}.pdf',
  );
}
