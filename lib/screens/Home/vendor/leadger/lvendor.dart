import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:loom/backend/homebackend/vendor/bvendor.dart';
import 'package:loom/backend/homebackend/vendor/bvendername.dart';

class VendorLedgerScreen extends StatefulWidget {
  const VendorLedgerScreen({super.key});

  @override
  State<VendorLedgerScreen> createState() => _VendorLedgerScreenState();
}

class _VendorLedgerScreenState extends State<VendorLedgerScreen> {
  List<Map<String, dynamic>> _vendors = [];
  Map<String, dynamic>? _selectedVendor;
  List<Map<String, dynamic>> _allEntries = [];
  List<Map<String, dynamic>> _filteredEntries = [];
  bool _isLoading = true;
  bool _isLedgerLoading = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _fetchVendors();
  }

  Future<void> _fetchVendors() async {
    setState(() => _isLoading = true);
    final vendors = await Bvendor.getInstance.getAllVendors();
    setState(() {
      _vendors = vendors;
      _isLoading = false;
    });
  }

  Future<void> _viewLedger(Map<String, dynamic> vendor) async {
    setState(() {
      _selectedVendor = vendor;
      _isLedgerLoading = true;
      _startDate = null;
      _endDate = null;
    });

    final entries = await Bvendername.getInstance.getLedgerEntries(
      vendor['name'],
    );

    setState(() {
      _allEntries = entries;
      _filteredEntries = entries;
      _isLedgerLoading = false;
    });
  }

  void _applyFilter() {
    if (_startDate == null || _endDate == null) {
      setState(() {
        _filteredEntries = _allEntries;
      });
      return;
    }

    final filtered = _allEntries.where((entry) {
      final dateStr = entry['date']?.toString() ?? "";
      final entryDate = _parseDate(dateStr);
      if (entryDate == null) return true;

      return (entryDate.isAfter(_startDate!) ||
              entryDate.isAtSameMomentAs(_startDate!)) &&
          (entryDate.isBefore(_endDate!) ||
              entryDate.isAtSameMomentAs(_endDate!));
    }).toList();

    setState(() {
      _filteredEntries = filtered;
    });
  }

  DateTime? _parseDate(String dateStr) {
    try {
      return DateFormat('dd-MM-yyyy').parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF455A64),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _applyFilter();
    }
  }

  void _clearFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _filteredEntries = _allEntries;
    });
  }

  void _showAddEntryDialog() async {
    final amountController = TextEditingController();
    final itemController = TextEditingController();
    final noteController = TextEditingController();
    String type = "Paid"; // "Paid" (+) or "Bill" (-)

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Manual Ledger Entry", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoSlidingSegmentedControl<String>(
                groupValue: type,
                children: const {
                  "Paid": Text("Payment Made", style: TextStyle(fontSize: 12)),
                  "Bill": Text("Bill Received", style: TextStyle(fontSize: 12)),
                },
                onValueChanged: (v) => setPopupState(() => type = v!),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Amount (Rs.)",
                  prefixIcon: const Icon(CupertinoIcons.money_dollar),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: itemController,
                decoration: InputDecoration(
                  labelText: "Item / Category",
                  prefixIcon: const Icon(CupertinoIcons.tag),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: "Note / Description",
                  prefixIcon: const Icon(CupertinoIcons.pencil),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF455A64),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final amountString = amountController.text;
                final itemName = itemController.text;
                
                final amount = double.tryParse(amountString) ?? 0;
                if (amount <= 0 || itemName.isEmpty) return;

                // Calculate Running Balance
                double lastBalance = await Bvendername.getInstance.getRunningBalance(_selectedVendor!['name']);

                // Vendor Balance = lastBalance + (CashPaid - TotalBill)
                double newBalance = type == "Paid" ? lastBalance + amount : lastBalance - amount;

                await Bvendername.getInstance.addLedgerEntry(_selectedVendor!['name'], {
                  'name': itemName,
                  'date': DateFormat('dd-MM-yyyy').format(DateTime.now()),
                  'uid': "MANUAL_${DateTime.now().millisecondsSinceEpoch}",
                  'totalmeter': 0.0,
                  'total_price': type == "Bill" ? amount : 0.0,
                  'per_meter': 0.0,
                  'cash': type == "Paid" ? amount : 0.0,
                  'debit': newBalance,
                });

                Navigator.pop(context);
                _viewLedger(_selectedVendor!);
              },
              child: const Text("Save Entry"),
            ),
          ],
        ),
      ),
    );
  }

  void _backToList() {
    setState(() {
      _selectedVendor = null;
      _allEntries = [];
      _filteredEntries = [];
      _startDate = null;
      _endDate = null;
    });
  }

  Future<void> _exportToPDF() async {
    if (_selectedVendor == null) return;
    
    final doc = pw.Document();
    final String dateInfo = (_startDate != null && _endDate != null) 
      ? "${DateFormat('dd-MM-yyyy').format(_startDate!)} to ${DateFormat('dd-MM-yyyy').format(_endDate!)}"
      : "Full History";

    double totalBill = 0;
    double totalPaid = 0;
    for (var entry in _filteredEntries) {
      totalBill += double.tryParse(entry['total_price']?.toString() ?? '0') ?? 0;
      totalPaid += double.tryParse(entry['cash']?.toString() ?? '0') ?? 0;
    }
    double currentBalance = 0;
    if (_allEntries.isNotEmpty) {
      currentBalance = double.tryParse(_allEntries.first['debit']?.toString() ?? '0') ?? 0;
    }

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
                      pw.Text("Vendor Ledger Statement", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                      pw.Text("Vendor: ${_selectedVendor!['name']}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text("Period: $dateInfo", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Text("Generated: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _pdfStat("Total Bill", totalBill, PdfColors.red700),
                _pdfStat("Cash Paid", totalPaid, PdfColors.green700),
                _pdfStat(currentBalance < 0 ? "Udhaar" : "Advance", currentBalance.abs(), currentBalance < 0 ? PdfColors.orange700 : PdfColors.blue700, prefix: currentBalance < 0 ? "-" : "+"),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Description', 'Mtr', 'Rate', 'Bill', 'Paid', 'Udhaar (-)', 'Jammah (+)'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellHeight: 25,
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
                7: pw.Alignment.centerRight,
              },
              data: [
                ..._filteredEntries.map((e) {
                  final bal = double.tryParse(e['debit']?.toString() ?? '0') ?? 0;
                  String udhaarCell = "";
                  String jammahCell = "";
                  if (bal < 0) {
                    udhaarCell = NumberFormat('#,###').format(bal.abs());
                  } else {
                    jammahCell = NumberFormat('#,###').format(bal.abs());
                  }

                  return [
                    e['date'] ?? "",
                    e['name'] ?? "",
                    e['totalmeter']?.toString() ?? "0",
                    e['per_meter']?.toString() ?? "0",
                    NumberFormat('#,###').format(double.tryParse(e['total_price']?.toString() ?? '0') ?? 0),
                    NumberFormat('#,###').format(double.tryParse(e['cash']?.toString() ?? '0') ?? 0),
                    udhaarCell,
                    jammahCell,
                  ];
                }),
                [
                  'TOTAL', '', '', '', 
                  NumberFormat('#,###').format(totalBill), 
                  NumberFormat('#,###').format(totalPaid), 
                  currentBalance < 0 ? NumberFormat('#,###').format(currentBalance.abs()) : "",
                  currentBalance >= 0 ? NumberFormat('#,###').format(currentBalance.abs()) : ""
                ],
              ],
            ),
            pw.SizedBox(height: 40),
            pw.Divider(thickness: 0.5, color: PdfColors.grey400),
            pw.Center(child: pw.Text("Software by iansar.codes", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500))),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final String fileName = "Vendor_Ledger_${_selectedVendor!['name']}_${DateFormat('ddMyy').format(DateTime.now())}.pdf";
    final file = File("${output.path}/$fileName");
    await file.writeAsBytes(await doc.save());
    await OpenFilex.open(file.path);
  }

  pw.Widget _pdfStat(String label, double val, PdfColor color, {String prefix = ""}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: color)),
          pw.Text("$prefix${NumberFormat('#,###').format(val)}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _selectedVendor == null ? _buildVendorList() : _buildLedgerDetail(),
    );
  }

  Widget _buildVendorList() {
    final filteredVendors = _vendors.where((v) {
      final name = v['name']?.toString().toLowerCase() ?? "";
      final phone = v['phone']?.toString().toLowerCase() ?? "";
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || phone.contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Select Vendor",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = "";
                    });
                  },
                  icon: const Icon(CupertinoIcons.clear_circled_solid, color: Colors.grey),
                ),
            ],
          ),
        ),
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: "Search name or phone...",
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                prefixIcon: const Icon(CupertinoIcons.search, size: 20, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        Expanded(
          child: filteredVendors.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.person_crop_circle_badge_exclam, size: 48, color: Colors.grey.shade200),
                      const SizedBox(height: 10),
                      const Text("No vendors found", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: filteredVendors.length,
            itemBuilder: (context, index) {
              final vendor = filteredVendors[index];
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueGrey.shade50,
                    child: const Icon(
                      CupertinoIcons.person_alt,
                      color: Colors.blueGrey,
                    ),
                  ),
                  title: Text(
                    vendor['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    vendor['phone'] ?? "No Phone Entry",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  trailing: const Icon(CupertinoIcons.chevron_right, size: 18),
                  onTap: () => _viewLedger(vendor),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLedgerDetail() {
    double totalBill = 0;
    double totalPaid = 0;
    for (var entry in _filteredEntries) {
      totalBill += double.tryParse(entry['total_price']?.toString() ?? '0') ?? 0;
      totalPaid += double.tryParse(entry['cash']?.toString() ?? '0') ?? 0;
    }
    // Current balance from the most recent entry's debit column (running balance)
    double currentBalance = 0;
    if (_allEntries.isNotEmpty) {
      currentBalance = double.tryParse(_allEntries.first['debit']?.toString() ?? '0') ?? 0;
    }

    bool isFiltered = _startDate != null && _endDate != null;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(10, 20, 20, 15),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(
                onPressed: _backToList,
                icon: const Icon(CupertinoIcons.back, size: 24),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedVendor!['name'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isFiltered
                          ? "${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM').format(_endDate!)}"
                          : "Full Transaction Ledger",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _showAddEntryDialog,
                icon: const Icon(CupertinoIcons.add_circled_solid, color: Colors.green, size: 28),
                tooltip: "Add Manual Entry",
              ),
              if (isFiltered)
                IconButton(
                  onPressed: _clearFilter,
                  icon: const Icon(
                    CupertinoIcons.refresh_thin,
                    size: 20,
                    color: Colors.red,
                  ),
                  tooltip: "Clear Filter",
                ),
              // Export PDF Button
              IconButton(
                onPressed: _exportToPDF,
                icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 22),
                tooltip: "Download PDF",
              ),
              IconButton(
                onPressed: _selectDateRange,
                icon: Icon(
                  CupertinoIcons.calendar,
                  color: isFiltered ? Colors.blue : Colors.blueGrey,
                  size: 24,
                ),
                tooltip: "Filter by Date",
              ),
            ],
          ),
        ),

        // Summary Cards
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              _buildSummaryCard("Total Bill", totalBill, Colors.red),
              const SizedBox(width: 10),
              _buildSummaryCard("Cash Paid", totalPaid, Colors.green),
              const SizedBox(width: 10),
              _buildSummaryCard(
                currentBalance < 0 ? "Udhaar" : "Advance",
                currentBalance.abs(),
                currentBalance < 0 ? Colors.orange : Colors.blue,
              ),
            ],
          ),
        ),

        // Ledger Table
        Expanded(
          child: _isLedgerLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredEntries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.doc_text,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "No transactions found",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                Colors.grey.shade50,
                              ),
                              columnSpacing: 20,
                              horizontalMargin: 15,
                              columns: const [
                                DataColumn(label: Text("Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                DataColumn(label: Text("Description", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                DataColumn(label: Text("Mtr", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                DataColumn(label: Text("Rate", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                DataColumn(label: Text("Total Bill", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                DataColumn(label: Text("Cash Paid", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                DataColumn(label: Text("Balance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                              ],
                              rows: [
                                ..._filteredEntries.map((e) {
                                  final bal = double.tryParse(e['debit']?.toString() ?? '0') ?? 0;
                                  final isUdhaar = bal < 0;
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(e['date'] ?? "", style: const TextStyle(fontSize: 12))),
                                      DataCell(Text(e['name'] ?? "", style: const TextStyle(fontSize: 12))),
                                      DataCell(Text(e['totalmeter']?.toString() ?? "0", style: const TextStyle(fontSize: 12))),
                                      DataCell(Text(e['per_meter']?.toString() ?? "0", style: const TextStyle(fontSize: 12))),
                                      DataCell(Text("Rs. ${(double.tryParse(e['total_price']?.toString() ?? '0') ?? 0).toStringAsFixed(0)}", 
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 12))),
                                      DataCell(Text("Rs. ${(double.tryParse(e['cash']?.toString() ?? '0') ?? 0).toStringAsFixed(0)}", 
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12))),
                                      DataCell(Text("Rs. ${bal.abs().toStringAsFixed(0)}", 
                                        style: TextStyle(fontWeight: FontWeight.w900, color: isUdhaar ? Colors.orange : Colors.blue, fontSize: 12))),
                                    ],
                                  );
                                }),
                                // Total Row
                                DataRow(
                                  color: WidgetStateProperty.all(Colors.blueGrey.withOpacity(0.05)),
                                  cells: [
                                    const DataCell(Text("TOTAL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey))),
                                    const DataCell(Text("")),
                                    const DataCell(Text("")),
                                    const DataCell(Text("")),
                                    DataCell(Text("Rs. ${totalBill.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.red, fontSize: 13))),
                                    DataCell(Text("Rs. ${totalPaid.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 13))),
                                    DataCell(Text("Rs. ${currentBalance.abs().toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.w900, color: currentBalance < 0 ? Colors.orange : Colors.blue, fontSize: 13))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSummaryCard(String title, double amount, MaterialColor color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "Rs. ${amount.toStringAsFixed(0)}",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Global Widget used by Home
Widget Lvendor() {
  return const VendorLedgerScreen();
}
