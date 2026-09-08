import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/cart_item.dart';
import '../models/shop.dart';

class PdfService {
  /// Generates PDF bytes for an invoice (non-blocking, no print dialog)
  static Future<Uint8List> generatePdfBytes({
    required Shop shop,
    required List<CartItem> cart,
    required double totalAmount,
    required String paymentMethod,
    String? customerName,
    String? invoiceNumber,
    required DateTime date,
  }) async {
    final pdf = pw.Document();
    const currency = 'DZD';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          // Shop Header
          pw.Center(
            child: pw.Text(
              shop.name.isNotEmpty ? shop.name : 'MY SHOP',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          if (shop.addressLine1.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text(shop.addressLine1,
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700))),
          ],
          if (shop.phoneNumber.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Center(child: pw.Text(shop.phoneNumber,
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700))),
          ],
          if (shop.nif.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Center(child: pw.Text('NIF: ${shop.nif}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))),
          ],
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.SizedBox(height: 8),

          // Invoice Info
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (invoiceNumber != null)
                    pw.Text('Invoice: $invoiceNumber', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Date: ${date.day}/${date.month}/${date.year}',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Payment: ${paymentMethod.toUpperCase()}',
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              if (customerName != null)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Customer:', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(customerName,
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 16),

          // Items Table
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            headerAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            headers: ['Item', 'Qty', 'Price', 'Total'],
            data: cart.map((item) => [
              item.product.name,
              '${item.quantity}',
              '${item.product.price.toStringAsFixed(0)} $currency',
              '${item.subtotal.toStringAsFixed(0)} $currency',
            ]).toList(),
          ),

          pw.SizedBox(height: 16),
          pw.Divider(),

          // Total
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    child: pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(width: 12),
                        pw.Text('${totalAmount.toStringAsFixed(0)} $currency',
                            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 32),

          if (shop.footerText.isNotEmpty) ...[
            pw.Center(
              child: pw.Text(shop.footerText,
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
            ),
          ],
          pw.SizedBox(height: 16),
          pw.Center(
            child: pw.Text('Generated by Algerian Billing App',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
          ),
        ],
      ),
    );

    return pdf.save();
  }
}
