import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';

class ReceiptGenerator {
  static Future<void> printReceipt({
    required List<CartItem> cart,
    required String customerName,
    required double subtotal,
    required double itemDiscounts,
    required double orderDiscount,
    required double redeemedPointsDiscount,
    required double tip,
    required double total,
    required String paymentMethod,
    required Map<String, double> splits,
    required String currencySymbol,
    required String salonName,
    required String address,
    required String footerMessage,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Standard 80mm thermal receipt
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  salonName.isEmpty ? 'STYLES POS' : salonName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  address.isEmpty ? 'Hair & Beauty Salon' : address,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 5),
              pw.Text(
                'Date: ${DateTime.now().toString().substring(0, 16)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'Customer: $customerName',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 5),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 5),
              // Itemized list
              ...cart.map((item) {
                final basePrice = item.service.price;
                final discount = item.isPercentDiscount
                    ? basePrice * (item.discount / 100)
                    : item.discount;
                final finalPrice = basePrice - discount;

                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            item.service.name,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Text(
                          '$currencySymbol${finalPrice.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      'Staff: ${item.assignedStaff}',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                    if (discount > 0)
                      pw.Text(
                        'Discount applied: $currencySymbol${discount.toStringAsFixed(2)}',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
                    pw.SizedBox(height: 4),
                  ],
                );
              }),
              pw.SizedBox(height: 5),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 5),
              // Totals
              _buildRow(
                'Subtotal (inc Staff Tips)',
                '$currencySymbol${subtotal.toStringAsFixed(2)}',
              ),
              if (itemDiscounts > 0)
                _buildRow(
                  'Item Discounts',
                  '-$currencySymbol${itemDiscounts.toStringAsFixed(2)}',
                ),
              if (orderDiscount > 0)
                _buildRow(
                  'Order Discount',
                  '-$currencySymbol${orderDiscount.toStringAsFixed(2)}',
                ),
              if (redeemedPointsDiscount > 0)
                _buildRow(
                  'Points Redemption',
                  '-$currencySymbol${redeemedPointsDiscount.toStringAsFixed(2)}',
                ),
              if (tip > 0) _buildRow('Tip', '+$currencySymbol${tip.toStringAsFixed(2)}'),
              pw.SizedBox(height: 5),
              pw.Divider(borderStyle: pw.BorderStyle.solid),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '$currencySymbol${total.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Payment Method: $paymentMethod',
                style: const pw.TextStyle(fontSize: 10),
              ),
              if (paymentMethod == 'Split' && splits.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                ...splits.entries.map(
                  (e) => pw.Text(
                    '- ${e.key}: $currencySymbol${e.value.toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ],
              pw.SizedBox(height: 15),
              pw.Center(
                child: pw.Text(
                  footerMessage.isEmpty ? 'Thank you for your visit!' : footerMessage,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Receipt_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  static pw.Widget _buildRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}
