import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:loom/backend/homebackend/operations/split_payment_db.dart';

class SplitLogScreen extends StatefulWidget {
  final String? filter; // 'cash' or 'credit' or null (all)
  const SplitLogScreen({super.key, this.filter});

  @override
  State<SplitLogScreen> createState() => _SplitLogScreenState();
}

class _SplitLogScreenState extends State<SplitLogScreen> {
  List<Map<String, dynamic>> _allRecords = [];
  List<Map<String, dynamic>> _filteredRecords = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  DateTime? _selectedDate;

  double _totalCash = 0;
  double _totalUdhaar = 0;
  double _totalJammah = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterData);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final rawRecords = await SplitPaymentDB.getInstance.getAllRecords();
    final records = rawRecords.reversed.toList();

    List<Map<String, dynamic>> filteredList = [];
    double cash = 0;
    double udhaar = 0;
    double jammah = 0;

    for (var r in records) {
      double rCash = (r[SplitPaymentDB.C_PAYMENT_CASH] as num?)?.toDouble() ?? 0;
      double rCredit = (r[SplitPaymentDB.C_PAYMENT_CREDIT] as num?)?.toDouble() ?? 0;

      bool keep = false;
      if (widget.filter == 'cash') {
        if (rCash != 0 || rCredit > 0) keep = true;
      } else if (widget.filter == 'credit') {
        if (rCredit < 0) keep = true;
      } else {
        if (rCash != 0 || rCredit != 0) keep = true;
      }

      if (keep) {
        filteredList.add(r);
        cash += rCash;
        if (rCredit < 0) {
          udhaar += rCredit.abs();
        } else {
          jammah += rCredit;
        }
      }
    }

    setState(() {
      _allRecords = filteredList;
      _filteredRecords = filteredList;
      _totalCash = cash;
      _totalUdhaar = udhaar;
      _totalJammah = jammah;
      _isLoading = false;
    });
  }

  void _filterData() {
    final query = _searchController.text.toLowerCase();
    String? dateQuery;
    if (_selectedDate != null) {
      dateQuery = DateFormat('dd-MM-yyyy').format(_selectedDate!);
    }

    double localCash = 0;
    double localUdhaar = 0;
    double localJammah = 0;

    final newList = _allRecords.where((r) {
      final name = r[SplitPaymentDB.C_NAME]?.toString().toLowerCase() ?? '';
      final suid = r[SplitPaymentDB.C_SUID]?.toString().toLowerCase() ?? '';
      final dbDate = r[SplitPaymentDB.C_DATE]?.toString() ?? '';

      bool matchesSearch = name.contains(query) || suid.contains(query);
      bool matchesDate = dateQuery == null || dbDate == dateQuery;

      return matchesSearch && matchesDate;
    }).toList();

    for (var r in newList) {
      double rCash = (r[SplitPaymentDB.C_PAYMENT_CASH] as num?)?.toDouble() ?? 0;
      double rCredit = (r[SplitPaymentDB.C_PAYMENT_CREDIT] as num?)?.toDouble() ?? 0;
      
      localCash += rCash;
      if (rCredit < 0) {
        localUdhaar += rCredit.abs();
      } else {
        localJammah += rCredit;
      }
    }

    setState(() {
      _filteredRecords = newList;
      _totalCash = localCash;
      _totalUdhaar = localUdhaar;
      _totalJammah = localJammah;
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blue,
            colorScheme: const ColorScheme.light(primary: Colors.blue),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _filterData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportToPDF() async {
    final doc = pw.Document();
    final String title = widget.filter == 'cash' ? "Diya & Jammah Report" : (widget.filter == 'credit' ? "Udhaar Report" : "Complete Khata Report");
    final String dateInfo = _selectedDate != null ? "Date: ${DateFormat('dd-MM-yyyy').format(_selectedDate!)}" : "Full History";

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text(dateInfo, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Text("Generated: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                if (widget.filter == null || widget.filter == 'cash') ...[
                  _pdfStat("Total Diya", _totalCash, PdfColors.blue700),
                  _pdfStat("Total Jammah", _totalJammah, PdfColors.green700, prefix: "+"),
                ],
                if (widget.filter == null || widget.filter == 'credit')
                  _pdfStat("Total Udhaar", _totalUdhaar, PdfColors.orange700, prefix: "-"),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Name / ID', 'Source', 'Bill', 'Status', 'Udhaar (-)', 'Jammah (+)'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
              cellHeight: 25,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.center,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
              },
              data: _filteredRecords.map((r) {
                final double rCash = (r[SplitPaymentDB.C_PAYMENT_CASH] as num?)?.toDouble() ?? 0;
                final double rCredit = (r[SplitPaymentDB.C_PAYMENT_CREDIT] as num?)?.toDouble() ?? 0;
                final double rTotal = (r[SplitPaymentDB.C_TOTAL] as num?)?.toDouble() ?? 0;
                
                String status = "";
                String udhaarStr = "";
                String jammahStr = "";

                if (rCash != 0) {
                  status = rCash < 0 ? "VAPSI" : "DIYA";
                  // Cash is neutral for this column view usually, but we'll show it or skip based on your need.
                  // For now, let's keep the credit focus for these columns.
                } else if (rCredit != 0) {
                  status = rCredit < 0 ? "UDHAAR" : "JAMMAH";
                  if (rCredit < 0) {
                    udhaarStr = NumberFormat('#,###').format(rCredit.abs());
                  } else {
                    jammahStr = NumberFormat('#,###').format(rCredit.abs());
                  }
                }

                return [
                  r[SplitPaymentDB.C_DATE] ?? "",
                  "${r[SplitPaymentDB.C_NAME]}\nID: ${r[SplitPaymentDB.C_SUID]}",
                  r[SplitPaymentDB.C_TABLE_NAME]?.toString().toUpperCase() ?? "",
                  NumberFormat('#,###').format(rTotal),
                  status,
                  udhaarStr,
                  jammahStr,
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    // Auto save to temp and open instantly
    final output = await getTemporaryDirectory();
    final String fileName = "Khata_Report_${DateFormat('ddMMyy_HHmmss').format(DateTime.now())}.pdf";
    final file = File("${output.path}/$fileName");
    await file.writeAsBytes(await doc.save());

    // Auto open the file
    await OpenFilex.open(file.path);
  }

  pw.Widget _pdfStat(String label, double val, PdfColor color, {String prefix = ""}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
          pw.Text("$prefix${NumberFormat('#,###').format(val)}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // --- 1. SEARCH & TOTALS HEADER ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CupertinoSearchTextField(
                        controller: _searchController,
                        placeholder: "Search by Name or ID...",
                        onChanged: (val) => _filterData(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Export PDF Button
                    GestureDetector(
                      onTap: _exportToPDF,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _pickDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedDate == null ? Colors.white : Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _selectedDate == null ? Colors.grey.withValues(alpha: 0.3) : Colors.blue),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month, size: 18, color: _selectedDate == null ? Colors.grey : Colors.blue),
                            if (_selectedDate != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('dd-MM-yyyy').format(_selectedDate!),
                                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  setState(() => _selectedDate = null);
                                  _filterData();
                                },
                                child: const Icon(Icons.close, size: 16, color: Colors.blue),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Centered Summary Cards
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.filter == null || widget.filter == 'cash') ...[
                        _buildStatCard("Total Diya", _totalCash, Colors.blue),
                        if (_totalJammah > 0) ...[
                          const SizedBox(width: 10),
                          _buildStatCard("Total Jammah", _totalJammah, Colors.green),
                        ],
                      ],
                      if (widget.filter == null || widget.filter == 'credit') ...[
                        if (widget.filter == null && _totalUdhaar > 0) const SizedBox(width: 10),
                        if (_totalUdhaar > 0) ...[
                          _buildStatCard("Total Udhaar", _totalUdhaar, Colors.orange),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- 2. LOG LIST ---
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : _filteredRecords.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredRecords.length,
                        itemBuilder: (context, index) {
                          final record = _filteredRecords[index];
                          return _buildLogItem(record);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, double value, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label, 
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold, letterSpacing: 0.5)
          ),
          const SizedBox(height: 8),
          Text(
            "PKR ${NumberFormat('#,###').format(value)}",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(Map<String, dynamic> record) {
    final String name = record[SplitPaymentDB.C_NAME] ?? "Unknown";
    final String suid = record[SplitPaymentDB.C_SUID] ?? "N/A";
    final double cash = (record[SplitPaymentDB.C_PAYMENT_CASH] as num?)?.toDouble() ?? 0;
    final double credit = (record[SplitPaymentDB.C_PAYMENT_CREDIT] as num?)?.toDouble() ?? 0;
    final double total = (record[SplitPaymentDB.C_TOTAL] as num?)?.toDouble() ?? 0;
    final String source = record[SplitPaymentDB.C_TABLE_NAME] ?? "log";
    final String date = record[SplitPaymentDB.C_DATE] ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(date, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  source.toUpperCase(),
                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
                  Text("ID: $suid", style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("BILL TOTAL", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text(
                    "PKR ${NumberFormat('#,###').format(total)}",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (cash != 0) ...[
                _buildPaymentBadge(cash < 0 ? "VAPSI" : "DIYA", cash.abs(), Colors.blue),
                const SizedBox(width: 12),
              ],
              if (credit != 0)
                _buildPaymentBadge(credit < 0 ? "UDHAAR" : "JAMMAH", credit.abs(), credit < 0 ? Colors.orange : Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBadge(String label, double amount, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 65,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 7, color: color, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 6),
        Text("PKR ${NumberFormat('#,###').format(amount)}", style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(CupertinoIcons.doc_text_search, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        const Text("No transactions found", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
