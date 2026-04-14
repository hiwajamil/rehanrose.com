import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/order_model.dart';

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
  final voiceLink = order.sanitizedVoiceMessageLink;
  final hasVoiceLink = order.hasVoiceMessageLink;

  final orderCode =
      order.bouquetCode.trim().isNotEmpty ? '#${order.bouquetCode.trim()}' : order.orderId;
  final whenStr = deliveryDateTimeForTag(order);

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a6,
      margin: const pw.EdgeInsets.all(20),
      build: (pw.Context context) {
        return pw.Center(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                orderCode,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'Delivery date & time',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                whenStr,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 12),
              ),
              if (hasVoiceLink)
                ...[
                  pw.SizedBox(height: 16),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.BarcodeWidget(
                      data: voiceLink!,
                      barcode: pw.Barcode.qrCode(),
                      width: 160,
                      height: 160,
                      drawText: false,
                    ),
                  ),
                ],
            ],
          ),
        );
      },
    ),
  );

  return pdf;
}

/// Opens the system print dialog with the vendor order card PDF.
Future<void> printOrderCard(OmsOrderModel order) async {
  final pdf = await buildVendorOrderCardDocument(order);
  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => pdf.save(),
    name: 'Rehan_Rose_Order_${order.orderId}.pdf',
  );
}
