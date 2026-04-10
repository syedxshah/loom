import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:loom/backend/homebackend/customer/bcustomer.dart';
import 'package:loom/backend/homebackend/customer/bcustomerlist_in_purchaing.dart';

class CustomerLedgerScreen extends StatefulWidget {
  const CustomerLedgerScreen({super.key});

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
  List<Map<String, dynamic>> _customers = [];
  Map<String, dynamic>? _selectedCustomer;
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
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoading = true);
    final customers = await BCustomer.getInstance.getAllCustomers();
    setState(() {
      _customers = customers;
      _isLoading = false;
    });
  }

  Future<void> _viewLedger(Map<String, dynamic> customer) async {
    String uid = customer[BCustomer.C_customeruid].toString();
    setState(() {
      _selectedCustomer = customer;
      _isLedgerLoading = true;
      _startDate = null;
      _endDate = null;
    });

    final entries = await BCustomerLedgerDB.getInstance.getTransactions(uid);

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
      final dateStr = entry[BCustomerLedgerDB.C_date]?.toString() ?? "";
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
              primary: Color(0xFF1E293B),
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
    String type = "Received"; // "Received" (+) or "Charge" (-)

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
                  "Received": Text("Payment Received", style: TextStyle(fontSize: 12)),
                  "Charge": Text("Bill / Charge", style: TextStyle(fontSize: 12)),
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
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final amountString = amountController.text;
                final itemName = itemController.text;
                
                final amount = double.tryParse(amountString) ?? 0;
                if (amount <= 0 || itemName.isEmpty) return;

                // Calculate Running Balance
                double lastBalance = 0;
                if (_allEntries.isNotEmpty) {
                  lastBalance = double.tryParse(_allEntries.first[BCustomerLedgerDB.C_credit]?.toString() ?? '0') ?? 0;
                }

                // Balance = lastBalance + (Paid - Bill)
                double newBalance = type == "Received" ? lastBalance + amount : lastBalance - amount;

                await BCustomerLedgerDB.getInstance.addTransaction(_selectedCustomer![BCustomer.C_customeruid].toString(), {
                  BCustomerLedgerDB.C_invoice_id: "MANUAL_${DateTime.now().millisecondsSinceEpoch}",
                  BCustomerLedgerDB.C_item: itemName,
                  BCustomerLedgerDB.C_meter: "N/A",
                  BCustomerLedgerDB.C_than: "N/A",
                  BCustomerLedgerDB.C_total: type == "Charge" ? amount.toString() : "0",
                  BCustomerLedgerDB.C_paid: type == "Received" ? amount.toString() : "0",
                  BCustomerLedgerDB.C_type: "Manual",
                  BCustomerLedgerDB.C_date: DateFormat('dd-MM-yyyy').format(DateTime.now()),
                  BCustomerLedgerDB.C_credit: newBalance.toString(),
                });

                Navigator.pop(context);
                _viewLedger(_selectedCustomer!);
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
      _selectedCustomer = null;
      _allEntries = [];
      _filteredEntries = [];
      _startDate = null;
      _endDate = null;
    });
  }

  Future<void> _exportToPDF() async {
    if (_selectedCustomer == null) return;
    
    final doc = pw.Document();
    final String dateInfo = (_startDate != null && _endDate != null) 
      ? "${DateFormat('dd-MM-yyyy').format(_startDate!)} to ${DateFormat('dd-MM-yyyy').format(_endDate!)}"
      : "Full History";

    double totalBill = 0;
    double totalPaid = 0;
    for (var entry in _filteredEntries) {
      totalBill += double.tryParse(entry[BCustomerLedgerDB.C_total]?.toString() ?? '0') ?? 0;
      totalPaid += double.tryParse(entry[BCustomerLedgerDB.C_paid]?.toString() ?? '0') ?? 0;
    }
    double currentBalance = 0;
    if (_allEntries.isNotEmpty) {
      currentBalance = double.tryParse(_allEntries.first[BCustomerLedgerDB.C_credit]?.toString() ?? '0') ?? 0;
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
                      pw.Text("Customer Ledger Statement", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                      pw.Text("Customer: ${_selectedCustomer![BCustomer.C_customername]}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text("ID: ${_selectedCustomer![BCustomer.C_customeruid]} | City: ${_selectedCustomer![BCustomer.C_customercity] ?? 'N/A'}", style: const pw.TextStyle(fontSize: 12)),
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
                _pdfStat("Total Billing", totalBill, PdfColors.red700),
                _pdfStat("Total Paid", totalPaid, PdfColors.green700),
                _pdfStat(currentBalance < 0 ? "Udhaar" : "Jammah", currentBalance.abs(), currentBalance < 0 ? PdfColors.orange700 : PdfColors.blue700, prefix: currentBalance < 0 ? "-" : "+"),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Description', 'Meters', 'Bill', 'Paid', 'Udhaar (-)', 'Jammah (+)'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellHeight: 25,
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
              },
              data: [
                ..._filteredEntries.map((e) {
                  final bal = double.tryParse(e[BCustomerLedgerDB.C_credit]?.toString() ?? '0') ?? 0;
                  String udhaarCell = "";
                  String jammahCell = "";
                  if (bal < 0) {
                    udhaarCell = NumberFormat('#,###').format(bal.abs());
                  } else {
                    jammahCell = NumberFormat('#,###').format(bal.abs());
                  }

                  return [
                    e[BCustomerLedgerDB.C_date] ?? "",
                    e[BCustomerLedgerDB.C_item] ?? "Sale Bill",
                    e[BCustomerLedgerDB.C_meter]?.toString() ?? "0",
                    NumberFormat('#,###').format(double.tryParse(e[BCustomerLedgerDB.C_total]?.toString() ?? '0') ?? 0),
                    NumberFormat('#,###').format(double.tryParse(e[BCustomerLedgerDB.C_paid]?.toString() ?? '0') ?? 0),
                    udhaarCell,
                    jammahCell,
                  ];
                }),
                [
                  'TOTAL', '', '', 
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
    final String fileName = "Customer_Ledger_${_selectedCustomer![BCustomer.C_customername].toString().replaceAll(' ', '_')}_${DateFormat('ddMyy').format(DateTime.now())}.pdf";
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
      return const Scaffold(body: Center(child: CupertinoActivityIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _selectedCustomer == null
          ? _buildCustomerList()
          : _buildLedgerDetail(),
    );
  }

  Widget _buildCustomerList() {
    final filteredCustomers = _customers.where((v) {
      final name = v[BCustomer.C_customername]?.toString().toLowerCase() ?? "";
      final phone =
          v[BCustomer.C_customerphone]?.toString().toLowerCase() ?? "";
      final uid = v[BCustomer.C_customeruid]?.toString().toLowerCase() ?? "";
      final city = v[BCustomer.C_customercity]?.toString().toLowerCase() ?? "";
      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          phone.contains(query) ||
          uid.contains(query) ||
          city.contains(query);
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
                "Select Customer",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
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
                  icon: const Icon(
                    CupertinoIcons.clear_circled_solid,
                    color: Colors.grey,
                  ),
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
              border: Border.all(color: const Color(0xFFE2E8F0)),
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
                hintText: "Search name, phone, UID or city...",
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                prefixIcon: const Icon(
                  CupertinoIcons.search,
                  size: 20,
                  color: Colors.grey,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        Expanded(
          child: filteredCustomers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.userSearch,
                        size: 48,
                        color: Colors.grey.shade200,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "No customers found",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final customer = filteredCustomers[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          child: Text(
                            customer[BCustomer.C_customeruid].toString(),
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          customer[BCustomer.C_customername],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        subtitle: Text(
                          "${customer[BCustomer.C_customercity] ?? 'N/A'} | ${customer[BCustomer.C_customerphone] ?? 'No Phone'}",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        trailing: const Icon(
                          CupertinoIcons.chevron_right,
                          size: 18,
                        ),
                        onTap: () => _viewLedger(customer),
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
      totalBill +=
          double.tryParse(
            entry[BCustomerLedgerDB.C_total]?.toString() ?? '0',
          ) ??
          0;
      totalPaid +=
          double.tryParse(entry[BCustomerLedgerDB.C_paid]?.toString() ?? '0') ??
          0;
    }

    // Standard Balance Logic: Negative = Udhaar, Positive = Jamah
    // For customers, if they pay MORE than they owe, they have a Jamah/Advance.
    // If they owe MORE than they have paid, it's Udhaar.
    // Standard logic in Sellings is: newRunningBalance = lastBalance + (Paid - Bill)
    double currentBalance = 0;
    if (_allEntries.isNotEmpty) {
      currentBalance =
          double.tryParse(
            _allEntries.first[BCustomerLedgerDB.C_credit]?.toString() ?? '0',
          ) ??
          0;
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
                      _selectedCustomer![BCustomer.C_customername],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      isFiltered
                          ? "${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM').format(_endDate!)}"
                          : "Full Transaction History",
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
                  color: isFiltered ? Colors.blue : const Color(0xFF64748B),
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
              _buildSummaryCard(
                "Total Billing",
                totalBill,
                Colors.red,
                LucideIcons.shoppingCart,
              ),
              const SizedBox(width: 10),
              _buildSummaryCard(
                "Total Paid",
                totalPaid,
                Colors.green,
                LucideIcons.banknote,
              ),
              const SizedBox(width: 10),
              _buildSummaryCard(
                currentBalance < 0 ? "Udhaar" : "Advance (Jamah)",
                currentBalance.abs(),
                currentBalance < 0 ? Colors.orange : Colors.blue,
                currentBalance < 0
                    ? LucideIcons.alertTriangle
                    : LucideIcons.checkCircle,
              ),
            ],
          ),
        ),

        // Ledger Table
        Expanded(
          child: _isLedgerLoading
              ? const Center(child: CupertinoActivityIndicator())
              : _filteredEntries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.fileQuestion,
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
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
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
                              headingRowColor: MaterialStateProperty.all(
                                const Color(0xFFF8FAFC),
                              ),
                              columnSpacing: 24,
                              horizontalMargin: 20,
                              columns: const [
                                DataColumn(
                                  label: Text(
                                    "Date",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    "Description",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    "Meters",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    "Bill (Debit)",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    "Paid (Credit)",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    "Balance",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                              rows: _filteredEntries.map((e) {
                                final balance =
                                    double.tryParse(
                                e[BCustomerLedgerDB.C_credit]
                                    ?.toString() ??
                                    '0',
                                ) ??
                                    0;
                                final isUdhaar = balance < 0;

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        e[BCustomerLedgerDB.C_date] ?? "",
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        e[BCustomerLedgerDB.C_item] ??
                                            "Sale Bill",
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        e[BCustomerLedgerDB.C_meter]
                                            ?.toString() ??
                                            "0",
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        "Rs. ${double.tryParse(e[BCustomerLedgerDB.C_total]?.toString() ?? '0')?.toStringAsFixed(0) ?? '0'}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        "Rs. ${double.tryParse(e[BCustomerLedgerDB.C_paid]?.toString() ?? '0')?.toStringAsFixed(0) ?? '0'}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        "Rs. ${balance.abs().toStringAsFixed(0)}",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: isUdhaar
                                              ? Colors.orange
                                              : Colors.blue,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
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

  Widget _buildSummaryCard(
    String title,
    double amount,
    MaterialColor color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: color[700],
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                Icon(icon, size: 14, color: color.withOpacity(0.5)),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "Rs. ${NumberFormat("#,###").format(amount)}",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
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
Widget LCustomer() {
  return const CustomerLedgerScreen();
}
