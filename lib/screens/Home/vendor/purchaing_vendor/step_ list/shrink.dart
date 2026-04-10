import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loom/backend/homebackend/vendor/speratevenderlist_in_purchaing.dart';

class ShrinkScreen extends StatefulWidget {
  final String suid;
  final String vendorName;
  final String clothName;

  const ShrinkScreen({
    super.key,
    required this.suid,
    required this.vendorName,
    required this.clothName,
  });

  @override
  State<ShrinkScreen> createState() => _ShrinkScreenState();
}

class _ShrinkScreenState extends State<ShrinkScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _transferItems = [];
  List<Map<String, dynamic>> _activeItems = [];

  double _totalTransferMeters = 0;
  double _totalTransferValue = 0;
  double _totalActiveMeters = 0;
  double _totalActiveValue = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _fetchData();
    setState(() => _isLoading = false);
  }

  Future<void> _fetchData() async {
    final stock = await SperatevenderlistInPurchaing.getInstance.getVendorStock(
      widget.vendorName,
    );

    List<Map<String, dynamic>> t = [];
    List<Map<String, dynamic>> s = [];

    double trM = 0;
    double trV = 0;
    double acM = 0;
    double acV = 0;

    for (var raw in stock) {
      final item = Map<String, dynamic>.from(raw);

      if (item['uid'].toString() == widget.suid) {
        if (item['type'] == 't_s_hold') {
          t.add(item);
          trM += double.tryParse(item['meter']?.toString() ?? '0') ?? 0;
          trV += double.tryParse(item['total']?.toString() ?? '0') ?? 0;
        } else if (item['type'] == 's_done' && item['condition'] == 'shrink') {
          s.add(item);
          if (item['type'] == 's_done') {
            acM += double.tryParse(item['meter']?.toString() ?? '0') ?? 0;
            acV += double.tryParse(item['total']?.toString() ?? '0') ?? 0;
          }
        }
      }
    }

    _transferItems = t;
    _activeItems = s;
    _totalTransferMeters = trM;
    _totalTransferValue = trV;
    _totalActiveMeters = acM;
    _totalActiveValue = acV;
  }

  void _showShrinkConversionDialog(Map<String, dynamic> item) {
    double originalMeter = double.tryParse(item['meter'].toString()) ?? 0;
    final meterCtrl = TextEditingController(text: originalMeter.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          "Process Shrinkage",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: meterCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Meters After Shrink",
                border: OutlineInputBorder(),
                isDense: true,
              ),
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
              backgroundColor: const Color(0xFF455A64),
            ),
            onPressed: () async {
              double received = double.tryParse(meterCtrl.text) ?? 0;
              if (received <= 0 || received > originalMeter) return;

              double originalPrice =
                  double.tryParse(item['price_per_meter']?.toString() ?? '0') ??
                  0;

              double totalCashAmount = originalMeter * originalPrice;
              double finalPricePerMeter = totalCashAmount / received;

              final allStock = await SperatevenderlistInPurchaing.getInstance
                  .getVendorStock(widget.vendorName);
              String currentSuid = item['suid'].toString();

              int existingSubCount = allStock
                  .where(
                    (s) =>
                        s['suid'].toString().startsWith(currentSuid) &&
                        s['condition'] == 'packing',
                  )
                  .length;
              String suffix = String.fromCharCode(65 + existingSubCount);
              String newEntitySuid = "$currentSuid$suffix";

              Map<String, dynamic> doneData = Map.from(item);
              doneData['type'] = 's_done';
              doneData['condition'] = 'shrink';
              doneData['meter'] = received;
              doneData['price_per_meter'] = finalPricePerMeter;
              doneData['total'] = totalCashAmount;

              await SperatevenderlistInPurchaing.getInstance.updateStock(
                item['id'].toString(),
                doneData,
                widget.vendorName,
              );

              Map<String, dynamic> packingData = Map.from(item);
              packingData['id'] =
                  DateTime.now().millisecondsSinceEpoch.toString() + "_packing";
              packingData['meter'] = received;
              packingData['price_per_meter'] = finalPricePerMeter;
              packingData['total'] = totalCashAmount;
              packingData['suid'] = newEntitySuid;
              packingData['condition'] = 'packing';
              packingData['type'] = 't_h_packing';
              packingData['date'] = DateFormat(
                'dd-MM-yyyy',
              ).format(DateTime.now());

              await SperatevenderlistInPurchaing.getInstance.addStock(
                packingData,
                widget.vendorName,
              );

              if (!mounted) return;
              Navigator.pop(context);
              _loadData();
            },
            child: const Text("Confirm"),
          ),
        ],
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF455A64),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF455A64),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Ready for Shrink"),
            Tab(text: "Completed Shrink"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryTopView(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListView(_transferItems, true),
                      _buildListView(_activeItems, false),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryTopView() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _summaryBox(
              "Pending (t_s_hold)",
              _totalTransferMeters,
              _totalTransferValue,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _summaryBox(
              "Completed (s_done)",
              _totalActiveMeters,
              _totalActiveValue,
              Colors.green,
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(10),
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
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Text(
            "Rs. ${value.toStringAsFixed(0)}",
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(List items, bool isTransfer) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 10),
            Text("No items found", style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 5,
            ),
            title: Row(
              children: [
                Text(
                  item['vendor_name'] ?? "N/A",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isTransfer
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    isTransfer ? "PENDING" : "SHRUNK",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isTransfer ? Colors.blue[800] : Colors.green[800],
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "SUID: ${item['suid']}  •  Qty: ${item['meter']} Mtr  •  Val: Rs. ${item['total'] ?? 0}",
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
            ),
            onTap: () {
              if (isTransfer) {
                _showShrinkConversionDialog(item);
              } else {
                if (item['type'] == 's_done') {
                  _showDetailsPopup(context, item);
                }
              }
            },
            trailing: isTransfer
                ? const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey,
                    size: 16,
                  )
                : item['type'] == 's_done'
                ? const Icon(Icons.check_circle, color: Colors.green, size: 24)
                : const Icon(Icons.compress, color: Colors.grey, size: 20),
          ),
        );
      },
    );
  }

  void _showDetailsPopup(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Completed Shrink Details",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Quantity: ${item['meter']} Mtr"),
            const SizedBox(height: 8),
            Text("Price Per Meter: Rs. ${item['price_per_meter']}"),
            const SizedBox(height: 8),
            Text(
              "Total Price: Rs. ${item['total']}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF455A64),
            ),
            child: const Text("Close", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
