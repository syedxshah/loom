import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loom/backend/homebackend/operations/cloth_db.dart';
import 'package:loom/backend/homebackend/vendor/speratevenderlist_in_purchaing.dart';
import 'package:loom/backend/homebackend/operations/selling.dart';
import 'package:loom/backend/homebackend/vendor/bvendername.dart';
import 'package:loom/backend/homebackend/vendor/bvendor.dart';
import 'package:loom/backend/homebackend/operations/khisab.dart';
import 'package:loom/backend/homebackend/operations/split_payment_db.dart';
import 'package:loom/screens/Home/vendor/purchaing_vendor/process_tracking_panel.dart';

Widget purchasingseprate(String uid, VoidCallback onBack) {
  return DetailsProcessPurchasing(uid: uid, onBack: onBack);
}

class DetailsProcessPurchasing extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;
  const DetailsProcessPurchasing({
    super.key,
    required this.uid,
    required this.onBack,
  });

  @override
  State<DetailsProcessPurchasing> createState() =>
      _DetailsProcessPurchasingState();
}

class _DetailsProcessPurchasingState extends State<DetailsProcessPurchasing> {
  final thanController = TextEditingController(text: "1");
  final meterController = TextEditingController();
  final priceController = TextEditingController();
  final biltiController = TextEditingController(text: "0");
  final clothSearchController = TextEditingController();
  final cashController = TextEditingController(text: "0");
  final creditController = TextEditingController(text: "0");

  String selectedCondition = "Grey";
  String paymentMode = "Split";
  String filterStatus = "All";

  List<Map<String, dynamic>> clothList = [];
  List<Map<String, dynamic>> currentStock = [];
  String vendorName = "Loading...";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    final cloths = await Bcloth.getInstance.getAllCloths();
    final stock = await SperatevenderlistInPurchaing.getInstance.getVendorStock(
      widget.uid,
    );

    // Fetch vendor name from ID
    final vendors = await Bvendor.getInstance.getAllVendors();
    final currentVendor = vendors.firstWhere(
      (v) => v['uid'].toString() == widget.uid,
      orElse: () => {'name': widget.uid},
    );

    setState(() {
      clothList = cloths;
      currentStock = stock;
      vendorName = currentVendor['name'];
      isLoading = false;
    });
  }

  Future<void> _refresh() async {
    final stock = await SperatevenderlistInPurchaing.getInstance.getVendorStock(
      widget.uid,
    );
    final cloths = await Bcloth.getInstance.getAllCloths();
    setState(() {
      currentStock = stock;
      clothList = cloths;
    });
  }

  List<Map<String, dynamic>> get filteredStock {
    final validStock = currentStock.where((item) {
      final condition = item['condition']?.toString() ?? "";
      return condition == "Grey" || condition == "Ready";
    }).toList();

    if (filterStatus == "All") return validStock;
    return validStock
        .where((item) => item['condition'] == filterStatus)
        .toList();
  }

  void _showDetailsPopup(Map<String, dynamic> item) {
    bool isReady = item['condition'] == "Ready";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Invoice: ${item['id']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Colors.blueGrey,
                        ),
                      ),
                      Text(
                        "Date: ${item['date']}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      const Divider(height: 30),
                      _detailTile("Cloth", item['cloth_name']),
                      _detailTile(
                        "Quantity",
                        "${item['than']} Than / ${item['meter']} Mtr",
                      ),
                      _detailTile("Rate", "Rs. ${item['price_per_meter']}"),
                      _detailTile("Bilti", "Rs. ${item['bilti_per_meter']}"),
                      _detailTile("Condition", item['condition']),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _summaryRow("Cash Paid", "Rs. ${item['cash']}"),
                            const SizedBox(height: 5),
                            _summaryRow("Credit", "Rs. ${item['credit']}"),
                            const Divider(),
                            _summaryRow(
                              "Net Total",
                              "Rs. ${item['total'].toStringAsFixed(0)}",
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                          ),
                          child: const Text(
                            "Close",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(width: 1, color: Colors.grey.shade200),
              Expanded(
                flex: 7,
                child: Container(
                  color: const Color(0xFFFAFAFA),
                  child: isReady
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 80,
                                color: Colors.green.shade400,
                              ),
                              const SizedBox(height: 15),
                              const Text(
                                "This Stock is Ready",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const Text(
                                "No further processing required.",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ProcessTrackingPanel(
                          totalMeters:
                              double.tryParse(item['meter'].toString()) ?? 0.0,
                          suid: item['uid'].toString(),
                          id: item['id'].toString(),
                          clothName: item['cloth_name'] ?? "",
                          vendorName: item['vendor_name'] ?? "",
                          originalPricePerMeter:
                              double.tryParse(
                                item['price_per_meter'].toString(),
                              ) ??
                              0.0,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? Colors.green.shade800 : Colors.black,
          ),
        ),
      ],
    );
  }

  void _showAddStockPopup() async {
    String nextId = await SperatevenderlistInPurchaing.getInstance.getNextId(
      widget.uid,
    );
    String currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    thanController.text = "1";
    meterController.clear();
    priceController.clear();
    biltiController.text = "0";
    clothSearchController.clear();
    cashController.text = "0";
    creditController.text = "0";
    paymentMode = "Split";

    // Fetch vendor's previous balance from ledger DB
    double previousBalance = await Bvendername.getInstance.getRunningBalance(vendorName);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) {
          double total =
              (double.tryParse(thanController.text) ?? 0) *
              (double.tryParse(meterController.text) ?? 0) *
              ((double.tryParse(priceController.text) ?? 0) +
                  (double.tryParse(biltiController.text) ?? 0));

          void updateBal(String field, String val) {
            double input = double.tryParse(val) ?? 0;
            if (paymentMode == "Split") {
              setPopupState(() {
                if (field == "cash") {
                  double rem = total - input;
                  creditController.text = rem < 0
                      ? "0"
                      : rem.toStringAsFixed(0);
                } else {
                  double rem = total - input;
                  cashController.text = rem < 0 ? "0" : rem.toStringAsFixed(0);
                }
              });
            }
          }

          if (paymentMode == "Cash") {
            cashController.text = total.toStringAsFixed(0);
            creditController.text = "0";
          } else if (paymentMode == "Credit") {
            cashController.text = "0";
            creditController.text = total.toStringAsFixed(0);
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Add Purchase"),
                Text(
                  "Total: ${total.toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Autocomplete<String>(
                      optionsBuilder: (val) => clothList
                          .map((c) => c['name'].toString())
                          .where(
                            (n) => n.toLowerCase().contains(
                              val.text.toLowerCase(),
                            ),
                          ),
                      onSelected: (s) => clothSearchController.text = s,
                      fieldViewBuilder: (ctx, ctrl, fNode, onSub) {
                        if (clothSearchController.text != ctrl.text &&
                            clothSearchController.text.isNotEmpty)
                          ctrl.text = clothSearchController.text;
                        return TextField(
                          controller: ctrl,
                          focusNode: fNode,
                          onChanged: (v) => clothSearchController.text = v,
                          decoration: const InputDecoration(
                            labelText: "Select Cloth",
                            prefixIcon: Icon(Icons.search),
                          ),
                        );
                      },
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInput(
                            thanController,
                            "Than",
                            Icons.numbers,
                            setPopupState,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildInput(
                            meterController,
                            "Meters",
                            Icons.straighten,
                            setPopupState,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInput(
                            priceController,
                            "Rate",
                            Icons.payments,
                            setPopupState,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildInput(
                            biltiController,
                            "Bilti/Mtr",
                            Icons.local_shipping,
                            setPopupState,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),
                    // --- Previous Balance Display ---
                    if (total > 0)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: previousBalance < 0
                              ? Colors.red.withOpacity(0.06)
                              : previousBalance > 0
                                  ? Colors.green.withOpacity(0.06)
                                  : Colors.grey.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: previousBalance < 0
                                ? Colors.red.withOpacity(0.2)
                                : previousBalance > 0
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.15),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  previousBalance < 0 ? "Previous Udhaar:" : previousBalance > 0 ? "Previous Jamah:" : "Previous Balance:",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: previousBalance < 0 ? Colors.red : previousBalance > 0 ? Colors.green : Colors.grey,
                                  ),
                                ),
                                Text(
                                  "Rs. ${previousBalance.abs().toStringAsFixed(0)}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: previousBalance < 0 ? Colors.red : previousBalance > 0 ? Colors.green : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Net Total:",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                                Text(
                                  "Rs. ${(total - previousBalance).toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const Text(
                      "Payment Mode",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    CupertinoSlidingSegmentedControl<String>(
                      groupValue: paymentMode,
                      children: const {
                        "Cash": Text("Cash"),
                        "Credit": Text("Credit"),
                        "Split": Text("Split"),
                      },
                      onValueChanged: (v) =>
                          setPopupState(() => paymentMode = v!),
                    ),
                    const SizedBox(height: 10),
                    if (paymentMode != "Credit")
                      _buildInput(
                        cashController,
                        "Cash Paid",
                        Icons.money,
                        setPopupState,
                        onChanged: (v) => updateBal("cash", v),
                      ),
                    if (paymentMode != "Cash")
                      _buildInput(
                        creditController,
                        "Credit Amount",
                        Icons.account_balance_wallet,
                        setPopupState,
                        onChanged: (v) => updateBal("credit", v),
                      ),
                    const SizedBox(height: 20),
                    const Text(
                      "Initial Condition",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    CupertinoSlidingSegmentedControl<String>(
                      groupValue: selectedCondition,
                      children: const {
                        "Grey": Text("Grey"),
                        "Ready": Text("Ready"),
                      },
                      onValueChanged: (v) =>
                          setPopupState(() => selectedCondition = v!),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  String enteredCloth = clothSearchController.text.trim();
                  if (enteredCloth.isEmpty) return;
                  bool clothExists = clothList.any(
                    (c) =>
                        c['name'].toString().toLowerCase() ==
                        enteredCloth.toLowerCase(),
                  );
                  if (!clothExists) {
                    bool? shouldSave = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Cloth Not Found"),
                        content: Text(
                          "'$enteredCloth' does not exist. Add it to database and continue?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text("No"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text("Yes, Add"),
                          ),
                        ],
                      ),
                    );
                    if (shouldSave == true) {
                      await Bcloth.getInstance.addCloth(enteredCloth);
                    } else {
                      return;
                    }
                  }

                  if (selectedCondition == "Ready") {
                    double than = double.tryParse(thanController.text) ?? 0;
                    double meter = double.tryParse(meterController.text) ?? 0;
                    double rate = double.tryParse(priceController.text) ?? 0;
                    double bilti = double.tryParse(biltiController.text) ?? 0;

                    await SellingDB.getInstance.addSelling(
                      name: enteredCloth,
                      uid: "${widget.uid}-$nextId",
                      totalMeter: than * meter,
                      perMeterPrice: rate + bilti,
                      totalPrice: total,
                      date: currentDate,
                    );
                  }

                  await SperatevenderlistInPurchaing.getInstance.addStock({
                    'id': "INV${nextId}",
                    'cloth_name': enteredCloth,
                    'vendor_name': widget.uid,
                    'uid': nextId,
                    'suid': nextId,
                    'date': currentDate,
                    'than': int.parse(thanController.text),
                    'meter': double.parse(meterController.text),
                    'price_per_meter': double.parse(priceController.text),
                    'bilti_per_meter':
                        double.tryParse(biltiController.text) ?? 0,
                    'total': total,
                    'cash': double.tryParse(cashController.text) ?? 0,
                    'credit': double.tryParse(creditController.text) ?? 0,
                    'type': paymentMode,
                    'condition': selectedCondition,
                    'p_or_r': 'purchased',
                  }, widget.uid);

                  // --- RUNNING BALANCE LOGIC (same as selling flow) ---
                  // 1. Sync Opening Balance (only inserts if no OPENING_BAL row exists)
                  final allVendors = await Bvendor.getInstance.getAllVendors();
                  final thisVendor = allVendors.firstWhere(
                    (v) => v['uid'].toString() == widget.uid,
                    orElse: () => {'balance': '0'},
                  );
                  await Bvendername.getInstance.syncOpeningBalance(
                    vendorName,
                    thisVendor['balance']?.toString() ?? '0',
                    currentDate,
                  );

                  // 2. Fetch previous running balance from ledger
                  double previousBalance = await Bvendername.getInstance.getRunningBalance(vendorName);

                  // 3. Calculate running balance
                  // cashPaid = what we actually paid the vendor now
                  double cashPaid = double.tryParse(cashController.text) ?? 0;
                  // billImpact = paid - bill (negative means we owe more, positive means advance)
                  double billImpact = cashPaid - total;
                  double newRunningBalance = previousBalance + billImpact;

                  // 4. Record in Vendor Ledger
                  await Bvendername.getInstance.addLedgerEntry(vendorName, {
                    'name': enteredCloth,
                    'date': currentDate,
                    'uid': nextId,
                    'totalmeter':
                        (double.tryParse(thanController.text) ?? 0) *
                        (double.tryParse(meterController.text) ?? 0),
                    'total_price': total,
                    'per_meter':
                        (double.tryParse(priceController.text) ?? 0) +
                        (double.tryParse(biltiController.text) ?? 0),
                    'cash': cashPaid,
                    'debit': newRunningBalance,
                  });
                  
                  // 5. Update Master Vendor Balance with new running balance
                  double liveBalance = await Bvendername.getInstance.getRunningBalance(vendorName);
                  await Bvendor.getInstance.updateVendorBalance(
                    widget.uid,
                    liveBalance.toString(),
                  );
                  
                  // 6. Add to General Hisab Table
                  await KHisabDB.getInstance.addHisab(
                    name: enteredCloth,
                    description: "Purchasing from $vendorName on $currentDate",
                    amount: total,
                    condition: "purchased",
                    date: currentDate,
                  );

                  // 7. Log Split/Credit breakdown for global reporting (Fetched directly from DB for 100% accuracy)
                  final List<Map<String, dynamic>> latestTx = await Bvendername.getInstance.getLedgerEntries(vendorName);
                  if (latestTx.isNotEmpty) {
                    final Map<String, dynamic> dbRecord = latestTx.first;
                    final double finalTotal = (dbRecord['total_price'] as num?)?.toDouble() ?? 0;
                    final double finalPaid = (dbRecord['cash'] as num?)?.toDouble() ?? 0;
                    final double finalDebit = (dbRecord['debit'] as num?)?.toDouble() ?? 0;
                    
                    await SplitPaymentDB.getInstance.addSplitRecord(
                      name: vendorName,
                      suid: nextId,
                      debit: finalDebit,
                      cash: finalPaid,
                      total: finalTotal,
                      tableName: 'purchasing',
                      date: currentDate,
                    );
                  } else {
                    // Fallback to UI values if DB fetch fails
                    await SplitPaymentDB.getInstance.addSplitRecord(
                      name: vendorName,
                      suid: nextId,
                      debit: double.tryParse(creditController.text) ?? 0,
                      cash: cashPaid,
                      total: total,
                      tableName: 'purchasing',
                      date: currentDate,
                    );
                  }

                  Navigator.pop(context);
                  _refresh();
                },
                child: const Text("Save Entry"),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInput(
    TextEditingController ctrl,
    String lbl,
    IconData icon,
    StateSetter setState, {
    Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
        controller: ctrl,
        onChanged: (v) {
          setState(() {});
          if (onChanged != null) onChanged(v);
        },
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: lbl,
          prefixIcon: Icon(icon, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayList = filteredStock;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(10, 40, 20, 20),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vendorName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                            ),
                          ),
                          const Text(
                            "Purchasing Log",
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showAddStockPopup,
                      icon: const Icon(Icons.add),
                      label: const Text("New Entry"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                CupertinoSlidingSegmentedControl<String>(
                  groupValue: filterStatus,
                  backgroundColor: Colors.grey.shade100,
                  thumbColor: Colors.white,
                  children: {
                    "All": _filterLabel("All", Icons.list_alt),
                    "Grey": _filterLabel("Grey", Icons.blur_on),
                    "Ready": _filterLabel("Ready", Icons.check_circle_outline),
                  },
                  onValueChanged: (v) => setState(() => filterStatus = v!),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayList.isEmpty
                ? const Center(
                    child: Text(
                      "No entries found",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: displayList.length,
                    itemBuilder: (context, index) {
                      final item = displayList[index];
                      bool isGrey = item['condition'] == "Grey";

                      return InkWell(
                        onTap: () => _showDetailsPopup(item),
                        child: Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(
                              color: isGrey
                                  ? Colors.orange.shade100
                                  : Colors.green.shade100,
                              width: 1.5,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: isGrey
                                  ? Colors.orange.withOpacity(0.02)
                                  : Colors.green.withOpacity(0.02),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isGrey
                                    ? Colors.orange.shade50
                                    : Colors.green.shade50,
                                child: Icon(
                                  isGrey ? Icons.hourglass_top : Icons.task_alt,
                                  color: isGrey
                                      ? Colors.orange.shade700
                                      : Colors.green.shade700,
                                ),
                              ),
                              title: Text(
                                item['cloth_name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                "${item['than']} Than | ${item['meter']} Mtr",
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              trailing: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 100,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        "PKR ${item['total'].toStringAsFixed(0)}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    _buildBadge(item['condition']),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterLabel(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 5), Text(text)],
      ),
    );
  }

  Widget _buildBadge(String status) {
    bool isGrey = status == "Grey";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isGrey ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isGrey ? Colors.orange.shade200 : Colors.green.shade200,
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w900,
          color: isGrey ? Colors.orange.shade800 : Colors.green.shade800,
        ),
      ),
    );
  }
}
