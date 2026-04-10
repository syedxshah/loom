import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loom/backend/homebackend/vendor/speratevenderlist_in_purchaing.dart';
import 'package:loom/backend/homebackend/vendor/bvendor.dart';
import 'package:loom/backend/homebackend/vendor/bvendername.dart';
import 'package:loom/backend/homebackend/operations/khisab.dart';

class Dying extends StatefulWidget {
  final double totalMeters;
  final String suid;
  final String id;
  final String clothName;
  final String vendorName;
  final double originalPricePerMeter;

  const Dying({
    super.key,
    required this.totalMeters,
    required this.suid,
    required this.id,
    required this.clothName,
    required this.vendorName,
    required this.originalPricePerMeter,
  });

  @override
  State<Dying> createState() => _DyingState();
}

class _DyingState extends State<Dying> {
  final TextEditingController _meterController = TextEditingController();
  final TextEditingController _thanController = TextEditingController();
  final TextEditingController _vendorSearchController = TextEditingController();

  List<Map<String, dynamic>> _dyingVendors = [];
  double _remainingMeters = 0.0;
  List<Map<String, dynamic>> _recentProcesses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _meterController.dispose();
    _thanController.dispose();
    _vendorSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _fetchVendorsFromDb();
    await _calculateRemainingBalance();
    setState(() => _isLoading = false);
  }

  Future<void> _fetchVendorsFromDb() async {
    try {
      final vendors = await Bvendor.getInstance.getAllVendors();
      setState(() => _dyingVendors = vendors);
    } catch (e) {
      debugPrint("Error fetching vendors: $e");
    }
  }

  Future<void> _calculateRemainingBalance() async {
    try {
      final stock = await SperatevenderlistInPurchaing.getInstance
          .getVendorStock(widget.vendorName);

      double alreadyDying = 0.0;
      List<Map<String, dynamic>> processes = [];

      for (var item in stock) {
        if (item['uid'].toString() == widget.suid &&
            item['condition'] == 'dying' &&
            (item['type'] == 'd_hold' || item['type'] == 'd_done')) {
          alreadyDying += double.tryParse(item['meter'].toString()) ?? 0.0;
          processes.add(item);
        }
      }

      setState(() {
        _remainingMeters = widget.totalMeters - alreadyDying;
        _recentProcesses = processes;
      });
    } catch (e) {
      debugPrint("Error calculating balance: $e");
    }
  }

  void _showReceivePopup(Map<String, dynamic> item) {
    double originalSentMeter = double.tryParse(item['meter'].toString()) ?? 0.0;
    final receiveMeterCtrl = TextEditingController(
      text: originalSentMeter.toString(),
    );
    final rateCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "RECEIVE PROCESS",
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
            const SizedBox(height: 20),
            _popupTextField(
              controller: receiveMeterCtrl,
              label: "Meters Received",
              icon: Icons.straighten,
              suffix: "MTR",
            ),
            const SizedBox(height: 16),
            _popupTextField(
              controller: rateCtrl,
              label: "Dying Rate",
              icon: Icons.payments,
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
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    double receivedMtr =
                        double.tryParse(receiveMeterCtrl.text) ?? 0;
                    double addedRate = double.tryParse(rateCtrl.text) ?? 0;

                    if (receivedMtr <= 0 || receivedMtr > originalSentMeter) return;

                    // Logic 1: Calculate Prices
                    double finalPricePerMeter =
                        widget.originalPricePerMeter + addedRate;
                    double totalValue = receivedMtr * finalPricePerMeter;

                    // Logic 2: Handle SUID and Naming
                    String currentDyingSuid = item['suid'].toString();
                    String newCondition = 'print';
                    String newType = 't_p_hold';

                    final allStock = await SperatevenderlistInPurchaing.getInstance
                        .getVendorStock(widget.vendorName);
                    int existingCount = allStock
                        .where(
                          (s) =>
                              s['suid'].toString().startsWith(currentDyingSuid) &&
                              s['condition'] == newCondition,
                        )
                        .length;
                    String suffix = String.fromCharCode(65 + (existingCount % 26));
                    String newEntitySuid = "$currentDyingSuid$suffix";

                    // Logic 4: Update Existing Dying Entry
                    if (receivedMtr == originalSentMeter) {
                      Map<String, dynamic> updateData = Map.from(item);
                      updateData['type'] = 'd_done';
                      await SperatevenderlistInPurchaing.getInstance.updateStock(
                        item['id'].toString(),
                        updateData,
                        widget.vendorName,
                      );
                    } else {
                      // Partial receive
                      Map<String, dynamic> remainData = Map.from(item);
                      remainData['meter'] = originalSentMeter - receivedMtr;
                      remainData['total'] =
                          (originalSentMeter - receivedMtr) *
                          widget.originalPricePerMeter;
                      await SperatevenderlistInPurchaing.getInstance.updateStock(
                        item['id'].toString(),
                        remainData,
                        widget.vendorName,
                      );

                      Map<String, dynamic> donePart = Map.from(item);
                      donePart['id'] =
                          "${DateTime.now().millisecondsSinceEpoch}_part_done";
                      donePart['meter'] = receivedMtr;
                      donePart['type'] = 'd_done';
                      donePart['total'] =
                          receivedMtr * widget.originalPricePerMeter;
                      await SperatevenderlistInPurchaing.getInstance.addStock(
                        donePart,
                        widget.vendorName,
                      );
                    }

                    // Logic 5: Create Next Stage entry
                    Map<String, dynamic> nextStage = Map.from(item);
                    nextStage['id'] =
                        "${DateTime.now().millisecondsSinceEpoch}_$newCondition";
                    nextStage['meter'] = receivedMtr;
                    nextStage['price_per_meter'] = finalPricePerMeter;
                    nextStage['total'] = totalValue;
                    nextStage['suid'] = newEntitySuid;
                    nextStage['condition'] = newCondition;
                    nextStage['type'] = newType;
                    nextStage['date'] = DateFormat(
                      'dd-MM-yyyy',
                    ).format(DateTime.now());

                    await SperatevenderlistInPurchaing.getInstance.addStock(
                      nextStage,
                      widget.vendorName,
                    );

                    // Add to Dying Vendor's Ledger (Received Status - Final cost)
                    await Bvendername.getInstance
                        .addLedgerEntry(item['vendor_name'] ?? "", {
                          'name': "${widget.clothName} (Received from Dying)",
                          'date': DateFormat('dd-MM-yyyy').format(DateTime.now()),
                          'uid': item['suid'],
                          'totalmeter': receivedMtr,
                          'total_price': receivedMtr * addedRate,
                          'per_meter': addedRate,
                          'cash': 0.0,
                          'debit': receivedMtr * addedRate,
                        });

                    // Add to General Hisab Table
                    await KHisabDB.getInstance.addHisab(
                      name: "${widget.clothName} Dying",
                      description: "Process from ${item['vendor_name'] ?? 'N/A'} on ${DateFormat('dd-MM-yyyy').format(DateTime.now())}",
                      amount: receivedMtr * addedRate,
                      condition: "dying",
                      date: DateFormat('dd-MM-yyyy').format(DateTime.now()),
                    );

                    if (!mounted) return;
                    Navigator.pop(context);
                    _loadInitialData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Confirm",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddDyingPopup() {
    _meterController.text = _remainingMeters.toString();
    _thanController.text = "1";
    _vendorSearchController.clear();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "NEW PROCESS",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF59E0B),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Dying Assignment",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Autocomplete<String>(
                  optionsBuilder: (val) => _dyingVendors
                      .map((v) => v['name'].toString())
                      .where(
                        (n) => n.toLowerCase().contains(val.text.toLowerCase()),
                      ),
                  onSelected: (s) => _vendorSearchController.text = s,
                  fieldViewBuilder: (ctx, ctrl, fNode, onSub) => _popupTextField(
                    controller: ctrl,
                    label: "Select Batching Unit",
                    icon: Icons.factory,
                    focusNode: fNode,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _popupTextField(
                        controller: _thanController,
                        label: "Than",
                        icon: Icons.layers,
                        suffix: "QTY",
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _popupTextField(
                        controller: _meterController,
                        label: "Meters",
                        icon: Icons.straighten,
                        suffix: "MTR",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      double entMtr = double.tryParse(_meterController.text) ?? 0.0;
                      String vName = _vendorSearchController.text.trim();
                      if (entMtr > _remainingMeters || entMtr <= 0 || vName.isEmpty)
                        return;

                      String suffix = String.fromCharCode(
                        65 + (_recentProcesses.length % 26),
                      );
                      String newSuid = "${widget.suid}$suffix";

                      await SperatevenderlistInPurchaing.getInstance.addStock({
                        'id': DateTime.now().millisecondsSinceEpoch.toString(),
                        'cloth_name': widget.clothName,
                        'vendor_name': vName,
                        'uid': widget.suid,
                        'suid': newSuid,
                        'date': DateFormat('dd-MM-yyyy').format(DateTime.now()),
                        'than': int.tryParse(_thanController.text) ?? 0,
                        'meter': entMtr,
                        'price_per_meter': widget.originalPricePerMeter,
                        'total': entMtr * widget.originalPricePerMeter,
                        'type': 'd_hold',
                        'condition': 'dying',
                        'p_or_r': 'expense',
                      }, widget.vendorName);

                      // Add to Dying Vendor's Ledger (Sent Status - No cost yet)
                      await Bvendername.getInstance.addLedgerEntry(vName, {
                        'name': "${widget.clothName} (Sent to Dying)",
                        'date': DateFormat('dd-MM-yyyy').format(DateTime.now()),
                        'uid': newSuid,
                        'totalmeter': entMtr,
                        'total_price': 0.0,
                        'per_meter': 0.0,
                        'cash': 0.0,
                        'debit': 0.0,
                      });

                      if (!mounted) return;
                      Navigator.pop(dialogContext);
                      _loadInitialData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Save Batch",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDyingPopup,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E293B)))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Dying In-Process",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildProcessList()),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "STOCK INVENTORY",
                    style: TextStyle(
                      color: Colors.blue.shade400,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${_remainingMeters.toStringAsFixed(1)} Mtr",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.layers_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _headerQuickStat(
                label: "Total Supply",
                value: "${widget.totalMeters.toInt()}m",
                icon: Icons.inventory_2_outlined,
              ),
              const SizedBox(width: 40),
              _headerQuickStat(
                label: "Assigned",
                value: "${(widget.totalMeters - _remainingMeters).toInt()}m",
                icon: Icons.assignment_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerQuickStat({required String label, required String value, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF64748B), size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w600),
            ),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProcessList() {
    if (_recentProcesses.isEmpty)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              "No active processes",
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    return ListView.builder(
      itemCount: _recentProcesses.length,
      itemBuilder: (context, index) {
        final item = _recentProcesses[index];
        bool isDone = item['type'] == 'd_done';
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            onTap: isDone
                ? () => _showDetailsPopup(context, item)
                : () => _showReceivePopup(item),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDone ? const Color(0xFF10B981) : const Color(0xFF3B82F6)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isDone ? Icons.check_circle_outline : Icons.pending_outlined,
                color: isDone ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                size: 24,
              ),
            ),
            title: Text(
              item['vendor_name'] ?? "N/A",
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1E293B)),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "${item['suid']} • ${item['date']}",
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${item['meter']} Mtr",
                  style: TextStyle(
                    color: const Color(0xFF1E293B),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isDone ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isDone ? "COMPLETED" : "IN PROCESS",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isDone ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "PROCESS COMPLETED",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF10B981),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
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
            _detailRow("Quantity Received", "${item['meter']} Mtr"),
            _detailRow("Service Rate", "Rs. ${item['price_per_meter'] - widget.originalPricePerMeter}/mtr"),
            _detailRow("Loom Base Cost", "Rs. ${widget.originalPricePerMeter}/mtr"),
            const Divider(height: 32, color: Color(0xFFE2E8F0)),
            _detailRow("Total Value", "Rs. ${item['total']}", isBold: true, valueColor: const Color(0xFF10B981)),
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
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
          ),
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
