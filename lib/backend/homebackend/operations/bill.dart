import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';

class BillPrinter {
  static Future<String?> printA5Bill({
    required Map<String, dynamic> customer,
    required List<Map<String, dynamic>> items,
    required String invoiceId,
    required String date,
    required String paymentMode,
    required double previousBalance,
    required double totalAmount,
  }) async {
    final pdf = pw.Document();

    // Calculate Totals
    int totalThan = items.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['than']?.toString() ?? '0') ?? 0),
    );
    double totalTMtr = items.fold(0.0, (sum, item) {
      double m = double.tryParse(item['meter']?.toString() ?? '0.0') ?? 0.0;
      int t = int.tryParse(item['than']?.toString() ?? '0') ?? 0;
      return sum + (m * t); 
    });

    double grandTotal = totalAmount;
    double finalBalance = previousBalance + grandTotal;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1.5, color: PdfColors.black),
            ),
            child: pw.Column(
              children: [
                // 1. Header
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Khawaja Mozzam Trader',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Container(
                        color: PdfColors.black,
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 2,
                        ),
                        child: pw.Text(
                          'Sale Bill',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Divider(thickness: 1, color: PdfColors.black, height: 0),

                // 2. Vno & Date
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Vno: INV-$invoiceId',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      pw.Text(
                        'Date: $date',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Divider(thickness: 1, color: PdfColors.black, height: 0),

                // 3. Party Inv & Customer
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Party Inv: $invoiceId',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      pw.Text(
                        customer['name']?.toString().toLowerCase() ?? 'walk-in',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Divider(thickness: 1, color: PdfColors.black, height: 0),

                // 4. Data Table
                pw.Expanded(
                  child: pw.Table(
                    border: const pw.TableBorder(
                      verticalInside: pw.BorderSide(
                        width: 0.5,
                        color: PdfColors.black,
                      ),
                      bottom: pw.BorderSide(width: 1, color: PdfColors.black),
                    ),
                    children: [
                      // Table Headers
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(
                              width: 1,
                              color: PdfColors.black,
                            ),
                          ),
                        ),
                        children: [
                          _cell('Sr.No', isHeader: true, width: 30),
                          _cell('Description', isHeader: true),
                          _cell('Tan', isHeader: true, width: 40),
                          _cell('Mtr', isHeader: true, width: 40),
                          _cell('T.Mtr', isHeader: true, width: 50),
                          _cell('Rate', isHeader: true, width: 50),
                          _cell('Amount', isHeader: true, width: 60),
                        ],
                      ),
                      // Table Body Content
                      ...items.asMap().entries.map((entry) {
                        int idx = entry.key + 1;
                        var item = entry.value;
                        double m =
                            double.tryParse(
                              item['meter']?.toString() ?? '0.0',
                            ) ??
                            0.0;
                        int t =
                            int.tryParse(item['than']?.toString() ?? '0') ?? 0;
                        double tm = m * t;

                        return pw.TableRow(
                          children: [
                            _cell('$idx', align: pw.TextAlign.center),
                            _cell(
                              item['name']?.toString() ?? '',
                              align: pw.TextAlign.center,
                            ),
                            _cell('$t', align: pw.TextAlign.center),
                            _cell(
                              m.toStringAsFixed(1),
                              align: pw.TextAlign.center,
                            ),
                            _cell(
                              tm.toStringAsFixed(2),
                              align: pw.TextAlign.center,
                            ),
                            _cell(
                              double.tryParse(
                                    item['per_meter_amount']?.toString() ?? '0',
                                  )?.toStringAsFixed(2) ??
                                  '0.00',
                              align: pw.TextAlign.center,
                            ),
                            _cell(
                              double.tryParse(
                                    item['total_amount']?.toString() ?? '0',
                                  )?.toStringAsFixed(0) ??
                                  '0',
                              align: pw.TextAlign.right,
                            ),
                          ],
                        );
                      }).toList(),

                      // Empty rows to fill space (matching image's grid look)
                      ...List.generate(
                        math.max(0, 10 - items.length),
                        (index) => pw.TableRow(
                          children: [
                            _cell(''),
                            _cell(''),
                            _cell(''),
                            _cell(''),
                            _cell(''),
                            _cell(''),
                            _cell(''),
                          ],
                        ),
                      ),

                      // Summary row inside table
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            top: pw.BorderSide(
                              width: 1,
                              color: PdfColors.black,
                            ),
                          ),
                        ),
                        children: [
                          _cell('${items.length}', isHeader: true),
                          _cell('Total', isHeader: true),
                          _cell('$totalThan', isHeader: true),
                          _cell(''),
                          _cell(totalTMtr.toStringAsFixed(2), isHeader: true),
                          _cell(''),
                          _cell(
                            totalAmount.toStringAsFixed(0),
                            isHeader: true,
                            align: pw.TextAlign.right,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 5. Footer Boxes
                pw.Padding(
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.Column(
                    children: [
                      _footerBox(
                        'Pre. Balance',
                        '${previousBalance >= 0 ? '+' : ''}${previousBalance.toStringAsFixed(0)}',
                      ),
                      pw.SizedBox(height: 5),
                      _footerBox('Bill Amt', grandTotal.toStringAsFixed(0)),
                      pw.SizedBox(height: 5),
                      _footerBox(
                        'Balance Amt',
                        finalBalance.toStringAsFixed(0),
                        isBold: true,
                        width: 180,
                      ),

                      pw.SizedBox(height: 15),
                      pw.Center(
                        child: pw.Text(
                          'iansar.codes',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Save to temp and open instantly
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/Invoice_$invoiceId.pdf");
    await file.writeAsBytes(await pdf.save());

    // Auto open the file
    await OpenFilex.open(file.path);
    return file.path;
  }

  static pw.Widget _cell(
    String text, {
    bool isHeader = false,
    double? width,
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.SizedBox(
        width: width,
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );
  }

  static pw.Widget _footerBox(
    String label,
    String value, {
    bool isBold = false,
    double? width,
  }) {
    return pw.Container(
      width: width ?? 350,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 1, color: PdfColors.black),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: 10,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
