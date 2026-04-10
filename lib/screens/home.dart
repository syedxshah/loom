import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';

// Your Imports
import 'package:loom/routes/routes.dart';
import 'package:loom/screens/Home/customer/customer.dart';
import 'package:loom/screens/Home/customer/khata.dart';
import 'package:loom/screens/Home/customer/selling.dart';
import 'package:loom/screens/Home/operator/cloth.dart';
import 'package:loom/screens/Home/operator/damage.dart';
import 'package:loom/screens/Home/operator/transcation.dart';
import 'package:loom/screens/Home/vendor/leadger.dart';
import 'package:loom/screens/Home/vendor/purchasing.dart';
import 'package:loom/screens/Home/vendor/vendor.dart';
import 'package:loom/widget/app_logo.dart';
import 'package:loom/widget/skeleton_loader.dart';
import 'package:loom/backend/homebackend/operations/khisab.dart';
import 'package:loom/backend/homebackend/operations/sale.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int currentTransIndex = 0;
  int khataIndex = 0;
  int ledgerIndex = 0;

  String name = "Ansar";
  int _selectedIndex = -1;
  bool _isDashboardLoading = true;
  
  double totalSales = 0; 
  double totalPurchasing = 0;
  double totalExpenses = 0;
  double totalProfit = 0;

  DateTime startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime endDate = DateTime.now();

  final List<Map<String, dynamic>> categories = [
    {
      "category": "Customer",
      "color": Colors.blue,
      "items": [
        {"title": "Customer List", "icon": LucideIcons.users, "idx": 1},
        {"title": "Selling", "icon": LucideIcons.shoppingCart, "idx": 2},
        {"title": "Khata", "icon": LucideIcons.bookOpen, "idx": 6},
      ],
    },
    {
      "category": "Vendor",
      "color": Colors.orange,
      "items": [
        {"title": "Vendor List", "icon": LucideIcons.usersRound, "idx": 0},
        {"title": "Purchasing", "icon": LucideIcons.shoppingBag, "idx": 3},
        {"title": "Ledger", "icon": LucideIcons.clipboardList, "idx": 8},
      ],
    },
    {
      "category": "Operations",
      "color": Colors.blueGrey,
      "items": [
        {"title": "Stock / Cloth", "icon": LucideIcons.layers, "idx": 4},
        {"title": "Transaction", "icon": LucideIcons.arrowLeftRight, "idx": 7},
        {"title": "Return / Damage", "icon": LucideIcons.alertTriangle, "idx": 5},
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) setState(() => _isDashboardLoading = true);
    
    final hisabs = await KHisabDB.getInstance.getAllHisabs();
    final sales = await SaleDB.getInstance.getAllSales();
    
    double s = 0;
    double p = 0;
    double e = 0;

    // Aggregate Sales from sale.db
    for (var item in sales) {
      String? dateStr = item['date'];
      if (dateStr == null) continue;
      try {
        DateTime recordDate = DateFormat('dd-MM-yyyy').parse(dateStr);
        if (_isWithinRange(recordDate)) {
          s += double.tryParse(item['total_amount']?.toString() ?? '0') ?? 0;
        }
      } catch (_) {}
    }

    // Aggregate Purchasing and Expenses
    for (var item in hisabs) {
      String? dateStr = item['date'];
      if (dateStr == null) continue;

      try {
        DateTime recordDate = DateFormat('dd-MM-yyyy').parse(dateStr);
        if (_isWithinRange(recordDate)) {
          double amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0;
          if (item['condition'] == 'purchased') {
            p += amount;
          } else {
            e += amount;
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        totalSales = s;
        totalPurchasing = p;
        totalExpenses = e;
        totalProfit = s - (p + e);
        _isDashboardLoading = false;
      });
    }
  }

  bool _isWithinRange(DateTime date) {
    DateTime start = DateTime(startDate.year, startDate.month, startDate.day);
    DateTime end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    return date.isAfter(start.subtract(const Duration(seconds: 1))) && 
           date.isBefore(end.add(const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: InkWell(
          onTap: () {
            setState(() => _selectedIndex = -1);
            _loadDashboardData();
          },
          child: Row(
            children: [
              const AppLogo(height: 32, showWordmark: false),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "LOOM BUSINESS",
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Text(
                    "Control Center",
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.userCircle, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(LucideIcons.settings, color: Color(0xFF64748B), size: 18),
            onPressed: () => Navigator.pushNamed(context, Routes.setting)
                .then((_) => _loadDashboardData()),
          ),
          IconButton(
            icon: const Icon(LucideIcons.logOut, color: Color(0xFFEF4444), size: 18),
            onPressed: () =>
                Navigator.pushReplacementNamed(context, Routes.password),
          ),
          const SizedBox(width: 15),
        ],
      ),
      body: Row(
        children: [
          // --- SIDE NAVIGATION BAR ---
          Container(
            width: 88,
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                _sideIcon(-1, LucideIcons.layoutDashboard, "Overview"),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  child: Divider(color: Colors.white.withOpacity(0.05), height: 1),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _sideIcon(0, LucideIcons.users, "Vendors"),
                        _sideIcon(1, LucideIcons.contact, "Customers"),
                        _sideIcon(2, LucideIcons.shoppingCart, "Selling"),
                        _sideIcon(3, LucideIcons.shoppingBag, "Purchasing"),
                        _sideIcon(4, LucideIcons.package, "Stock"),
                        _sideIcon(5, LucideIcons.alertCircle, "Return / Damage"),
                        _sideIcon(6, LucideIcons.bookOpenText, "Khata"),
                        _sideIcon(7, LucideIcons.arrowLeftRight, "Ledger"),
                        _sideIcon(8, LucideIcons.clipboardList, "Reports"),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- MAIN CONTENT ---
          Expanded(
            child: ClipRRect(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) =>
                    FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.02, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                child: _selectedIndex == -1
                    ? _buildCategoryDashboard()
                    : _buildDataPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataPage() {
    switch (_selectedIndex) {
      case 0:
        return Vendor(context);
      case 1:
        return Customer(context);
      case 2:
        return SellingPage();
      case 3:
        return PurchasingPage();
      case 4:
        return Cloth(context);
      case 5:
        return Damage(context);
      case 6:
        return Khata(khataIndex, (newIdx) {
          setState(() => khataIndex = newIdx);
        });
      case 7:
        return Transaction(context, currentTransIndex, (newIdx) {
          setState(() => currentTransIndex = newIdx);
        });
      case 8:
        return Leadger(ledgerIndex, (newIdx) {
          setState(() => ledgerIndex = newIdx);
        });
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCategoryDashboard() {
    return ListView(
      key: const ValueKey('dashboard'),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Dashboard Overview",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Real-time business performance analytics",
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            _dateRangeRow(),
          ],
        ),
        const SizedBox(height: 20),
        _isDashboardLoading
            ? const Row(
                children: [
                  SkeletonStatCard(),
                  SkeletonStatCard(),
                  SkeletonStatCard(),
                  SkeletonStatCard(),
                ],
              )
            : Row(
                children: [
                  _statCard("Total Sales", "Rs. ${NumberFormat('#,###').format(totalSales)}", const Color(0xFF10B981), LucideIcons.trendingUp),
                  _statCard("Purchased", "Rs. ${NumberFormat('#,###').format(totalPurchasing)}", const Color(0xFFF59E0B), LucideIcons.shoppingBag),
                  _statCard("Expenses", "Rs. ${NumberFormat('#,###').format(totalExpenses)}", const Color(0xFFEF4444), LucideIcons.receiptText),
                  _statCard("Net Profit", "Rs. ${NumberFormat('#,###').format(totalProfit)}", const Color(0xFF3B82F6), LucideIcons.badgePercent,
                      isDark: true),
                ],
              ),
        const SizedBox(height: 35),
        if (_isDashboardLoading)
          ..._buildSkeletonCategories()
        else
          ...categories.map((cat) => _buildCategorySection(cat)),
      ],
    );
  }

  List<Widget> _buildSkeletonCategories() {
    return List.generate(3, (_) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shimmer.fromColors(
            baseColor: const Color(0xFFE8EDF2),
            highlightColor: const Color(0xFFF5F8FB),
            child: Container(
              height: 14,
              width: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 90,
            ),
            itemCount: 3,
            itemBuilder: (_, _i) => const SkeletonGridCard(),
          ),
          const SizedBox(height: 25),
        ],
      );
    });
  }

  Widget _buildCategorySection(Map<String, dynamic> cat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cat['category'],
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: cat['color'],
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 90,
          ),
          itemCount: cat['items'].length,
          itemBuilder: (context, i) {
            var item = cat['items'][i];
            return _menuCard(
              item['title'],
              item['icon'],
              cat['color'],
              item['idx'],
            );
          },
        ),
        const SizedBox(height: 25),
      ],
    );
  }

  Widget _menuCard(String title, IconData icon, Color color, int targetIdx) {
    return InkWell(
      onTap: () => setState(() => _selectedIndex = targetIdx),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideIcon(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        if (index == -1) {
          _loadDashboardData();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (isSelected)
                  Positioned(
                    left: -20,
                    child: Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                Icon(
                  icon,
                  color: isSelected ? const Color(0xFF3B82F6) : Colors.white.withOpacity(0.4),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
                fontSize: 9,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateRangeRow() {
    return Row(
      children: [
        _dateButton("From", startDate, () => _selectDate(true)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(LucideIcons.arrowRight, size: 14, color: Colors.grey),
        ),
        _dateButton("To", endDate, () => _selectDate(false)),
      ],
    );
  }

  Future<void> _selectDate(bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? startDate : endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
        _loadDashboardData();
      });
    }
  }

  Widget _dateButton(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 9, color: Colors.grey)),
            Text(
              DateFormat('dd MMM').format(date),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
    String label,
    String value,
    Color color,
    IconData icon, {
    bool isDark = false,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isDark ? null : Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: isDark ? color.withOpacity(0.2) : Colors.black.withOpacity(0.03),
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
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  icon,
                  size: 16,
                  color: isDark ? Colors.white.withOpacity(0.5) : color.withOpacity(0.6),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
