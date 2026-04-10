import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loom/widget/rowmenu.dart';
import 'package:loom/screens/Home/vendor/leadger/lvendor.dart';
import 'package:loom/screens/Home/vendor/leadger/lcustomer.dart';

Widget Leadger(int activeIndex, Function(int) onTabChanged) {
  // Shared button style
  final ButtonStyle ledgerButtonStyle =
      ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
      ).copyWith(
        overlayColor: WidgetStateProperty.all(Colors.grey.withOpacity(0.1)),
      );

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // --- 1. HEADER SECTION ---
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Text(
          "Ledger Reports",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.blueGrey,
          ),
        ),
      ),

      // --- 2. CATEGORY SELECTOR SECTION ---
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => onTabChanged(0),
                style: ledgerButtonStyle,
                child: rowmenu(
                  "Customer",
                  CupertinoIcons.person_2_fill,
                  // Color highlight logic can be added here
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: ElevatedButton(
                onPressed: () => onTabChanged(1),
                style: ledgerButtonStyle,
                child: rowmenu("Vendor", CupertinoIcons.person_3_fill),
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 20),
      const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

      // --- 3. DATA DISPLAY SECTION ---
      Expanded(
        child: Container(
          width: double.infinity,
          color: Colors.white,
          // Show content based on activeIndex
          child: _buildLedgerContent(activeIndex),
        ),
      ),
    ],
  );
}

// Helper to switch views
Widget _buildLedgerContent(int index) {
  if (index == 1) {
    return Lvendor();
  }
  return LCustomer();
}
