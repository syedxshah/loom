import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loom/widget/rowbutton.dart';
import 'package:loom/backend/homebackend/operations/return_db.dart';
import 'package:loom/backend/homebackend/operations/selling.dart';
import 'package:loom/backend/homebackend/operations/sale.dart';
import 'package:loom/backend/homebackend/operations/khisab.dart';

Widget Damage(BuildContext context) {
  return const ReturnDamagePage();
}

class ReturnDamagePage extends StatefulWidget {
  const ReturnDamagePage({super.key});

  @override
  State<ReturnDamagePage> createState() => _ReturnDamagePageState();
}

class _ReturnDamagePageState extends State<ReturnDamagePage> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    final data = await ReturnDB.getInstance.getAllReturns();
    setState(() {
      _records = data;
      _isLoading = false;
    });
  }

  void _showAddPopup() {
    final uidController = TextEditingController();
    final nameController = TextEditingController();
    final meterController = TextEditingController();
    final priceController = TextEditingController();
    final reasonController = TextEditingController();
    String type = "Return"; 
    bool isDataFetched = false;
    double _selectedCostPrice = 0;
    List<Map<String, dynamic>>? multipleItemsFromInvoice;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(CupertinoIcons.arrow_2_squarepath, color: Colors.blue.shade700),
                const SizedBox(width: 10),
                const Text("New Return / Damage", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // UID with Search
                    Row(
                      children: [
                        Expanded(
                          child: _popupField(
                            uidController, 
                            "Enter UID to Search", 
                            CupertinoIcons.qrcode,
                            readOnly: isDataFetched || multipleItemsFromInvoice != null,
                          ),
                        ),
                        if (!isDataFetched && multipleItemsFromInvoice == null) ...[
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: () async {
                              final uid = uidController.text.trim();
                              if (uid.isEmpty) return;

                              bool isNumeric = RegExp(r'^[0-9]+$').hasMatch(uid);

                              if (isNumeric) {
                                final salesList = await SaleDB.getInstance.getSalesByInvoice(uid);
                                if (salesList.isNotEmpty) {
                                  setPopupState(() {
                                    if (salesList.length == 1) {
                                      final result = salesList.first;
                                      nameController.text = result[SaleDB.C_NAME] ?? "";
                                      meterController.text = result[SaleDB.C_METER]?.toString() ?? "";
                                      priceController.text = result[SaleDB.C_PER_METER_AMOUNT]?.toString() ?? "";
                                      _selectedCostPrice = double.tryParse(result[SaleDB.C_COST_PRICE]?.toString() ?? '0') ?? 0;
                                      isDataFetched = true;
                                    } else {
                                      multipleItemsFromInvoice = salesList;
                                    }
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Invoice UID '$uid' not found in Sale history")),
                                  );
                                }
                              } else {
                                final result = await SellingDB.getInstance.getSaleByUID(uid);
                                if (result != null) {
                                  setPopupState(() {
                                    nameController.text = result[SellingDB.C_NAME] ?? "";
                                    meterController.text = result[SellingDB.C_TOTAL_METER]?.toString() ?? "";
                                    priceController.text = result[SellingDB.C_PER_METER_PRICE]?.toString() ?? "";
                                    _selectedCostPrice = double.tryParse(result[SellingDB.C_PER_METER_PRICE]?.toString() ?? '0') ?? 0;
                                    isDataFetched = true;
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("UID '$uid' not found in Selling history")),
                                  );
                                }
                              }
                            },
                            icon: const Icon(CupertinoIcons.search, color: Colors.blue),
                          ),
                        ] else 
                          IconButton(
                            onPressed: () => setPopupState(() {
                              isDataFetched = false;
                              multipleItemsFromInvoice = null;
                              _selectedCostPrice = 0;
                              uidController.clear();
                              nameController.clear();
                              meterController.clear();
                              priceController.clear();
                            }),
                            icon: const Icon(CupertinoIcons.refresh, color: Colors.grey),
                          ),
                      ],
                    ),

                    if (multipleItemsFromInvoice != null && !isDataFetched) ...[
                      const SizedBox(height: 15),
                      const Text(
                        "Multiple items found. Select one:",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                      ),
                      const SizedBox(height: 10),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: multipleItemsFromInvoice!.length,
                        itemBuilder: (ctx, i) {
                          final item = multipleItemsFromInvoice![i];
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.blue.withOpacity(0.2)),
                            ),
                            child: ListTile(
                              dense: true,
                              title: Text(item[SaleDB.C_NAME] ?? "Unknown Item", style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("${item[SaleDB.C_METER]} Mtr @ PKR ${item[SaleDB.C_PER_METER_AMOUNT]}"),
                              trailing: Icon(CupertinoIcons.check_mark_circled, size: 20, color: Colors.blue.shade300),
                              onTap: () {
                                setPopupState(() {
                                  nameController.text = item[SaleDB.C_NAME] ?? "";
                                  meterController.text = item[SaleDB.C_METER]?.toString() ?? "";
                                  priceController.text = item[SaleDB.C_PER_METER_AMOUNT]?.toString() ?? "";
                                  _selectedCostPrice = double.tryParse(item[SaleDB.C_COST_PRICE]?.toString() ?? '0') ?? 0;
                                  multipleItemsFromInvoice = null;
                                  isDataFetched = true;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ],

                    if (isDataFetched) ...[
                      const Divider(height: 30),
                      // Type Selector
                      CupertinoSlidingSegmentedControl<String>(
                        groupValue: type,
                        children: const {
                          "Return": Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text("Return", style: TextStyle(fontSize: 12))),
                          "Damage": Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text("Damage", style: TextStyle(fontSize: 12))),
                        },
                        onValueChanged: (v) => setPopupState(() => type = v!),
                      ),
                      const SizedBox(height: 15),
                      _popupField(nameController, "Item Name", CupertinoIcons.tag),
                      Row(
                        children: [
                          Expanded(child: _popupField(meterController, "Meters", CupertinoIcons.layers, type: TextInputType.number)),
                          const SizedBox(width: 10),
                          Expanded(child: _popupField(priceController, "Price/Mtr", CupertinoIcons.money_dollar, type: TextInputType.number)),
                        ],
                      ),
                      _popupField(reasonController, "Reason (Broken, Wrong Size, etc.)", CupertinoIcons.info),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
              if (isDataFetched)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (nameController.text.isEmpty) return;
                    
                    double retMeters = double.tryParse(meterController.text) ?? 0;
                    double retPrice = double.tryParse(priceController.text) ?? 0;
                    String currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

                    double retTotal = retMeters * retPrice;
                    double retCostTotal = retMeters * _selectedCostPrice;

                    // 1. Always reverse the Sale so it gets minused from Total Sales
                    await SaleDB.getInstance.addSale(
                      invUid: "REV_${uidController.text}", 
                      name: "Reversal: ${nameController.text}",
                      than: 0,
                      meter: -retMeters, // Negative to reverse
                      perMeterAmount: retPrice,
                      costPrice: _selectedCostPrice,
                      totalAmount: -retTotal, // Negative total to decrease sale sum
                      date: currentDate,
                    );

                    // 2. Save to Return History
                    await ReturnDB.getInstance.addReturn(
                      uid: uidController.text,
                      name: nameController.text,
                      type: type,
                      date: currentDate,
                      reason: reasonController.text,
                      meters: retMeters,
                      price: retPrice,
                    );

                    if (type == "Damage") {
                      // 3a. If Damage, minus from Purchasing as well (Return to Vendor / Write-off)
                      await KHisabDB.getInstance.addHisab(
                        name: "Damaged Stock: ${nameController.text}",
                        amount: -retCostTotal, // Negative to decrease purchasing sum
                        condition: "purchased", // Must match exactly to hit purchasing filter
                        date: currentDate,
                        description: "Stock loss write-off due to damage",
                      );
                    } else if (type == "Return") {
                      // 3b. If Return (not Damage), put stock back into selling.db to be resold
                      await SellingDB.getInstance.addSelling(
                        name: "${nameController.text} (Returned)",
                        uid: "RET_${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}",
                        totalMeter: retMeters,
                        perMeterPrice: _selectedCostPrice > 0 ? _selectedCostPrice : retPrice, // Keep original base cost
                        totalPrice: retMeters * (_selectedCostPrice > 0 ? _selectedCostPrice : retPrice),
                        totalProfit: 0,
                        date: currentDate,
                        paymentMode: "Return",
                        previousBalance: 0,
                      );
                    }

                    if (context.mounted) Navigator.pop(context);
                    _loadRecords();
                  },
                  child: const Text("Save Record"),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _popupField(TextEditingController controller, String hint, IconData icon, {TextInputType type = TextInputType.text, bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: type,
        readOnly: readOnly,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: hint,
          prefixIcon: Icon(icon, size: 18),
          filled: readOnly,
          fillColor: readOnly ? Colors.grey.shade50 : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: readOnly ? Colors.blue.shade100 : Colors.grey.shade300),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- 1. HEADER SECTION ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Return & Damage",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.blueGrey),
              ),
              ElevatedButton(
                onPressed: _showAddPopup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                ).copyWith(overlayColor: WidgetStateProperty.all(Colors.grey.withOpacity(0.1))),
                child: rowbutton("New Entry", CupertinoIcons.arrow_2_squarepath),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

        // --- 2. MAIN CONTENT ---
        Expanded(
          child: _isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : _records.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(15),
                      itemCount: _records.length,
                      itemBuilder: (context, index) {
                        final item = _records[index];
                        final bool isDamage = item[ReturnDB.C_TYPE] == "Damage";
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: (isDamage ? Colors.red : Colors.blue).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isDamage ? CupertinoIcons.xmark_circle_fill : CupertinoIcons.arrow_2_squarepath,
                                    color: isDamage ? Colors.red : Colors.blue,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            item[ReturnDB.C_NAME] ?? "Unknown Item",
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          Text(
                                            item[ReturnDB.C_DATE] ?? "",
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "UID: ${item[ReturnDB.C_UID] ?? 'N/A'}",
                                        style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Reason: ${item[ReturnDB.C_REASON] ?? 'No reason provided'}",
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "${item[ReturnDB.C_METERS]} Mtr",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      "PKR ${(item[ReturnDB.C_PRICE] * item[ReturnDB.C_METERS]).toStringAsFixed(0)}",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey.shade400),
                                    ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () async {
                                        await ReturnDB.getInstance.deleteReturn(item[ReturnDB.C_ID]);
                                        _loadRecords();
                                      },
                                      child: const Icon(CupertinoIcons.trash, color: Colors.redAccent, size: 18),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), shape: BoxShape.circle),
            child: Icon(CupertinoIcons.arrow_2_squarepath, size: 80, color: Colors.blue.withOpacity(0.2)),
          ),
          const SizedBox(height: 24),
          const Text("No Return Records", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 10),
          Text(
            "Track returned items or damaged stock here.\nUse 'New Entry' to log a UID return.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.5),
          ),
        ],
      ),
    );
  }
}
