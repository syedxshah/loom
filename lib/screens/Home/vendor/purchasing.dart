import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:loom/backend/homebackend/vendor/bvendor.dart';
import 'package:loom/backend/homebackend/vendor/bvendorlist_in_purchaing.dart';
import 'package:loom/backend/homebackend/vendor/speratevenderlist_in_purchaing.dart';
import 'package:loom/screens/Home/vendor/purchaing_vendor/purchasing_seprate.dart';
import 'package:loom/widget/rowbutton.dart';
import 'package:loom/widget/skeleton_loader.dart';

class PurchasingPage extends StatefulWidget {
  const PurchasingPage({super.key});
  @override
  State<PurchasingPage> createState() => _PurchasingPageState();
}

class _PurchasingPageState extends State<PurchasingPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const String _uidKey = Bvendor.C_uid;
  List<Map<String, dynamic>> _allVendorsFromDB = [];
  List<Map<String, dynamic>> _selectedVendors = [];
  String _searchQuery = "";
  String? _selectedVendorUid;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _fetchVendors();
    await _loadActiveVendors();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchVendors() async {
    final data = await Bvendor.getInstance.getallVendors();
    if (mounted) setState(() => _allVendorsFromDB = data);
  }

  Future<void> _loadActiveVendors() async {
    final activeData = await BvendorlistInPurchaing.getInstance.getActiveVendors();
    if (mounted) setState(() => _selectedVendors = List.from(activeData));
  }

  Future<void> _handleDelete(Map<String, dynamic> vendor) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Vendor?"),
        content: Text("Remove ${vendor['name']} from the active list?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Remove", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await BvendorlistInPurchaing.getInstance.removeActiveVendor(vendor[_uidKey].toString());
      await _loadActiveVendors();
    }
  }

  void _showVendorSelectionPopup() {
    String popupSearch = "";
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) {
          List<Map<String, dynamic>> filtered = _allVendorsFromDB
              .where((v) => v['name'].toString().toLowerCase().contains(popupSearch.toLowerCase()))
              .toList();
          return AlertDialog(
            title: const Text("Select Vendor"),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (val) => setPopupState(() => popupSearch = val),
                    decoration: InputDecoration(
                      hintText: "Search vendor...",
                      prefixIcon: const Icon(LucideIcons.search, size: 18, color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final v = filtered[index];
                        final String vendorUid = v[_uidKey].toString();
                        bool added = _selectedVendors.any((sel) => sel[_uidKey].toString() == vendorUid);
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: added ? Colors.grey.shade200 : Colors.orange.withOpacity(0.12),
                            child: Icon(LucideIcons.usersRound, size: 16, color: added ? Colors.grey : Colors.orange),
                          ),
                          title: Text(v['name'], style: TextStyle(color: added ? Colors.grey : Colors.black, fontWeight: FontWeight.w500)),
                          trailing: added ? const Icon(LucideIcons.checkCircle, size: 18, color: Colors.green) : null,
                          onTap: added ? null : () async {
                            await BvendorlistInPurchaing.getInstance.addActiveVendor(v['name'], vendorUid);
                            await SperatevenderlistInPurchaing.getInstance.openPurchasingDB(vendorUid);
                            await _loadActiveVendors();
                            if (context.mounted) Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_selectedVendorUid != null) {
      return purchasingseprate(_selectedVendorUid!, () => setState(() => _selectedVendorUid = null));
    }
    List<Map<String, dynamic>> displayList = _selectedVendors
        .where((v) => v['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Purchasing", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.blueGrey)),
                GestureDetector(onTap: _showVendorSelectionPopup, child: rowbutton("New Vendor", LucideIcons.plus)),
              ],
            ),
          ),
          if (!_isLoading && _selectedVendors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: "Search vendors...",
                  prefixIcon: const Icon(LucideIcons.search, size: 18, color: Colors.grey),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? buildSkeletonList(count: 5)
                : _selectedVendors.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.05), shape: BoxShape.circle),
                              child: Icon(LucideIcons.shoppingBag, size: 64, color: Colors.orange.withOpacity(0.25)),
                            ),
                            const SizedBox(height: 16),
                            const Text("No Vendors Added", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                            const SizedBox(height: 6),
                            Text("Tap 'New Vendor' to add a purchasing vendor.", style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: displayList.length,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemBuilder: (ctx, index) {
                          final vendor = displayList[index];
                          final String actualUid = vendor[_uidKey].toString();
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                            child: ListTile(
                              onTap: () => setState(() => _selectedVendorUid = actualUid),
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.blueGrey.shade50,
                                child: Text("${index + 1}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              ),
                              title: Text(vendor['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: const Text("Tap to view details"),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 20), onPressed: () => _handleDelete(vendor)),
                                  const Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey),
                                ],
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
}
