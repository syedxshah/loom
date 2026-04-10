import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:loom/backend/homebackend/operations/cloth_db.dart';
import 'package:loom/widget/popup.dart';
import 'package:loom/widget/rowbutton.dart';
import 'package:loom/widget/skeleton_loader.dart';

Widget Cloth(BuildContext context) {
  return const ClothScreen();
}

class ClothScreen extends StatefulWidget {
  const ClothScreen({super.key});

  @override
  State<ClothScreen> createState() => _ClothScreenState();
}

class _ClothScreenState extends State<ClothScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final clothNameController = TextEditingController();
  List<Map<String, dynamic>> _clothList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshCloths();
  }

  @override
  void dispose() {
    clothNameController.dispose();
    super.dispose();
  }

  Future<void> _refreshCloths() async {
    if (!_isLoading) setState(() => _isLoading = true);
    final data = await Bcloth.getInstance.getAllCloths();
    if (!mounted) return;
    setState(() {
      _clothList = data;
      _isLoading = false;
    });
  }

  void onClothSubmit() async {
    if (clothNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a Cloth Name"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    await Bcloth.getInstance.addCloth(clothNameController.text);
    clothNameController.clear();
    if (mounted) Navigator.pop(context);
    _refreshCloths();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Cloth added successfully!"),
        backgroundColor: Colors.purple,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // --- HEADER ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Cloth Inventory",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Colors.blueGrey,
                ),
              ),
              ElevatedButton(
                onPressed: () => showAddPopup(
                  context: context,
                  title: "Add New Cloth",
                  fields: [
                    buildPopupField(
                      clothNameController,
                      "Cloth Name",
                      LucideIcons.layers,
                    ),
                  ],
                  onSubmit: onClothSubmit,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                ),
                child: rowbutton("New Cloth", LucideIcons.layers),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

        // --- CONTENT ---
        Expanded(
          child: _isLoading
              ? buildSkeletonList(count: 5)
              : _clothList.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: _clothList.length,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemBuilder: (context, index) {
                        final item = _clothList[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side:
                                BorderSide(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFF3E5F5),
                              child: Icon(
                                LucideIcons.layers,
                                color: Colors.purple,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              item[Bcloth.C_NAME],
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            subtitle:
                                Text("ID: ${item[Bcloth.C_ID]}"),
                            trailing: IconButton(
                              icon: const Icon(
                                LucideIcons.trash2,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              onPressed: () async {
                                await Bcloth.getInstance
                                    .deleteCloth(item[Bcloth.C_ID]);
                                _refreshCloths();
                              },
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.layers,
              size: 64,
              color: Colors.purple.withOpacity(0.25),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "No Cloth Items Found",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Your fabric inventory is empty.\nAdd your first cloth type to start tracking stock.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
