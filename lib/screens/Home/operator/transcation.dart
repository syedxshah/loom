import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loom/widget/rowmenu.dart';
import 'package:loom/widget/popup.dart';
import 'package:loom/screens/Home/operator/transcation/expense.dart';
import 'package:loom/backend/homebackend/operations/khisab.dart';
import 'package:loom/backend/homebackend/operations/payment_service.dart';
import 'package:loom/backend/homebackend/customer/bcustomer.dart';
import 'package:loom/backend/homebackend/vendor/bvendor.dart';
import 'package:loom/backend/homebackend/customer/bcustomerlist_in_purchaing.dart';
import 'package:loom/backend/homebackend/vendor/bvendername.dart';

Widget Transaction(
  BuildContext context,
  int activeIndex,
  Function(int) onTabChanged,
) {
  final amountController = TextEditingController();
  final nameController = TextEditingController();
  final noteController = TextEditingController();

  void onTransactionSubmit() async {
    if (amountController.text.isEmpty || nameController.text.isEmpty) return;
    final double amount = double.tryParse(amountController.text) ?? 0;
    if (amount <= 0) return;

    String? condition;
    if (activeIndex == 1) {
      condition = 'income';
    } else if (activeIndex == 2) {
      condition = 'expense';
    }

    await KHisabDB.getInstance.addHisab(
      name: nameController.text,
      description: noteController.text.isEmpty ? "Manual Entry" : noteController.text,
      amount: amount,
      condition: condition,
    );

    Navigator.pop(context);
    amountController.clear();
    nameController.clear();
    noteController.clear();
    onTabChanged(activeIndex);
  }

  void _showLedgerPaymentPopup() async {
    List<Map<String, dynamic>> allPeople = [];
    final customers = await BCustomer.getInstance.getAllCustomers();
    final vendors = await Bvendor.getInstance.getAllVendors();

    allPeople.addAll(customers.map((e) => {
          'name': e[BCustomer.C_customername],
          'id': e[BCustomer.C_customeruid],
          'type': PaymentService.TYPE_CUSTOMER,
          'display': "${e[BCustomer.C_customername]} (Customer)",
        }));

    allPeople.addAll(vendors.map((e) => {
          'name': e[Bvendor.C_name],
          'id': e[Bvendor.C_uid],
          'type': PaymentService.TYPE_VENDOR,
          'display': "${e[Bvendor.C_name]} (Vendor)",
        }));

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) {
          // Initialize state variables inside StatefulBuilder
          // These need to be persisted across setPopupState calls
          return _LedgerPaymentDialogContent(
            allPeople: allPeople,
            activeIndex: activeIndex,
            onTabChanged: onTabChanged,
          );
        },
      ),
    );
  }

  final ButtonStyle transButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.transparent,
    shadowColor: Colors.transparent,
    elevation: 0,
    padding: EdgeInsets.zero,
  ).copyWith(
    overlayColor: WidgetStateProperty.all(Colors.grey.withOpacity(0.1)),
  );

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Transactions",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.blueGrey,
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(CupertinoIcons.creditcard_fill, color: Colors.indigo),
                  onPressed: _showLedgerPaymentPopup,
                  tooltip: "Ledger Payment",
                ),
                IconButton(
                  icon: const Icon(CupertinoIcons.add_circled_solid, color: Colors.green),
                  onPressed: () => showAddPopup(
                    context: context,
                    title: "New Transaction",
                    fields: [
                      buildPopupField(nameController, "Name / Bill Name", CupertinoIcons.tag),
                      buildPopupField(amountController, "Amount", CupertinoIcons.money_dollar, type: TextInputType.number),
                      buildPopupField(noteController, "Note/Description", CupertinoIcons.pencil),
                    ],
                    onSubmit: onTransactionSubmit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      SizedBox(
        height: 60,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          children: [
            ElevatedButton(
              onPressed: () => onTabChanged(0),
              style: transButtonStyle,
              child: rowmenu("Total", CupertinoIcons.creditcard),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => onTabChanged(1),
              style: transButtonStyle,
              child: rowmenu("Income", CupertinoIcons.arrow_down_circle),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => onTabChanged(2),
              style: transButtonStyle,
              child: rowmenu("Expense", CupertinoIcons.arrow_up_circle),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
      Expanded(
        child: Container(
          width: double.infinity,
          color: Colors.white,
          child: ExpenseList(activeIndex: activeIndex),
        ),
      ),
    ],
  );
}

// Inner helper class to manage the stateful parts of the payment dialog
class _LedgerPaymentDialogContent extends StatefulWidget {
  final List<Map<String, dynamic>> allPeople;
  final int activeIndex;
  final Function(int) onTabChanged;

  const _LedgerPaymentDialogContent({
    required this.allPeople,
    required this.activeIndex,
    required this.onTabChanged,
  });

  @override
  State<_LedgerPaymentDialogContent> createState() => _LedgerPaymentDialogContentState();
}

class _LedgerPaymentDialogContentState extends State<_LedgerPaymentDialogContent> {
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  Map<String, dynamic>? selectedPerson;
  double currentBalance = 0;
  bool isFetchingBalance = false;
  bool isReceived = true;

  Future<void> _fetchBalance(Map<String, dynamic> person) async {
    setState(() => isFetchingBalance = true);
    double bal = 0;
    if (person['type'] == PaymentService.TYPE_CUSTOMER) {
      final txs = await BCustomerLedgerDB.getInstance.getTransactions(person['id']);
      if (txs.isNotEmpty) {
        bal = double.tryParse(txs.first[BCustomerLedgerDB.C_credit]?.toString() ?? '0') ?? 0;
      }
    } else {
      bal = await Bvendername.getInstance.getRunningBalance(person['name']);
    }
    setState(() {
      currentBalance = bal;
      isFetchingBalance = false;
      selectedPerson = person;
      isReceived = person['type'] == PaymentService.TYPE_CUSTOMER;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text("Ledger Payment", style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Autocomplete<Map<String, dynamic>>(
              displayStringForOption: (option) => option['display'],
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text == '') return const Iterable<Map<String, dynamic>>.empty();
                return widget.allPeople.where((p) => p['display'].toLowerCase().contains(textEditingValue.text.toLowerCase()));
              },
              onSelected: (p) => _fetchBalance(p),
              fieldViewBuilder: (context, controller, focus, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focus,
                  decoration: InputDecoration(
                    labelText: "Select Customer / Vendor",
                    prefixIcon: const Icon(CupertinoIcons.person_solid),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ),
            if (selectedPerson != null) ...[
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Current Balance:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    isFetchingBalance
                        ? const CupertinoActivityIndicator(radius: 8)
                        : Text(
                            "PKR ${currentBalance.abs().toStringAsFixed(0)} ${currentBalance < 0 ? '(Udhaar)' : '(Advance)'}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: currentBalance < 0 ? Colors.red : Colors.green,
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              CupertinoSlidingSegmentedControl<bool>(
                groupValue: isReceived,
                children: const {
                  true: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("Received", style: TextStyle(fontSize: 12))),
                  false: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("Paid", style: TextStyle(fontSize: 12))),
                },
                onValueChanged: (v) => setState(() => isReceived = v!),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Amount",
                  prefixIcon: const Icon(CupertinoIcons.money_dollar),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: "Note (Optional)",
                  prefixIcon: const Icon(CupertinoIcons.pencil),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade800,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: selectedPerson == null
              ? null
              : () async {
                  final amount = double.tryParse(amountController.text) ?? 0;
                  if (amount <= 0) return;

                  final success = await PaymentService.getInstance.processLedgerPayment(
                    personType: selectedPerson!['type'],
                    personId: selectedPerson!['id'],
                    personName: selectedPerson!['name'],
                    amount: amount,
                    isPaymentReceived: isReceived,
                    description: noteController.text,
                  );

                  if (success && context.mounted) {
                    Navigator.pop(context);
                    widget.onTabChanged(widget.activeIndex);
                  }
                },
          child: const Text("Save Payment"),
        ),
      ],
    );
  }
}
