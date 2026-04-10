import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:loom/backend/homebackend/vendor/bvendor.dart';
import 'package:loom/widget/popup.dart';
import 'package:loom/widget/rowbutton.dart';
import 'package:loom/widget/skeleton_loader.dart';
import 'package:intl/intl.dart';
import 'package:loom/backend/homebackend/vendor/bvendername.dart';

Widget Vendor(BuildContext context) {
  return const VendorPage();
}

class VendorPage extends StatefulWidget {
  const VendorPage({super.key});
  @override
  State<VendorPage> createState() => _VendorPageState();
}

class _VendorPageState extends State<VendorPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _uidController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();

  List<Map<String, dynamic>> _vendors = [];
  String _searchQuery = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _uidController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  String _generateSpecialUid() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(
      8,
      (index) => chars[Random().nextInt(chars.length)],
    ).join();
  }

  Future<void> _loadData() async {
    if (!_isLoading) setState(() => _isLoading = true);
    final data = await Bvendor.getInstance.getallVendors();
    if (!mounted) return;
    setState(() {
      _vendors = data;
      _uidController.text = _generateSpecialUid();
      _isLoading = false;
    });
  }

  void _clearFields() {
    _nameController.clear();
    _phoneController.clear();
    _addressController.clear();
    _emailController.clear();
    _balanceController.clear();
  }

  Future<void> _deleteVendor(String uid, String name) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Delete Vendor?"),
            content: Text("Are you sure you want to remove '$name'?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Delete",
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await Bvendor.getInstance.deleteVendor(uid);
      await _loadData();
    }
  }

  void _editVendor(Map<String, dynamic> item) {
    _nameController.text = item[Bvendor.C_name] ?? "";
    _phoneController.text = item[Bvendor.C_phone] ?? "";
    _addressController.text = item[Bvendor.C_address] ?? "";
    _emailController.text = item[Bvendor.C_email] ?? "";
    _uidController.text = item[Bvendor.C_uid] ?? "";
    _balanceController.text = item[Bvendor.C_balance] ?? "";

    showAddPopup(
      context: context,
      title: "Edit Vendor",
      fields: [
        buildPopupField(_nameController, "Name", LucideIcons.user),
        buildPopupField(_phoneController, "Phone", LucideIcons.phone,
            type: TextInputType.phone),
        buildPopupField(_addressController, "Address", LucideIcons.mapPin),
        buildPopupField(_emailController, "Email", LucideIcons.mail,
            type: TextInputType.emailAddress),
        buildPopupField(_uidController, "UID (Fixed)", LucideIcons.hash),
        buildPopupField(_balanceController, "Balance", LucideIcons.dollarSign,
            type: TextInputType.number),
      ],
      onSubmit: () async {
        bool success = await Bvendor.getInstance.updateVendor(
          item[Bvendor.C_id],
          _nameController.text.trim(),
          _phoneController.text.trim(),
          _addressController.text.trim(),
          _emailController.text.trim(),
          _balanceController.text.trim(),
        );
        if (success && mounted) {
          await _loadData();
          Navigator.pop(context);
          _clearFields();
        }
      },
    );
  }

  void _showDetails(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item[Bvendor.C_name],
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.trash2,
                      color: Colors.redAccent, size: 22),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _deleteVendor(item[Bvendor.C_uid], item[Bvendor.C_name]);
                  },
                ),
              ],
            ),
            const Divider(),
            _detailRow("UID", item[Bvendor.C_uid]),
            _detailRow("Phone", item[Bvendor.C_phone]),
            _detailRow("Email", item[Bvendor.C_email]),
            _detailRow("Address", item[Bvendor.C_address]),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text("Opening Balance: ",
                    style: TextStyle(fontSize: 16)),
                Text(
                  "${item[Bvendor.C_balance] ?? '0'}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text("$label: ${value ?? 'N/A'}",
          style: const TextStyle(fontSize: 16)),
    );
  }

  Future<void> _onVendorSubmit() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) return;
    bool success = await Bvendor.getInstance.insertVendor(
      _nameController.text.trim(),
      _uidController.text.trim(),
      _phoneController.text.trim(),
      _addressController.text.trim(),
      _emailController.text.trim(),
      _balanceController.text.trim(),
    );
    if (success && mounted) {
      // Instantly create the ALLVENDERLEedger database and sync the opening balance
      String currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
      await Bvendername.getInstance.syncOpeningBalance(
        _nameController.text.trim(),
        _balanceController.text.trim(),
        currentDate,
      );

      await _loadData();
      Navigator.pop(context);
      _clearFields();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    List<Map<String, dynamic>> filteredVendors = _vendors.where((vendor) {
      final name = vendor[Bvendor.C_name].toString().toLowerCase();
      final uid = vendor[Bvendor.C_uid].toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) ||
          uid.contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [_buildHeader(), _buildAddButton()],
          ),
        ),
        if (!_isLoading && _vendors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: "Search by name or ID...",
                prefixIcon:
                    const Icon(LucideIcons.search, size: 18, color: Colors.grey),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
        Expanded(
          child: _isLoading
              ? buildSkeletonList(count: 6)
              : filteredVendors.isEmpty
                  ? (_searchQuery.isEmpty
                      ? _buildEmptyView()
                      : _buildNoResultView())
                  : _buildListView(filteredVendors),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Text(
          "Vendors",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(width: 10),
        if (!_isLoading && _vendors.isNotEmpty)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              "${_vendors.length}",
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Colors.green),
            ),
          ),
      ],
    );
  }

  Widget _buildAddButton() {
    return ElevatedButton(
      onPressed: () {
        _clearFields();
        _uidController.text = _generateSpecialUid();
        showAddPopup(
          context: context,
          title: "Add New Vendor",
          fields: [
            buildPopupField(_nameController, "Name", LucideIcons.user),
            buildPopupField(_phoneController, "Phone", LucideIcons.phone,
                type: TextInputType.phone),
            buildPopupField(
                _addressController, "Address", LucideIcons.mapPin),
            buildPopupField(_emailController, "Email", LucideIcons.mail),
            buildPopupField(
                _uidController, "UID (Auto)", LucideIcons.hash),
            buildPopupField(
                _balanceController, "Balance", LucideIcons.dollarSign,
                type: TextInputType.number),
          ],
          onSubmit: _onVendorSubmit,
        );
      },
      style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, elevation: 0),
      child: rowbutton("Add New Vendor", LucideIcons.userPlus),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> list) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, _i) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = list[index];
        final bool isIncomplete = item[Bvendor.C_complete] == 0;
        final String balance = item[Bvendor.C_balance]?.toString() ?? "0";

        return InkWell(
          onTap: () => _showDetails(item),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isIncomplete
                  ? Colors.red.withOpacity(0.04)
                  : Colors.green.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isIncomplete
                    ? Colors.red.withOpacity(0.2)
                    : Colors.green.withOpacity(0.15),
              ),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: isIncomplete
                    ? Colors.red.withOpacity(0.1)
                    : Colors.green.withOpacity(0.12),
                child: Icon(
                  LucideIcons.userCircle,
                  color: isIncomplete ? Colors.red : Colors.green,
                  size: 22,
                ),
              ),
              title: Text(
                item[Bvendor.C_name] ?? "",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      "ID: ${item[Bvendor.C_uid]} • ${item[Bvendor.C_phone]}"),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "Balance: $balance",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  if (isIncomplete) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Icon(LucideIcons.alertCircle,
                            size: 12, color: Colors.red),
                        SizedBox(width: 4),
                        Text(
                          "Fill complete details",
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.pencil,
                        color: Colors.blueGrey, size: 20),
                    onPressed: () => _editVendor(item),
                  ),
                  const Icon(LucideIcons.chevronRight,
                      size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.usersRound,
                size: 64, color: Colors.green.withOpacity(0.25)),
          ),
          const SizedBox(height: 16),
          const Text(
            "No Vendors Found",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Add your first vendor to start purchasing.",
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.searchX, size: 50, color: Colors.grey),
          const SizedBox(height: 10),
          Text("No results for '$_searchQuery'",
              style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
