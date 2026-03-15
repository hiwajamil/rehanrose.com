import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr/qr.dart';

import '../../data/models/order_model.dart';
import 'price_format_utils.dart';

/// Builds a printable PDF of the Florist Order Card (order details + optional QR code).
Future<Uint8List> buildFloristCardPdf(OmsOrderModel order) async {
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
      const qrSize = 100.0;
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

  final createdAtStr = order.createdAt != null
      ? '${order.createdAt!.day}/${order.createdAt!.month}/${order.createdAt!.year} ${order.createdAt!.hour.toString().padLeft(2, '0')}:${order.createdAt!.minute.toString().padLeft(2, '0')}'
      : '—';
  final orderDateStr = (order.orderDate != null && order.orderDate!.isNotEmpty)
      ? order.orderDate!
      : createdAtStr;
  final totalStr = 'IQD ${formatPriceIqd(order.totalPrice.toInt())}';

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(24),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                'Rehan Rose',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                'Order Card',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            _pdfRow('Order', order.orderId),
            _pdfRow('Date & Time', orderDateStr),
            _pdfRow('Customer', order.customerPhone),
            _pdfRow('Bouquet', order.bouquetName ?? '—'),
            _pdfRow('Code', order.bouquetCode),
            if (order.bouquetDetails != null && order.bouquetDetails!.isNotEmpty)
              _pdfRow('Details', order.bouquetDetails!),
            _pdfRow('Total', totalStr),
            if (order.addons.isNotEmpty) _pdfRow('Add-ons', order.addons),
            if (order.deliveryLocationLink != null &&
                order.deliveryLocationLink!.isNotEmpty)
              _pdfRow('Delivery', order.deliveryLocationLink!),
            if (qrWidget != null) ...[
              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Column(
                  children: [
                    qrWidget,
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Scan for voice message',
                      style: pw.TextStyle(
                        fontSize: 10,
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

  return pdf.save();
}

pw.Widget _pdfRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 90,
          child: pw.Text(
            '$label:',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 10),
            maxLines: 3,
            overflow: pw.TextOverflow.clip,
          ),
        ),
      ],
    ),
  );
}

/// Opens the print dialog with the Florist Card PDF.
Future<void> printFloristCard(OmsOrderModel order) async {
  final pdfBytes = await buildFloristCardPdf(order);
  await Printing.layoutPdf(
    onLayout: (_) async => pdfBytes,
    name: 'Order_${order.orderId}.pdf',
  );
}
