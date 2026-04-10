import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loom/backend/homebackend/vendor/speratevenderlist_in_purchaing.dart';
import 'package:loom/backend/homebackend/vendor/bvendor.dart';
import 'package:loom/backend/homebackend/vendor/bvendername.dart';
import 'package:loom/backend/homebackend/operations/khisab.dart';

class KhariScreen extends StatefulWidget {
  final String suid;
  final String vendorName;
  final String clothName;

  const KhariScreen({
    super.key,
    required this.suid,
    required this.vendorName,
    required this.clothName,
  });

  @override
  State<KhariScreen> createState() => _KhariScreenState();
}

class _KhariScreenState extends State<KhariScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _transferItems = [];
  List<Map<String, dynamic>> _activeItems = [];
  List<Map<String, dynamic>> _vendors = [];

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
    _vendors = await Bvendor.getInstance.getAllVendors();
    await _fetchData();
    setState(() => _isLoading = false);
  }

  Future<void> _fetchData() async {
    final stock = await SperatevenderlistInPurchaing.getInstance.getVendorStock(
      widget.vendorName,
    );

    List<Map<String, dynamic>> t = [];
    List<Map<String, dynamic>> k = [];

    double trM = 0;
    double trV = 0;
    double acM = 0;
    double acV = 0;

    for (var raw in stock) {
      final item = Map<String, dynamic>.from(raw);

      if (item['uid'].toString() == widget.suid) {
        if (item['type'] == 't_k_hold') {
          t.add(item);
          trM += double.tryParse(item['meter']?.toString() ?? '0') ?? 0;
          trV += double.tryParse(item['total']?.toString() ?? '0') ?? 0;
        } else if ((item['type'] == 'k_hold' || item['type'] == 'k_done') &&
            item['condition'] == 'khari') {
          k.add(item);
          if (item['type'] == 'k_hold') {
            acM += double.tryParse(item['meter']?.toString() ?? '0') ?? 0;
            acV += double.tryParse(item['total']?.toString() ?? '0') ?? 0;
          }
        }
      }
    }

    _transferItems = t;
    _activeItems = k;
    _totalTransferMeters = trM;
    _totalTransferValue = trV;
    _totalActiveMeters = acM;
    _totalActiveValue = acV;
  }

  void _skipToShrink(Map<String, dynamic> item) {
    double original = double.tryParse(item['meter'].toString()) ?? 0;
    final meterCtrl = TextEditingController(text: original.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "SKIP PROCESS",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFFF59E0B),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Redirect to Shrink",
              style: TextStyle(
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
              controller: meterCtrl,
              label: "Meters to Skip",
              icon: Icons.fast_forward_rounded,
              suffix: "MTR",
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
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    double skip = double.tryParse(meterCtrl.text) ?? 0;
                    if (skip <= 0 || skip > original) return;

                    final stock = await SperatevenderlistInPurchaing.getInstance
                        .getVendorStock(widget.vendorName);
                    int count = stock
                        .where(
                          (s) =>
                              s['suid'].toString().startsWith(item['suid']) &&
                              s['condition'] == 'shrink_done',
                        )
                        .length;
                    String suffix = String.fromCharCode(65 + count);
                    String newSuid = "${item['suid']}$suffix";

                    Map<String, dynamic> newItem = Map.from(item);
                    newItem['id'] = DateTime.now().millisecondsSinceEpoch.toString();
                    newItem['meter'] = skip;
                    newItem['suid'] = newSuid;
                    newItem['type'] = 't_s_hold';
                    newItem['condition'] = 'shrink_done';
                    newItem['p_or_r'] = 'expense';
                    newItem['date'] = DateFormat('dd-MM-yyyy').format(DateTime.now());

                    if (skip == original) {
                      await SperatevenderlistInPurchaing.getInstance.updateStock(
                        item['id'],
                        newItem,
                        widget.vendorName,
                      );
                    } else {
                      await SperatevenderlistInPurchaing.getInstance.addStock(
                        newItem,
                        widget.vendorName,
                      );
                      Map<String, dynamic> remaining = Map.from(item);
                      remaining['meter'] = original - skip;
                      await SperatevenderlistInPurchaing.getInstance.updateStock(
                        item['id'],
                        remaining,
                        widget.vendorName,
                      );
                    }
                    Navigator.pop(context);
                    _loadData();
                  },
                  child: const Text("Confirm Skip", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _skipAll() async {
    if (_transferItems.isEmpty) return;
    for (var item in _transferItems) {
      double meter = double.tryParse(item['meter'].toString()) ?? 0;
      final stock = await SperatevenderlistInPurchaing.getInstance
          .getVendorStock(widget.vendorName);
      int count = stock
          .where(
            (s) =>
                s['suid'].toString().startsWith(item['suid']) &&
                s['condition'] == 'shrink_done',
          )
          .length;
      String suffix = String.fromCharCode(65 + count);
      String newSuid = "${item['suid']}$suffix";

      Map<String, dynamic> newItem = Map.from(item);
      newItem['id'] = DateTime.now().millisecondsSinceEpoch.toString();
      newItem['meter'] = meter;
      newItem['suid'] = newSuid;
      newItem['type'] = 't_s_hold';
      newItem['condition'] = 'shrink_done';
      newItem['p_or_r'] = 'expense';
      newItem['date'] = DateFormat('dd-MM-yyyy').format(DateTime.now());

      await SperatevenderlistInPurchaing.getInstance.updateStock(
        item['id'],
        newItem,
        widget.vendorName,
      );
    }
    _loadData();
  }

  void _sendDialog(Map<String, dynamic> item) {
    double originalMeter = double.tryParse(item['meter'].toString()) ?? 0;
    final meterCtrl = TextEditingController(text: originalMeter.toString());
    String? selectedVendor = _vendors.isNotEmpty
        ? _vendors.first['name']
        : null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "ASSIGN PROCESS",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF3B82F6),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Send to Karhai",
                style: TextStyle(
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<String>(
                  value: selectedVendor,
                  decoration: const InputDecoration(
                    labelText: "Select Workshop",
                    labelStyle: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
                    border: InputBorder.none,
                  ),
                  items: _vendors
                      .map(
                        (v) => DropdownMenuItem(
                          value: v['name'].toString(),
                          child: Text(
                            v['name'].toString(),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B)),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedVendor = v),
                ),
              ),
              const SizedBox(height: 16),
              _popupTextField(
                controller: meterCtrl,
                label: "Meters to Send",
                icon: Icons.straighten_rounded,
                suffix: "MTR",
              ),
              const SizedBox(height: 16),
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
                      double send = double.tryParse(meterCtrl.text) ?? 0;
                      if (send <= 0 || send > originalMeter || selectedVendor == null) return;

                      double pricePerMeter =
                          double.tryParse(item['price_per_meter']?.toString() ?? '0') ??
                          0;

                      final allStock = await SperatevenderlistInPurchaing.getInstance.getVendorStock(widget.vendorName);
                      int existingCount = allStock.where((s) => s['suid'].toString().startsWith(item['uid'].toString()) && s['condition'] == 'khari').length;
                      String suffix = String.fromCharCode(65 + (existingCount % 26));
                      String newSuid = "${item['uid']}$suffix";

                      Map<String, dynamic> newItem = Map.from(item);
                      newItem['id'] =
                          DateTime.now().millisecondsSinceEpoch.toString() + "_khold";
                      newItem['vendor_name'] = selectedVendor;
                      newItem['meter'] = send;
                      newItem['suid'] = newSuid;
                      newItem['type'] = 'k_hold';
                      newItem['condition'] = 'khari';
                      newItem['p_or_r'] = 'expense';
                      newItem['price_per_meter'] = pricePerMeter;
                      newItem['total'] = pricePerMeter * send;
                      newItem['date'] = DateFormat('dd-MM-yyyy').format(DateTime.now());

                      if (send == originalMeter) {
                        await SperatevenderlistInPurchaing.getInstance.updateStock(
                          item['id'].toString(),
                          newItem,
                          widget.vendorName,
                        );
                      } else {
                        await SperatevenderlistInPurchaing.getInstance.addStock(
                          newItem,
                          widget.vendorName,
                        );
                        Map<String, dynamic> remainingData = Map.from(item);
                        remainingData['meter'] = originalMeter - send;
                        remainingData['total'] = (originalMeter - send) * pricePerMeter;
                        await SperatevenderlistInPurchaing.getInstance.updateStock(
                          item['id'].toString(),
                          remainingData,
                          widget.vendorName,
                        );
                      }

                      await Bvendername.getInstance.addLedgerEntry(selectedVendor!, {
                        'name': "${widget.clothName} (Sent to Karhai)",
                        'date': DateFormat('dd-MM-yyyy').format(DateTime.now()),
                        'uid': newSuid,
                        'totalmeter': send,
                        'total_price': 0.0,
                        'per_meter': 0.0,
                        'cash': 0.0,
                        'debit': 0.0,
                      });

                      Navigator.pop(context);
                      _loadData();
                    },
                    child: const Text("Confirm Send", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiveFromKhariDialog(Map<String, dynamic> item) {
    double originalSentMeter = double.tryParse(item['meter'].toString()) ?? 0;
    final receiveMeterCtrl = TextEditingController(text: originalSentMeter.toString());
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
              "RECEIVE DELIVERY",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF10B981),
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
              controller: receiveMeterCtrl,
              label: "Meters Received",
              icon: Icons.straighten_rounded,
              suffix: "MTR",
            ),
            const SizedBox(height: 16),
            _popupTextField(
              controller: rateCtrl,
              label: "Karhai Rate",
              icon: Icons.payments_outlined,
              suffix: "PKR",
            ),
            const SizedBox(height: 24),
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
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    double received = double.tryParse(receiveMeterCtrl.text) ?? 0;
                    double rateValue = double.tryParse(rateCtrl.text) ?? 0;

                    if (received <= 0 || received > originalSentMeter) return;

                    double originalPrice =
                        double.tryParse(item['price_per_meter']?.toString() ?? '0') ??
                        0;
                    double finalPricePerMeter = originalPrice + rateValue;
                    double totalCashAmount = received * finalPricePerMeter;

                    final allStock = await SperatevenderlistInPurchaing.getInstance
                        .getVendorStock(widget.vendorName);
                    String currentSuid = item['suid'].toString();

                    int existingSubCount = allStock
                        .where(
                          (s) =>
                              s['suid'].toString().startsWith(currentSuid) &&
                              s['condition'] == 'shrink',
                        )
                        .length;

                    String suffix = String.fromCharCode(65 + existingSubCount);
                    String newEntitySuid = "$currentSuid$suffix";

                    if (received == originalSentMeter) {
                      Map<String, dynamic> doneData = Map.from(item);
                      doneData['type'] = 'k_done';
                      await SperatevenderlistInPurchaing.getInstance.updateStock(
                        item['id'].toString(),
                        doneData,
                        widget.vendorName,
                      );
                    } else {
                      Map<String, dynamic> remainingData = Map.from(item);
                      remainingData['meter'] = originalSentMeter - received;
                      remainingData['total'] =
                          (originalSentMeter - received) * originalPrice;
                      await SperatevenderlistInPurchaing.getInstance.updateStock(
                        item['id'].toString(),
                        remainingData,
                        widget.vendorName,
                      );

                      Map<String, dynamic> doneData = Map.from(item);
                      doneData['id'] =
                          DateTime.now().millisecondsSinceEpoch.toString() + "_kdone";
                      doneData['meter'] = received;
                      doneData['type'] = 'k_done';
                      doneData['total'] = received * originalPrice;
                      await SperatevenderlistInPurchaing.getInstance.addStock(
                        doneData,
                        widget.vendorName,
                      );
                    }

                    Map<String, dynamic> shrinkData = Map.from(item);
                    shrinkData['id'] =
                        DateTime.now().millisecondsSinceEpoch.toString() + "_shrink";
                    shrinkData['meter'] = received;
                    shrinkData['price_per_meter'] = finalPricePerMeter;
                    shrinkData['total'] = totalCashAmount;
                    shrinkData['suid'] = newEntitySuid;
                    shrinkData['condition'] = 'shrink';
                    shrinkData['type'] = 't_s_hold';
                    shrinkData['date'] = DateFormat('dd-MM-yyyy').format(DateTime.now());

                    await SperatevenderlistInPurchaing.getInstance.addStock(
                      shrinkData,
                      widget.vendorName,
                    );

                    await Bvendername.getInstance.addLedgerEntry(item['vendor_name'] ?? "", {
                      'name': "${widget.clothName} (Received from Karhai)",
                      'date': DateFormat('dd-MM-yyyy').format(DateTime.now()),
                      'uid': item['suid'],
                      'totalmeter': received,
                      'total_price': received * rateValue,
                      'per_meter': rateValue,
                      'cash': 0.0,
                      'debit': received * rateValue,
                    });

                    await KHisabDB.getInstance.addHisab(
                      name: "${widget.clothName} Karhai",
                      description: "Process from ${item['vendor_name'] ?? 'N/A'} on ${DateFormat('dd-MM-yyyy').format(DateTime.now())}",
                      amount: received * rateValue,
                      condition: "karhai",
                      date: DateFormat('dd-MM-yyyy').format(DateTime.now()),
                    );

                    if (!mounted) return;
                    Navigator.pop(context);
                    _loadData();
                  },
                  child: const Text("Confirm Receipt", style: TextStyle(fontWeight: FontWeight.bold)),
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
              "KARHAI STAGE",
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _skipAll,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFFF7ED),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.fast_forward_rounded, size: 18, color: Color(0xFFEA580C)),
              label: const Text(
                "Skip Stage",
                style: TextStyle(color: Color(0xFFEA580C), fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              tabs: const [
                Tab(text: "Ready to Send"),
                Tab(text: "Active Karhai"),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E293B)))
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        children: [
          Expanded(
            child: _summaryBox(
              "STAGE BUFFER", 
              _totalTransferMeters, 
              _totalTransferValue, 
              const Color(0xFF3B82F6),
              Icons.hourglass_empty_rounded,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _summaryBox(
              "IN PRODUCTION", 
              _totalActiveMeters, 
              _totalActiveValue, 
              const Color(0xFF10B981),
              Icons.sync_rounded,
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

  Widget _buildListView(List items, bool isTransfer) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[200]),
            const SizedBox(height: 12),
            Text(
              "No Karhai batches", 
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
                color: (isTransfer ? const Color(0xFF3B82F6) : const Color(0xFF10B981)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isTransfer ? Icons.warehouse_rounded : Icons.gesture_rounded,
                color: isTransfer ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
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
            onTap: () {
              if (isTransfer) {
                _sendDialog(item);
              } else {
                if (item['type'] == 'k_done') {
                  _showDetailsPopup(context, item);
                } else {
                  _showReceiveFromKhariDialog(item);
                }
              }
            },
            trailing: isTransfer
                ? Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.fast_forward_rounded,
                        color: Color(0xFFEA580C),
                        size: 20,
                      ),
                      onPressed: () => _skipToShrink(item),
                    ),
                  )
                : item['type'] == 'k_done'
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28)
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "ACTIVE",
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64748B)),
                        ),
                      ),
          ),
        );
      },
    );
  }

  void _showDetailsPopup(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "PROCESS COMPLETED",
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.w900, 
                color: Colors.green.shade600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Full Transaction Details",
              style: TextStyle(
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
            _detailRow("Quantity Processed", "${item['meter']} Mtr"),
            const Divider(height: 32, color: Color(0xFFE2E8F0)),
            _detailRow("Final Batch Value", "Rs. ${NumberFormat('#,###').format(item['total'])}", isBold: true, valueColor: Colors.green.shade600),
            const SizedBox(height: 16),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Close Report", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
          Text(
            value, 
            style: TextStyle(
              color: valueColor ?? const Color(0xFF1E293B), 
              fontSize: 14, 
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _popupTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? suffix,
    FocusNode? focusNode,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
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
