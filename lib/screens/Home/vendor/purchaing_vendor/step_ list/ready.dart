import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loom/backend/homebackend/vendor/speratevenderlist_in_purchaing.dart';
import 'package:loom/backend/homebackend/operations/selling.dart';

class ReadyScreen extends StatefulWidget {
  final String suid;
  final String vendorName;
  final String clothName;

  const ReadyScreen({
    super.key,
    required this.suid,
    required this.vendorName,
    required this.clothName,
  });

  @override
  State<ReadyScreen> createState() => _ReadyScreenState();
}

class _ReadyScreenState extends State<ReadyScreen> {
  List<Map<String, dynamic>> _readyItems = [];
  double _totalMeters = 0;
  double _totalValue = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _fetchData();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchData() async {
    final stock = await SperatevenderlistInPurchaing.getInstance.getVendorStock(
      widget.vendorName,
    );
    List<Map<String, dynamic>> items = [];
    double m = 0;
    double v = 0;

    for (var raw in stock) {
      final item = Map<String, dynamic>.from(raw);
      // Logic: Show items belonging to this UID that are in 'ready' condition
      if (item['uid'].toString() == widget.suid) {
        if (item['condition']?.toString().toLowerCase() == 'ready' &&
            (item['type'] == 'r_hold' || item['type'] == 'r_done')) {
          items.add(item);

          // Only add to summary totals if NOT yet purchased (Pending)
          if (item['p_or_r'] != 'purchased') {
            m += double.tryParse(item['meter']?.toString() ?? '0') ?? 0;
            v += double.tryParse(item['total']?.toString() ?? '0') ?? 0;
          }
        }
      }
    }

    // Sort so purchased items go to the bottom
    items.sort(
      (a, b) => (a['p_or_r'] == 'purchased' ? 1 : 0).compareTo(
        b['p_or_r'] == 'purchased' ? 1 : 0,
      ),
    );

    _readyItems = items;
    _totalMeters = m;
    _totalValue = v;
  }

  void _showReadyActionDialog(Map<String, dynamic> item) {
    // Prevent actions on already purchased items
    if (item['p_or_r'] == 'purchased') return;

    final cutCtrl = TextEditingController(text: "0");
    double originalMeters =
        double.tryParse(item['meter']?.toString() ?? '0') ?? 0;
    double rate =
        double.tryParse(item['price_per_meter']?.toString() ?? '0') ?? 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          double cutMeters = double.tryParse(cutCtrl.text) ?? 0;
          double remainingMeters = originalMeters - cutMeters;

          return AlertDialog(
            title: Text(
              "Purchase & Cut: ${item['suid']}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Available: $originalMeters Mtr",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: cutCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: "Cut / Rough Piece Meter",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) => setDialogState(() {}),
                ),
                const SizedBox(height: 15),
                Text(
                  "Main: ${remainingMeters.toStringAsFixed(2)} Mtr",
                  style: const TextStyle(color: Colors.blue, fontSize: 13),
                ),
                Text(
                  "Cut: ${cutMeters.toStringAsFixed(2)} Mtr",
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                ),
                onPressed: () async {
                  if (cutMeters > originalMeters) return;

                  // 1. Update Main Piece
                  Map<String, dynamic> mainPiece = Map.from(item);
                  mainPiece['meter'] = remainingMeters;
                  mainPiece['total'] = remainingMeters * rate;
                  mainPiece['p_or_r'] = 'purchased';
                  mainPiece['type'] = 'r_done';

                  await SperatevenderlistInPurchaing.getInstance.updateStock(
                    item['id'].toString(),
                    mainPiece,
                    widget.vendorName,
                  );

                  // Add Main Piece to SellingDB
                  await SellingDB.getInstance.addSelling(
                    name: widget.clothName,
                    uid: "${widget.vendorName}-${mainPiece['suid']}",
                    totalMeter: remainingMeters,
                    perMeterPrice: rate,
                    totalPrice: mainPiece['total'],
                    date: DateFormat('dd-MM-yyyy').format(DateTime.now()),
                  );

                  // 2. Create Cut Piece (if applicable)
                  if (cutMeters > 0) {
                    Map<String, dynamic> cutPiece = Map.from(item);
                    cutPiece['id'] =
                        "${DateTime.now().millisecondsSinceEpoch}_cut";
                    cutPiece['suid'] = "${item['suid']}-CUT";
                    cutPiece['meter'] = cutMeters;
                    cutPiece['total'] = cutMeters * rate;
                    cutPiece['p_or_r'] = 'purchased';
                    cutPiece['type'] = 'r_done';

                    await SperatevenderlistInPurchaing.getInstance.addStock(
                      cutPiece,
                      widget.vendorName,
                    );

                    // Add Cut Piece to SellingDB
                    await SellingDB.getInstance.addSelling(
                      name: widget.clothName,
                      uid: "${widget.vendorName}-${cutPiece['suid']}",
                      totalMeter: cutMeters,
                      perMeterPrice: rate,
                      totalPrice: cutPiece['total'],
                      date: DateFormat('dd-MM-yyyy').format(DateTime.now()),
                    );
                  }

                  if (!mounted) return;
                  Navigator.pop(context);
                  _loadData();
                },
                child: const Text(
                  "Confirm",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          widget.clothName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryTopView(),
                Expanded(child: _buildListView(_readyItems)),
              ],
            ),
    );
  }

  Widget _buildSummaryTopView() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: _summaryBox(
        "Pending Purchase",
        _totalMeters,
        _totalValue,
        Colors.green,
      ),
    );
  }

  Widget _summaryBox(
    String title,
    double meters,
    double value,
    MaterialColor color,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color[800],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "${meters.toStringAsFixed(1)} Mtr",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            "Payable: Rs. ${value.toStringAsFixed(0)}",
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(List items) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        bool isPurchased = item['p_or_r'] == 'purchased';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          color: isPurchased ? Colors.grey[50] : Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: isPurchased ? Colors.grey[200]! : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            title: Row(
              children: [
                Text(
                  item['suid'] ?? "N/A",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isPurchased ? Colors.grey : Colors.black,
                    decoration: isPurchased ? TextDecoration.lineThrough : null,
                  ),
                ),
                const Spacer(),
                _statusBadge(isPurchased ? "PURCHASED" : "READY", isPurchased),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "Qty: ${item['meter']} Mtr  •  Rate: ${item['price_per_meter']}  •  Total: ${item['total']}",
                style: TextStyle(
                  fontSize: 11,
                  color: isPurchased ? Colors.grey : Colors.grey[800],
                ),
              ),
            ),
            onTap: () => _showReadyActionDialog(item),
            trailing: Icon(
              isPurchased ? Icons.check_circle : Icons.shopping_cart_outlined,
              color: isPurchased ? Colors.green : Colors.grey,
              size: 18,
            ),
          ),
        );
      },
    );
  }

  Widget _statusBadge(String label, bool isPurchased) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isPurchased ? Colors.grey : Colors.green).withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isPurchased ? Colors.grey[600] : Colors.green[800],
        ),
      ),
    );
  }
}
