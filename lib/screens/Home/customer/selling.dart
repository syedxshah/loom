import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:loom/backend/homebackend/customer/bcustomer.dart';
import 'package:loom/backend/homebackend/vendor/bvendor.dart';
import 'package:loom/backend/homebackend/vendor/bvendername.dart';
import 'package:loom/backend/homebackend/operations/selling.dart';
import 'package:loom/backend/homebackend/operations/sale.dart';
import 'package:loom/backend/homebackend/operations/bill.dart';
import 'package:loom/backend/homebackend/operations/split_payment_db.dart';
import 'package:loom/backend/homebackend/customer/bcustomerlist_in_purchaing.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:loom/widget/rowbutton.dart';

class SellingPage extends StatefulWidget {
  const SellingPage({super.key});

  @override
  State<SellingPage> createState() => _SellingPageState();
}

class _SellingPageState extends State<SellingPage> {
  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _allVendors = [];
  List<Map<String, dynamic>> _allBills = [];
  List<Map<String, dynamic>> _allStock = [];
  DateTime? _startDate;
  DateTime? _endDate;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _thanController = TextEditingController();
  final TextEditingController _meterController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default to today's bills
    _startDate = DateTime.now();
    _endDate = DateTime.now();
    _loadDatabaseData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _itemController.dispose();
    _thanController.dispose();
    _meterController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadDatabaseData() async {
    try {
      final customers = await BCustomer.getInstance.getAllCustomers();
      final vendors = await Bvendor.getInstance.getAllVendors();
      final bills = await SellingDB.getInstance.getBillHistory();
      final stock = await SellingDB.getInstance.getAvailableStock();

      if (!mounted) return;

      setState(() {
        _allCustomers = customers;
        _allVendors = vendors;
        _allBills = bills;
        _allStock = stock;
      });
    } catch (e) {
      debugPrint("Error loading data: $e");
    }
  }

  void _showNewBillPopup() {
    _nameController.clear();
    _itemController.clear();
    _thanController.text = "1";
    _meterController.text = "21";
    _priceController.clear();

    List<Map<String, dynamic>> tempItems = [];
    String recordType = "Permanent";
    String permanentRole = "Customer";
    Map<String, dynamic>? selectedPerson;
    Map<String, dynamic>? selectedStockItem;
    final TextEditingController _stockSearchController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPopupState) {
            double totalBill = tempItems.fold(
              0,
              (sum, item) =>
                  sum +
                  (double.tryParse(item['total']?.toString() ?? '0') ?? 0),
            );

            List<Map<String, dynamic>> sourceList =
                (permanentRole == "Customer") ? _allCustomers : _allVendors;
            List<Map<String, dynamic>> filteredPeople = sourceList.where((
              person,
            ) {
              String name = person['name']?.toString().toLowerCase() ?? "";
              return name.contains(_nameController.text.toLowerCase());
            }).toList();

            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text(
                "Create New Bill",
                style: TextStyle(
                  color: Colors.indigo,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: 580,
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel("1. Record Type"),
                            Row(
                              children: [
                                _radioTile(
                                  "Temp",
                                  "Temporary",
                                  recordType,
                                  (v) => setPopupState(() {
                                    recordType = v!;
                                    selectedPerson = null;
                                    _nameController.clear();
                                  }),
                                ),
                                _radioTile(
                                  "Permanent",
                                  "Permanent",
                                  recordType,
                                  (v) => setPopupState(() => recordType = v!),
                                ),
                              ],
                            ),
                            if (recordType == "Permanent") ...[
                              const Divider(),
                              _sectionLabel("2. Select Account"),
                              Row(
                                children: [
                                  _radioTile(
                                    "Customer",
                                    "Customer",
                                    permanentRole,
                                    (v) => setPopupState(() {
                                      permanentRole = v!;
                                      selectedPerson = null;
                                      _nameController.clear();
                                    }),
                                  ),
                                  _radioTile(
                                    "Vendor",
                                    "Vendor",
                                    permanentRole,
                                    (v) => setPopupState(() {
                                      permanentRole = v!;
                                      selectedPerson = null;
                                      _nameController.clear();
                                    }),
                                  ),
                                ],
                              ),
                            ],
                            selectedPerson == null
                                ? Column(
                                    children: [
                                      TextField(
                                        controller: _nameController,
                                        onChanged: (_) => setPopupState(() {}),
                                        decoration: InputDecoration(
                                          labelText: recordType == "Temporary"
                                              ? "Enter Name"
                                              : "Search $permanentRole...",
                                          prefixIcon: const Icon(
                                            Icons.person_search,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      if (recordType == "Permanent" &&
                                          _nameController.text.isNotEmpty &&
                                          filteredPeople.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          constraints: const BoxConstraints(
                                            maxHeight: 120,
                                          ),
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: filteredPeople.length,
                                            itemBuilder: (context, index) {
                                              final p = filteredPeople[index];
                                              return ListTile(
                                                dense: true,
                                                title: Text(p['name']),
                                                subtitle: Text(
                                                  "Contact: ${p['phone'] ?? 'N/A'}",
                                                ),
                                                onTap: () => setPopupState(() {
                                                  selectedPerson = p;
                                                  _nameController.text =
                                                      p['name'];
                                                }),
                                              );
                                            },
                                          ),
                                        ),
                                    ],
                                  )
                                : _buildSelectedPersonCard(
                                    selectedPerson!,
                                    () => setPopupState(() {
                                      selectedPerson = null;
                                      _nameController.clear();
                                    }),
                                  ),
                            const Divider(height: 30),
                            _sectionLabel("3. Add Items"),
                            selectedStockItem == null
                                ? Column(
                                    children: [
                                      TextField(
                                        controller: _itemController,
                                        onChanged: (_) => setPopupState(() {}),
                                        decoration: const InputDecoration(
                                          labelText: "Item Name",
                                          prefixIcon: Icon(
                                            Icons.shopping_bag,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      if (_itemController.text.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.indigo.withValues(
                                                alpha: 0.1,
                                              ),
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            color: Colors.indigo.withValues(
                                              alpha: 0.02,
                                            ),
                                          ),
                                          constraints: const BoxConstraints(
                                            maxHeight: 150,
                                          ),
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: _allStock.length,
                                            itemBuilder: (context, index) {
                                              final s = _allStock[index];
                                              String name =
                                                  s['name']
                                                      ?.toString()
                                                      .toLowerCase() ??
                                                  "";
                                              String search = _itemController
                                                  .text
                                                  .toLowerCase();
                                              if (!name.contains(search))
                                                return const SizedBox.shrink();

                                              return ListTile(
                                                dense: true,
                                                title: Text(
                                                  s['name'],
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  "UID: ${s['uid']} | Avail: ${s['total_meter']} Mtr | PKR ${s['per_meter_price']}",
                                                ),
                                                onTap: () => setPopupState(() {
                                                  selectedStockItem = s;
                                                  _itemController.text =
                                                      s['name'];
                                                  _meterController.text =
                                                      "21"; // User requested 21 default
                                                  _thanController.text =
                                                      "1"; // User requested 1 default
                                                  _priceController.text =
                                                      s['per_meter_price']
                                                          .toString();
                                                }),
                                              );
                                            },
                                          ),
                                        ),
                                    ],
                                  )
                                : _buildSelectedItemCard(
                                    selectedStockItem!,
                                    () => setPopupState(() {
                                      selectedStockItem = null;
                                      _itemController.clear();
                                      _meterController.text = "21";
                                      _thanController.text = "1";
                                      _priceController.clear();
                                    }),
                                  ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _thanController,
                                    onChanged: (_) => setPopupState(() {}),
                                    decoration: const InputDecoration(
                                      labelText: "Than",
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _meterController,
                                    onChanged: (_) => setPopupState(() {}),
                                    decoration: const InputDecoration(
                                      labelText: "Mtrs/Than",
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                "Total Meters: ${(double.tryParse(_thanController.text) ?? 1) * (double.tryParse(_meterController.text) ?? 21)}",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            TextField(
                              controller: _priceController,
                              decoration: const InputDecoration(
                                labelText: "Price per Meter",
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () {
                                if (_itemController.text.isNotEmpty &&
                                    _priceController.text.isNotEmpty) {
                                  double m =
                                      double.tryParse(_meterController.text) ??
                                      0;
                                  double th =
                                      double.tryParse(_thanController.text) ??
                                      1;
                                  double p =
                                      double.tryParse(_priceController.text) ??
                                      0;
                                  double calculatedTotalMeters = m * th;

                                  setPopupState(() {
                                    tempItems.add({
                                      'name': _itemController.text,
                                      'than': th.toInt(),
                                      'meter': m,
                                      'total_meters': calculatedTotalMeters,
                                      'per_meter_price': p,
                                      'cost_per_meter':
                                          selectedStockItem != null
                                          ? (selectedStockItem!['per_meter_price'] ??
                                                0.0)
                                          : 0.0,
                                      'total': calculatedTotalMeters * p,
                                      'stock_id': selectedStockItem?['id'],
                                    });
                                    selectedStockItem = null;
                                    _itemController.clear();
                                    _meterController.text = "21";
                                    _thanController.text = "1";
                                    _priceController.clear();
                                  });
                                }
                              },
                              icon: const Icon(Icons.add),
                              label: const Text("Add to Bill"),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 30),
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          _sectionLabel("Bill Summary"),
                          Expanded(
                            child: ListView.builder(
                              itemCount: tempItems.length,
                              itemBuilder: (context, i) => ListTile(
                                dense: true,
                                title: Text(
                                  tempItems[i]['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "PKR ${tempItems[i]['total']}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed: () => setPopupState(
                                        () => tempItems.removeAt(i),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Divider(),
                          if (selectedPerson != null) ...[
                            _summaryRow("Bill Subtotal", totalBill, Colors.black87),
                            
                            // Clear handling of Debt vs Advance
                            // For Vendor: fetch live balance from vendor ledger (cash column)
                            // For Customer: use obalance from customer master table
                            FutureBuilder<double>(
                              future: permanentRole == "Vendor"
                                  ? Bvendername.getInstance.getRunningBalance(selectedPerson!['name'] ?? '')
                                  : Future.value(double.tryParse(selectedPerson!['obalance']?.toString() ?? '0') ?? 0),
                              builder: (context, snapshot) {
                                double bal = snapshot.data ?? 0;
                                bool isUdhaar = bal < 0; // Negative = Udhaar
                                return Column(
                                  children: [
                                    _summaryRow(
                                      isUdhaar ? "Previous Udhaar" : "Available Jamah",
                                      bal.abs(),
                                      isUdhaar ? Colors.red : Colors.green,
                                    ),
                                    const Divider(),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          isUdhaar ? "Total Payable:" : "Net to Pay:",
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
                                        ),
                                        Text(
                                          "PKR ${(totalBill - bal).toStringAsFixed(0)}",
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ] else
                            Text(
                              "Total: PKR $totalBill",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_nameController.text.isEmpty || tempItems.isEmpty)
                      return;
                    _showPaymentSelectionDialog(
                      totalBill,
                      selectedPerson,
                      tempItems,
                      permanentRole,
                    );
                  },
                  child: const Text("Save Bill"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showPaymentSelectionDialog(
    double totalAmount,
    Map<String, dynamic>? person,
    List<Map<String, dynamic>> items,
    String role,
  ) async {
    String paymentMode = "Cash";
    final TextEditingController _paidController = TextEditingController(
      text: "0",
    );

    // Calculate dynamic net total including previous balance from exact Ledger History
    double previousBalance = 0;
    if (person != null) {
      if (role == "Vendor") {
        // First cleanup any NULL rows from vendor's ledger
        await Bvendername.getInstance.cleanupNullRows(person['name'] ?? '');
        
        final entries = await Bvendername.getInstance.getValidLedgerEntries(person['name'] ?? '');
        if (entries.isNotEmpty) {
          previousBalance = await Bvendername.getInstance.getRunningBalance(person['name'] ?? '');
        } else {
          // No valid ledger entries yet, fall back to master vendor balance
          previousBalance = double.tryParse(person['balance']?.toString() ?? '0') ?? 0;
        }
      } else if (role == "Customer") {
        String pUid = person['uid'].toString();
        final prevTransactions = await BCustomerLedgerDB.getInstance.getTransactions(pUid);
        if (prevTransactions.isNotEmpty) {
          previousBalance = double.tryParse(prevTransactions.first[BCustomerLedgerDB.C_credit]?.toString() ?? '0') ?? 0;
        } else {
          // Fallback if no bills exist yet
          previousBalance = double.tryParse(person['obalance']?.toString() ?? '0') ?? 0;
        }
      }
    }

    if (!mounted) return;

    // Negative = Udhaar (add to bill), Positive = Jamah (subtract from bill)
    double netTotal = totalAmount - previousBalance;
    // If net is negative (jamah exceeds bill), nothing to pay
    double cashPayable = netTotal > 0 ? netTotal : 0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPayState) {
            double paid = double.tryParse(_paidController.text) ?? 0;
            double remaining = totalAmount - paid;

            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text(
                "Select Payment Mode",
                style: TextStyle(
                  color: Colors.indigo,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show bill breakdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Bill Amount:", style: TextStyle(fontSize: 13)),
                      Text("PKR $totalAmount", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                    if (person != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Builder(
                            builder: (context) {
                              bool isUdhaar = previousBalance < 0; // Standardized: Negative = Udhaar
                              String label = isUdhaar ? "Previous Udhaar:" : (previousBalance == 0 ? "Previous Balance:" : "Available Jamah:");
                              Color statusColor = isUdhaar ? Colors.red : Colors.green;
                              return Text(
                                label,
                                style: TextStyle(fontSize: 13, color: previousBalance == 0 ? Colors.black54 : statusColor),
                              );
                            }
                          ),
                          Text(
                            "PKR ${previousBalance.abs().toStringAsFixed(0)}",
                            style: TextStyle(
                              fontSize: 13, 
                              fontWeight: FontWeight.bold, 
                              color: previousBalance < 0 ? Colors.red : (previousBalance == 0 ? Colors.black : Colors.green)
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Net Total:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
                        Text("PKR ${netTotal.toStringAsFixed(0)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
                      ],
                    ),
                  ],
                  const Divider(height: 30),
                  _radioTile(
                    "Cash (Full Pay)",
                    "Cash",
                    paymentMode,
                    (v) => setPayState(() => paymentMode = v!),
                  ),
                  _radioTile(
                    "Credit (Udhaar)",
                    "Credit",
                    paymentMode,
                    (v) => setPayState(() => paymentMode = v!),
                  ),
                  _radioTile(
                    "Split (Partial)",
                    "Split",
                    paymentMode,
                    (v) => setPayState(() => paymentMode = v!),
                  ),
                  if (paymentMode == "Split")
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextField(
                        controller: _paidController,
                        onChanged: (_) => setPayState(() {}),
                        decoration: const InputDecoration(
                          labelText: "Amount Paid",
                          prefixIcon: Icon(Icons.money),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  const SizedBox(height: 10),
                  // Show what happens after payment
                  Builder(
                    builder: (context) {
                      double willPay = 0;
                      if (paymentMode == "Cash") {
                        willPay = cashPayable;
                      } else if (paymentMode == "Credit") {
                        willPay = 0;
                      } else {
                        willPay = paid;
                      }
                      double newBalance = netTotal - willPay;
                      // Standardized Convention: Negative newBalance means they owe us (Udhaar).
                      bool isUdhaar = newBalance < 0; 
                      
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isUdhaar ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Paying:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text("PKR ${willPay.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isUdhaar ? "Remaining Udhaar:" : "Available Jamah:",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isUdhaar ? Colors.red : Colors.green),
                                ),
                                Text(
                                  "PKR ${newBalance.abs().toStringAsFixed(0)}",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: isUdhaar ? Colors.red : Colors.green, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Back"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String finalMode = paymentMode;
                    // Cash = pay the net total (bill + previous balance)
                    // Credit = pay nothing
                    // Split = pay whatever user entered
                    double finalPaid = (finalMode == "Cash")
                        ? cashPayable
                        : (finalMode == "Credit" ? 0 : paid);
                    await _finalizeSale(
                      totalAmount,
                      finalPaid,
                      finalMode,
                      person,
                      items,
                      role,
                    );
                    if (!mounted) return;
                    Navigator.pop(context); // Close Payment Dialog
                    Navigator.pop(context); // Close Bill Dialog
                  },
                  child: const Text("Complete Sale"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _finalizeSale(
    double totalBill,
    double paidAmount,
    String pMode,
    Map<String, dynamic>? person,
    List<Map<String, dynamic>> items,
    String role,
  ) async {
    try {
      String currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
      String invUid = (math.Random().nextInt(90000000) + 10000000).toString();

      double totalProfit = items.fold(0.0, (sum, item) {
        double cost =
            double.tryParse(item['cost_per_meter']?.toString() ?? '0') ?? 0.0;
        double sale =
            double.tryParse(item['per_meter_price']?.toString() ?? '0') ?? 0.0;
        double meters =
            double.tryParse(item['total_meters']?.toString() ?? '0') ?? 0.0;
        return sum + ((sale - cost) * meters);
      });

      // 1. Save Header Record
      await SellingDB.getInstance.addSelling(
        name: _nameController.text,
        uid: "BILL_$invUid",
        totalMeter: items.fold(
          0.0,
          (sum, item) =>
              sum +
              (double.tryParse(item['total_meters']?.toString() ?? '0') ?? 0.0),
        ),
        perMeterPrice: 0,
        totalPrice: totalBill,
        totalProfit: totalProfit,
        date: currentDate,
        paymentMode: pMode, // Use chosen mode
        previousBalance:
            double.tryParse(person?['obalance']?.toString() ?? '0.0') ?? 0.0,
      );

      // 2. Save Item Details & Update Stock
      for (var item in items) {
        await SaleDB.getInstance.addSale(
          invUid: invUid,
          name: item['name'],
          than: item['than'],
          meter: item['meter'],
          perMeterAmount: item['per_meter_price'],
          costPrice: item['cost_per_meter'],
          totalAmount: item['total'],
          date: currentDate,
        );

        if (item['stock_id'] != null) {
          // Use a safe search to prevent "No element" crash
          final stockItem = _allStock.cast<Map<String, dynamic>?>().firstWhere(
            (s) => s?['id'] == item['stock_id'],
            orElse: () => null,
          );

          if (stockItem != null) {
            double currentMeters =
                double.tryParse(stockItem['total_meter']?.toString() ?? '0') ??
                0;
            int currentThan =
                int.tryParse(stockItem['than']?.toString() ?? '0') ?? 0;
            double remainingMeters =
                currentMeters -
                (double.tryParse(item['total_meters']?.toString() ?? '0') ?? 0);
            int remainingThan =
                currentThan -
                (int.tryParse(item['than']?.toString() ?? '1') ?? 1);

            await SellingDB.getInstance.updateStockMeters(
              item['stock_id'],
              remainingMeters,
              remainingThan > 0 ? remainingThan : 0,
            );
          }
        }
      }

      // 3. RESTORE SYNC: Update Balance & Ledger
      if (person != null && person['uid'] != null) {
        String pUid = person['uid'].toString();
        double currentBalance = 0;
        if (role == "Vendor") {
          currentBalance = double.tryParse(person['balance']?.toString() ?? '0') ?? 0;
        } else {
          currentBalance = double.tryParse(person['obalance']?.toString() ?? '0') ?? 0;
        }
        // Standardized Negative convention: paying LESS than bill takes balance towards negative (Udhaar)
        double balanceChange = paidAmount - totalBill;
        
        if (role == "Customer") {
          // Update main customer balance
          if (balanceChange != 0) {
            double newBalance = currentBalance + balanceChange;
            await BCustomer.getInstance.updateCustomerBalance(
              pUid,
              newBalance.toString(),
            );
          }

          // SYNC OPENING BALANCE
          await BCustomerLedgerDB.getInstance.syncOpeningBalance(
            pUid,
            person['obalance']?.toString() ?? '0',
            currentDate,
          );

          // RECORD IN CUSTOMER LEDGER
          final prevTransactions = await BCustomerLedgerDB.getInstance.getTransactions(pUid);
          double lastBalance = 0;
          if (prevTransactions.isNotEmpty) {
            lastBalance = double.tryParse(prevTransactions.first[BCustomerLedgerDB.C_credit]?.toString() ?? '0') ?? 0;
          } else {
            lastBalance = double.tryParse(person['obalance']?.toString() ?? '0') ?? 0;
          }

          double billImpact = paidAmount - totalBill;
          double newRunningBalance = lastBalance + billImpact;

          await BCustomerLedgerDB.getInstance.addTransaction(pUid, {
            BCustomerLedgerDB.C_invoice_id: invUid,
            BCustomerLedgerDB.C_item: "Sale Bill #$invUid",
            BCustomerLedgerDB.C_meter: items.fold(0.0, (s, i) => s + (double.tryParse(i['total_meters']?.toString() ?? '0') ?? 0)).toString(),
            BCustomerLedgerDB.C_than: items.fold(0, (s, i) => s + (int.tryParse(i['than']?.toString() ?? '0') ?? 0)).toString(),
            BCustomerLedgerDB.C_total: totalBill.toString(),
            BCustomerLedgerDB.C_type: newRunningBalance < 0 ? "Udhaar" : "Jamah",
            BCustomerLedgerDB.C_date: currentDate,
            BCustomerLedgerDB.C_paid: paidAmount.toString(),
            BCustomerLedgerDB.C_credit: newRunningBalance.toString(),
          });
        } else if (role == "Vendor") {
          String vendorName = person['name'] ?? '';

          // Cleanup any NULL rows first
          await Bvendername.getInstance.cleanupNullRows(vendorName);

          // SYNC OPENING BALANCE (only inserts if no OPENING_BAL row exists and balance != 0)
          await Bvendername.getInstance.syncOpeningBalance(
            vendorName,
            person['balance']?.toString() ?? '0',
            currentDate,
          );

          // RECORD IN VENDOR LEDGER (ALLVENDERLEedger)
          // Running balance: previousBalance + (paidAmount - totalBill)
          double previousVendorBalance = await Bvendername.getInstance.getRunningBalance(vendorName);
          double vendorBillImpact = paidAmount - totalBill;
          double newVendorRunningBalance = previousVendorBalance + vendorBillImpact;

          await Bvendername.getInstance.addLedgerEntry(vendorName, {
            'name': "Sale Bill #$invUid",
            'uid': invUid,
            'date': currentDate,
            'totalmeter': items.fold(0.0, (s, i) => s + (double.tryParse(i['total_meters']?.toString() ?? '0') ?? 0.0)),
            'total_price': totalBill,
            'per_meter': items.isNotEmpty ? (double.tryParse(items.first['per_meter_price']?.toString() ?? '0') ?? 0) : 0,
            'debit': newVendorRunningBalance,
            'cash': paidAmount,
          });

          // Update main vendor balance with live running balance from ledger
          double liveBalance = await Bvendername.getInstance.getRunningBalance(vendorName);
          await Bvendor.getInstance.updateVendorBalance(
            pUid,
            liveBalance.toString(),
          );
        }
        
        // 4. Log Split/Credit breakdown for global reporting (Fetched directly from DB for 100% accuracy)
        if (role == "Customer") {
          final List<Map<String, dynamic>> latestTx = await BCustomerLedgerDB.getInstance.getTransactions(pUid);
          if (latestTx.isNotEmpty) {
            final Map<String, dynamic> dbRecord = latestTx.first;
            final double finalTotal = double.tryParse(dbRecord[BCustomerLedgerDB.C_total]?.toString() ?? '0') ?? 0;
            final double finalPaid = double.tryParse(dbRecord[BCustomerLedgerDB.C_paid]?.toString() ?? '0') ?? 0;
            final double finalDebit = double.tryParse(dbRecord[BCustomerLedgerDB.C_credit]?.toString() ?? '0') ?? 0;
            
            await SplitPaymentDB.getInstance.addSplitRecord(
              name: _nameController.text,
              suid: invUid,
              debit: finalDebit,
              cash: finalPaid,
              total: finalTotal,
              tableName: 'selling',
              date: currentDate,
            );
          }
        } else if (role == "Vendor") {
          final vendorName = person['name'] ?? '';
          final List<Map<String, dynamic>> latestTx = await Bvendername.getInstance.getLedgerEntries(vendorName);
          if (latestTx.isNotEmpty) {
            final Map<String, dynamic> dbRecord = latestTx.first;
            final double finalTotal = (dbRecord['total_price'] as num?)?.toDouble() ?? 0;
            final double finalPaid = (dbRecord['cash'] as num?)?.toDouble() ?? 0;
            final double finalDebit = (dbRecord['debit'] as num?)?.toDouble() ?? 0;
            
            await SplitPaymentDB.getInstance.addSplitRecord(
              name: vendorName,
              suid: invUid,
              debit: finalDebit,
              cash: finalPaid,
              total: finalTotal,
              tableName: 'selling',
              date: currentDate,
            );
          }
        }
      }

      await _loadDatabaseData();
    } catch (e) {
      debugPrint("Error finalizing sale: $e");
    }
  }

  Widget _summaryMiniCard(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          "PKR ${value.toStringAsFixed(0)}",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedItemCard(
    Map<String, dynamic> item,
    VoidCallback onClear,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item['name'].toString().toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 18, color: Colors.red),
              ),
            ],
          ),
          _infoRow(Icons.qr_code, "UID: ${item['uid']}"),
          _infoRow(Icons.inventory, "Available: ${item['total_meter']} Meters"),
        ],
      ),
    );
  }

  Widget _buildSelectedPersonCard(
    Map<String, dynamic> person,
    VoidCallback onClear,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                person['name'].toString().toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 18, color: Colors.red),
              ),
            ],
          ),
          _infoRow(Icons.phone, "Phone: ${person['phone'] ?? 'No Contact'}"),
          _infoRow(
            Icons.location_on,
            "Address: ${person['address'] ?? 'No Address'}",
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );

  Widget _summaryRow(String label, double value, Color color) {
    bool isNegative = value < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          Text(
            "${isNegative ? '-' : ''}PKR ${value.abs().toStringAsFixed(0)}",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
    ),
  );

  Widget _radioTile(
    String title,
    String val,
    String group,
    Function(String?)? onChange,
  ) => Row(
    children: [
      Radio<String>(
        value: val,
        groupValue: group,
        onChanged: onChange,
        activeColor: Colors.indigo,
      ),
      Text(title, style: const TextStyle(fontSize: 12)),
    ],
  );

  void _showBillDetails(Map<String, dynamic> bill) async {
    String invId = bill['uid'].toString().replaceFirst('BILL_', '');
    final saleItems = await SaleDB.getInstance.getSalesByInvoice(invId);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Invoice #$invId",
                    style: const TextStyle(
                      color: Colors.indigo,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "${bill['name']} | ${bill['date']}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.red),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: saleItems.length,
                    itemBuilder: (context, i) {
                      final item = saleItems[i];
                      return ListTile(
                        dense: true,
                        title: Text(
                          item['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "${item['than']} Than x ${item['meter']} Mtr | @${item['per_meter_amount']}",
                        ),
                        trailing: Text(
                          "PKR ${item['total_amount']}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Grand Total:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "PKR ${bill['total_price']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: (_startDate != null && _endDate != null)
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.indigo,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> displayedBills = _allBills;
    if (_startDate != null && _endDate != null) {
      displayedBills = _allBills.where((bill) {
        try {
          DateTime billDate = DateFormat('dd-MM-yyyy').parse(bill['date']);
          DateTime s = DateTime(
            _startDate!.year,
            _startDate!.month,
            _startDate!.day,
          );
          DateTime e = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
          DateTime b = DateTime(billDate.year, billDate.month, billDate.day);
          return b.isAtSameMomentAs(s) ||
              b.isAtSameMomentAs(e) ||
              (b.isAfter(s) && b.isBefore(e));
        } catch (_) {
          return false;
        }
      }).toList();
    }

    double totalSalesInView = displayedBills.fold(
      0.0,
      (sum, b) =>
          sum + (double.tryParse(b['total_price']?.toString() ?? '0') ?? 0.0),
    );
    double totalProfitInView = displayedBills.fold(
      0.0,
      (sum, b) =>
          sum + (double.tryParse(b['total_profit']?.toString() ?? '0') ?? 0.0),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade800, Colors.indigo.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          "Sales & Billing",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: () => _selectDateRange(context),
                          icon: Icon(
                            Icons.calendar_month,
                            color: (_startDate != null)
                                ? Colors.indigo.shade100
                                : Colors.white70,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _showNewBillPopup,
                      child: rowbutton(
                        "New Bill",
                        CupertinoIcons.cart_fill_badge_plus,
                      ),
                    ),
                  ],
                ),
                if (_startDate != null && _endDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _summaryMiniCard(
                              "Sales",
                              totalSalesInView,
                              Colors.greenAccent,
                            ),
                            const SizedBox(width: 15),
                            _summaryMiniCard(
                              "Profit",
                              totalProfitInView,
                              Colors.white,
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "From: ${DateFormat('dd-MM').format(_startDate!)} to ${DateFormat('dd-MM').format(_endDate!)}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 5),
                              GestureDetector(
                                onTap: () => setState(() {
                                  _startDate = null;
                                  _endDate = null;
                                }),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: displayedBills.isEmpty
                ? const Center(
                    child: Text(
                      "No bills found for this period",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: displayedBills.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final bill = displayedBills[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.05),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.receipt_long,
                              color: Colors.indigo.shade700,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            bill['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            "Inv #: ${bill['uid'].toString().replaceFirst('BILL_', '')}",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 10,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "PKR ${bill['total_price']}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    bill['date'],
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 4),
                              SizedBox(
                                width: 30,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.print,
                                    color: Colors.indigo,
                                    size: 18,
                                  ),
                                  onPressed: () async {
                                    final saleItems = await SaleDB.getInstance
                                        .getSalesByInvoice(
                                          bill['uid'].toString().replaceFirst(
                                            'BILL_',
                                            '',
                                          ),
                                        );
                                    final path = await BillPrinter.printA5Bill(
                                      customer: {'name': bill['name']},
                                      items: saleItems,
                                      invoiceId: bill['uid']
                                          .toString()
                                          .replaceFirst('BILL_', ''),
                                      date: bill['date'],
                                      paymentMode:
                                          bill['payment_mode'] ?? 'Sales',
                                      previousBalance:
                                          double.tryParse(
                                            bill['previous_balance']
                                                    ?.toString() ??
                                                '0',
                                          ) ??
                                          0,
                                      totalAmount:
                                          double.tryParse(
                                            bill['total_price']?.toString() ??
                                                '0',
                                          ) ??
                                          0,
                                    );
                                    if (mounted &&
                                        path != null &&
                                        path.isNotEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Bill PDF saved to: $path",
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                              if (bill['name'] != null) ...[
                                SizedBox(
                                  width: 30,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.message,
                                      color: Colors.green,
                                      size: 18,
                                    ),
                                    onPressed: () async {
                                      String phone = "";
                                      final foundCustomer = _allCustomers.where(
                                        (c) => c['name'] == bill['name'],
                                      );
                                      if (foundCustomer.isNotEmpty)
                                        phone =
                                            foundCustomer.first['phone'] ?? "";
                                      if (phone.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "No phone number found for this customer",
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      final saleItems = await SaleDB.getInstance
                                          .getSalesByInvoice(
                                            bill['uid'].toString().replaceFirst(
                                              'BILL_',
                                              '',
                                            ),
                                          );
                                      final pdfPath =
                                          await BillPrinter.printA5Bill(
                                            customer: {'name': bill['name']},
                                            items: saleItems,
                                            invoiceId: bill['uid']
                                                .toString()
                                                .replaceFirst('BILL_', ''),
                                            date: bill['date'],
                                            paymentMode:
                                                bill['payment_mode'] ?? 'Sales',
                                            previousBalance:
                                                double.tryParse(
                                                  bill['previous_balance']
                                                          ?.toString() ??
                                                      '0',
                                                ) ??
                                                0,
                                            totalAmount:
                                                double.tryParse(
                                                  bill['total_price']
                                                          ?.toString() ??
                                                      '0',
                                                ) ??
                                                0,
                                          );

                                      if (pdfPath != null) {
                                        await Clipboard.setData(
                                          ClipboardData(text: pdfPath),
                                        );
                                        String cleanPhone = phone.replaceAll(
                                          RegExp(r'[^0-9]'),
                                          '',
                                        );
                                        if (!cleanPhone.startsWith('92') &&
                                            cleanPhone.startsWith('0'))
                                          cleanPhone =
                                              '92${cleanPhone.substring(1)}';
                                        String message =
                                            "Hello ${bill['name']}, your bill for PKR ${bill['total_price']} is ready. The PDF path has been copied to my clipboard. Opening chat...";
                                        final url =
                                            "https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}";
                                        if (await canLaunchUrl(Uri.parse(url)))
                                          await launchUrl(
                                            Uri.parse(url),
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                          onTap: () => _showBillDetails(bill),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
