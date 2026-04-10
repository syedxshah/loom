import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loom/backend/homebackend/operations/khisab.dart';
import 'package:loom/backend/homebackend/operations/sale.dart';

class ExpenseList extends StatefulWidget {
  final int activeIndex;
  const ExpenseList({super.key, required this.activeIndex});

  @override
  State<ExpenseList> createState() => _ExpenseListState();
}

class _ExpenseListState extends State<ExpenseList> {
  List<Map<String, dynamic>> _allData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(ExpenseList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeIndex != widget.activeIndex) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Fetch Expenses (Hisab)
    final expensesRaw = await KHisabDB.getInstance.getAllHisabs();
    
    // Fetch Income (Sales)
    final salesRaw = await SaleDB.getInstance.getAllSales();
    
    // Map Sales to matching format
    final List<Map<String, dynamic>> incomeData = salesRaw.map((e) => {
      'id': e['id'],
      'name': e['name'],
      'description': "Sale Invoice: ${e['inv_uid']}",
      'amount': e['total_amount'],
      'date': e['date'],
      'condition': 'income', // Custom condition for UI
    }).toList();

    List<Map<String, dynamic>> combined = [];
    
    // Filtering based on activeIndex from transaction.dart
    // index 0 = Total, 1 = Income, 2 = Expense
    if (widget.activeIndex == 0) {
      combined = [...incomeData, ...expensesRaw];
      // Sort by date (assuming dd-MM-yyyy format, we might need a parser if order is critical)
      // For now, sorting by ID if dates are same or just merging since both are DESC already
    } else if (widget.activeIndex == 1) {
      combined = incomeData;
    } else if (widget.activeIndex == 2) {
      combined = expensesRaw;
    }
    
    setState(() {
      _allData = combined;
      _isLoading = false;
    });
  }

  Future<void> _deleteEntry(int id) async {
    await KHisabDB.getInstance.deleteHisab(id);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_allData.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _allData.length,
      itemBuilder: (context, index) {
        final item = _allData[index];
        final bool isPurchase = item['condition'] == 'purchased';
        final bool isIncome = item['condition'] == 'income';
        
        return Card(
          elevation: 0,
          margin: const EdgeInsets.all(0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0),
            // side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon based on condition
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isIncome 
                        ? Colors.green.withOpacity(0.1)
                        : (isPurchase ? Colors.orange.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isIncome 
                        ? CupertinoIcons.arrow_down_circle
                        : (isPurchase ? CupertinoIcons.shopping_cart : CupertinoIcons.arrow_up_circle),
                    color: isIncome ? Colors.green : (isPurchase ? Colors.orange : Colors.redAccent),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 15),
                // Text info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? "Unknown",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['description'] ?? "",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['date'] ?? "",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Amount and Delete
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${isIncome ? '+' : '-'} Rs. ${NumberFormat("#,###").format(item['amount'] ?? 0)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isIncome ? Colors.green : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (!isIncome) // Only show delete for manually added hisabs, not Sales
                      GestureDetector(
                        onTap: () => _showDeleteConfirm(item['id']),
                        child: const Icon(
                          CupertinoIcons.trash,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.doc_text_search,
            size: 60,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 15),
          Text(
            "No Records Found",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(int id) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Delete Record?"),
        content: const Text("This will permanently remove this entry from your ledger."),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Delete"),
            onPressed: () {
              Navigator.pop(context);
              _deleteEntry(id);
            },
          ),
        ],
      ),
    );
  }
}
