import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:loom/backend/homebackend/customer/bcustomer.dart';
import 'package:loom/backend/homebackend/customer/bcustomerlist_in_purchaing.dart';
import 'package:loom/widget/popup.dart';
import 'package:intl/intl.dart';
import 'package:loom/widget/rowbutton.dart';
import 'package:loom/widget/skeleton_loader.dart';

Widget Customer(BuildContext context) {
  return const CustomerPage();
}

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});
  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _currentUidCount = 1;
  List<Map<String, dynamic>> _customers = [];
  String _searchQuery = "";
  bool _isLoading = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _uidController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _uidController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    if (!_isLoading) setState(() => _isLoading = true);
    final dbHelper = BCustomer.getInstance;
    final savedCustomers = await dbHelper.getAllCustomers();
    int lastId = await dbHelper.getLastUid();
    if (!mounted) return;
    setState(() {
      _customers = List.from(savedCustomers);
      _currentUidCount = lastId + 1;
      _uidController.text = _currentUidCount.toString();
      _isLoading = false;
    });
  }

  void _clear() {
    _nameController.clear();
    _cityController.clear();
    _phoneController.clear();
    _addressController.clear();
    _balanceController.clear();
  }

  Future<void> _deleteCustomer(String uid, String name) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Delete Customer?"),
            content: Text("Are you sure you want to remove '$name'?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Delete",
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await BCustomer.getInstance.deleteCustomer(uid);
      await _initData();
    }
  }

  void _editCustomer(Map<String, dynamic> item) {
    _nameController.text = item[BCustomer.C_customername] ?? "";
    _cityController.text = item[BCustomer.C_customercity] ?? "";
    _phoneController.text = item[BCustomer.C_customerphone] ?? "";
    _addressController.text = item[BCustomer.C_customeraddress] ?? "";
    _uidController.text = item[BCustomer.C_customeruid].toString();
    _balanceController.text = item[BCustomer.C_customerbalance] ?? "";

    showAddPopup(
      context: context,
      title: "Edit Customer",
      fields: [
        buildPopupField(_nameController, "Name", LucideIcons.user),
        buildPopupField(_cityController, "City", LucideIcons.building2),
        buildPopupField(_phoneController, "Phone", LucideIcons.phone,
            type: TextInputType.phone),
        buildPopupField(_addressController, "Address", LucideIcons.mapPin),
        buildPopupField(_uidController, "UID (Fixed)", LucideIcons.hash),
        buildPopupField(_balanceController, "Balance", LucideIcons.dollarSign,
            type: TextInputType.number),
      ],
      onSubmit: () async {
        bool isUpdated = await BCustomer.getInstance.updateCustomer(
          item[BCustomer.C_customerid].toString(),
          _nameController.text.trim(),
          _phoneController.text.trim(),
          _addressController.text.trim(),
          _cityController.text.trim(),
          _balanceController.text.trim(),
        );
        if (isUpdated && mounted) {
          await _initData();
          Navigator.pop(context);
          _clear();
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
      builder: (context) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item[BCustomer.C_customername],
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.trash2,
                      color: Colors.redAccent, size: 22),
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteCustomer(
                      item[BCustomer.C_customeruid].toString(),
                      item[BCustomer.C_customername],
                    );
                  },
                ),
              ],
            ),
            const Divider(),
            _detailRow("UID", item[BCustomer.C_customeruid]),
            _detailRow("Phone", item[BCustomer.C_customerphone]),
            _detailRow("City", item[BCustomer.C_customercity]),
            _detailRow("Address", item[BCustomer.C_customeraddress]),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text("Opening Balance: ",
                    style: TextStyle(fontSize: 16)),
                Text(
                  "${item[BCustomer.C_customerbalance] ?? '0'}",
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

  Future<void> _onCustomerSubmit() async {
    if (_nameController.text.isEmpty) return;
    String customerUid = _uidController.text.trim();

    bool isSaved = await BCustomer.getInstance.addcustomer(
      _nameController.text.trim(),
      customerUid,
      _phoneController.text.trim(),
      _addressController.text.trim(),
      _cityController.text.trim(),
      _balanceController.text.trim(),
    );

    if (isSaved && mounted) {
      await BCustomerLedgerDB.getInstance.getDatabase(customerUid);
      String dateToday = DateFormat('dd-MM-yyyy').format(DateTime.now());
      await BCustomerLedgerDB.getInstance.syncOpeningBalance(
        customerUid, 
        _balanceController.text.trim(), 
        dateToday
      );
      await _initData();
      Navigator.pop(context);
      _clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Customer Added & Ledger Created for ID: $customerUid"),
          backgroundColor: Colors.blueGrey,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    List<Map<String, dynamic>> filteredCustomers =
        _customers.where((customer) {
      final name =
          customer[BCustomer.C_customername].toString().toLowerCase();
      final city =
          customer[BCustomer.C_customercity].toString().toLowerCase();
      final uid = customer[BCustomer.C_customeruid].toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) ||
          city.contains(_searchQuery.toLowerCase()) ||
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
        if (!_isLoading && _customers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: "Search name, city or ID...",
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
              : filteredCustomers.isEmpty
                  ? (_searchQuery.isEmpty
                      ? _buildEmptyView()
                      : _buildNoResultView())
                  : _buildListView(filteredCustomers),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Text(
          "Customers",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(width: 10),
        if (!_isLoading && _customers.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              "${_customers.length}",
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Colors.blue),
            ),
          ),
      ],
    );
  }

  Widget _buildAddButton() {
    return ElevatedButton(
      onPressed: () {
        _clear();
        _uidController.text = _currentUidCount.toString();
        showAddPopup(
          context: context,
          title: "Add New Customer",
          fields: [
            buildPopupField(_nameController, "Name", LucideIcons.user),
            buildPopupField(_cityController, "City", LucideIcons.building2),
            buildPopupField(_phoneController, "Phone", LucideIcons.phone,
                type: TextInputType.phone),
            buildPopupField(
                _addressController, "Address", LucideIcons.mapPin),
            buildPopupField(_uidController, "UID", LucideIcons.hash),
            buildPopupField(
                _balanceController, "Balance", LucideIcons.dollarSign,
                type: TextInputType.number),
          ],
          onSubmit: _onCustomerSubmit,
        );
      },
      style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, elevation: 0),
      child: rowbutton("Add New Customer", LucideIcons.userPlus),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> list) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, _i) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = list[index];
        final bool isIncomplete = item[BCustomer.C_complete] == 0;
        final String balance =
            item[BCustomer.C_customerbalance]?.toString() ?? "0";

        return InkWell(
          onTap: () => _showDetails(item),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isIncomplete
                  ? Colors.red.withOpacity(0.04)
                  : Colors.blue.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isIncomplete
                    ? Colors.red.withOpacity(0.12)
                    : Colors.blue.withOpacity(0.12),
              ),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: isIncomplete
                    ? Colors.red.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
                child: Text(
                  item[BCustomer.C_customeruid]?.toString() ?? "",
                  style: TextStyle(
                    fontSize: 12,
                    color: isIncomplete ? Colors.red : Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                item[BCustomer.C_customername] ?? "Unknown",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${item[BCustomer.C_customercity]} | ${item[BCustomer.C_customerphone]}",
                  ),
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
                    onPressed: () => _editCustomer(item),
                  ),
                  const Icon(LucideIcons.chevronRight,
                      size: 16, color: Colors.blueGrey),
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
              color: Colors.blue.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.users,
                size: 64, color: Colors.blue.withOpacity(0.25)),
          ),
          const SizedBox(height: 16),
          const Text(
            "No Customers Found",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Add your first customer to get started.",
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
          Text(
            "No results for '$_searchQuery'",
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
