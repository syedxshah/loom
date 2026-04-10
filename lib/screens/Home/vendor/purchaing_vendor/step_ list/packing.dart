import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loom/backend/homebackend/vendor/speratevenderlist_in_purchaing.dart';
import 'package:loom/backend/homebackend/operations/khisab.dart';

class PackingScreen extends StatefulWidget {
  final String suid;
  final String vendorName;
  final String clothName;

  const PackingScreen({
    super.key,
    required this.suid,
    required this.vendorName,
    required this.clothName,
  });

  @override
  State<PackingScreen> createState() => _PackingScreenState();
}

class _PackingScreenState extends State<PackingScreen> {
  List<Map<String, dynamic>> _packingItems = [];
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

      // Filtering items belonging to this specific batch (suid)
      // and checking for packing-related conditions
      if (item['uid'].toString() == widget.suid) {
        if (item['condition']?.toString().toLowerCase() == 'packing' &&
            (item['type'] == 't_h_packing' || item['type'] == 'p_hold')) {
          items.add(item);
          m += double.tryParse(item['meter']?.toString() ?? '0') ?? 0;
          v += double.tryParse(item['total']?.toString() ?? '0') ?? 0;
        }
      }
    }

    _packingItems = items;
    _totalMeters = m;
    _totalValue = v;
  }

  void _showPackingDialog(Map<String, dynamic> item) {
    final rateCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "FINALIZE PACKING",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF3B82F6),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Batch: ${item['suid']}",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            _popupTextField(
              controller: rateCtrl,
              label: "Packing Rate",
              icon: Icons.payments_outlined,
              suffix: "PKR/MTR",
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF3B82F6)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Final cost includes original cloth + process costs + bilti value.",
                      style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    double rateValue = double.tryParse(rateCtrl.text) ?? 0;

                    final allStock = await SperatevenderlistInPurchaing.getInstance
                        .getVendorStock(widget.vendorName);

                    final greyItem = allStock.firstWhere(
                      (s) =>
                          s['condition']?.toString().toLowerCase() == 'grey' &&
                          s['uid'].toString() == item['uid'].toString(),
                      orElse: () => <String, dynamic>{},
                    );

                    double biltyValue = double.tryParse(greyItem['bilti_per_meter']?.toString() ?? '0') ?? 0;
                    double meters = double.tryParse(item['meter'].toString()) ?? 0;
                    double originalPrice = double.tryParse(item['price_per_meter']?.toString() ?? '0') ?? 0;

                    double finalPricePerMeter = originalPrice + rateValue + biltyValue;
                    double totalValueAmount = meters * finalPricePerMeter;

                    String currentSuid = item['suid'].toString();

                    int existingSubCount = allStock
                        .where(
                          (s) =>
                              s['suid'].toString().startsWith(currentSuid) &&
                              s['condition']?.toString().toLowerCase() == 'ready',
                        )
                        .length;

                    String suffix = String.fromCharCode(65 + (existingSubCount % 26));
                    String newEntitySuid = "$currentSuid$suffix";

                    Map<String, dynamic> readyData = Map.from(item);
                    readyData['id'] = "${DateTime.now().millisecondsSinceEpoch}_ready";
                    readyData['meter'] = meters;
                    readyData['price_per_meter'] = finalPricePerMeter;
                    readyData['total'] = totalValueAmount;
                    readyData['suid'] = newEntitySuid;
                    readyData['bilti_per_meter'] = biltyValue;
                    readyData['condition'] = 'ready';
                    readyData['type'] = 'r_hold';
                    readyData['date'] = DateFormat('dd-MM-yyyy').format(DateTime.now());

                    readyData.remove('bilty');
                    readyData.remove('grey_uid');

                    await SperatevenderlistInPurchaing.getInstance.addStock(
                      readyData,
                      widget.vendorName,
                    );

                    Map<String, dynamic> doneData = Map.from(item);
                    doneData['type'] = 'p_done';
                    await SperatevenderlistInPurchaing.getInstance.updateStock(
                      item['id'].toString(),
                      doneData,
                      widget.vendorName,
                    );

                    await KHisabDB.getInstance.addHisab(
                      name: "${widget.clothName} Packing",
                      description: "Packing on ${DateFormat('dd-MM-yyyy').format(DateTime.now())}",
                      amount: meters * rateValue,
                      condition: "packing",
                      date: DateFormat('dd-MM-yyyy').format(DateTime.now()),
                    );

                    if (!mounted) return;
                    Navigator.pop(context);
                    _loadData();
                  },
                  child: const Text("Confirm Packing", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "PACKING STAGE",
              style: TextStyle(
                color: Colors.blue.shade600,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              widget.clothName,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E293B)))
          : Column(
              children: [
                _buildSummaryTopView(),
                Expanded(child: _buildListView(_packingItems)),
              ],
            ),
    );
  }

  Widget _buildSummaryTopView() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        children: [
          Expanded(
            child: _summaryBox(
              "PENDING PACKING", 
              _totalMeters, 
              _totalValue, 
              const Color(0xFF3B82F6),
              Icons.inventory_2_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBox(String title, double meters, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                  color: color, 
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(icon, size: 14, color: color.withOpacity(0.5)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "${meters.toStringAsFixed(1)} Mtr", 
            style: const TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          Text(
            "Rs. ${NumberFormat('#,###').format(value)}", 
            style: const TextStyle(
              fontSize: 11, 
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(List items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[200]),
            const SizedBox(height: 12),
            Text(
              "No packing batches", 
              style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.inventory_2_rounded,
                color: Color(0xFF3B82F6),
                size: 20,
              ),
            ),
            title: Text(
              item['vendor_name'] ?? "BUFFER STOCK",
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1E293B)),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                "BATCH: ${item['suid']}  •  ${item['meter']} MTR",
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ),
            onTap: () => _showPackingDialog(item),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF94A3B8),
              size: 24,
            ),
          ),
        );
      },
    );
  }

  Widget _popupTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
        suffixText: suffix,
        suffixStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }
}
