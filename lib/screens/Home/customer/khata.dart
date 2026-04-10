import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loom/screens/Home/customer/khata/split_log.dart';
import 'package:loom/widget/rowmenu.dart';

// 1. Pass the current index and a callback function as parameters
Widget Khata(int currentIndex, Function(int) onTabChanged) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // --- 1. HEADER SECTION ---
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Text(
          "Khata Summary",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.blueGrey,
          ),
        ),
      ),

      // --- 2. STATS CARDS SECTION ---
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Credit Button
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: () => onTabChanged(0),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentIndex == 0 ? Colors.orange.withOpacity(0.08) : Colors.transparent,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.zero,
                  ).copyWith(
                    overlayColor: WidgetStateProperty.all(Colors.grey.withOpacity(0.1)),
                  ),
                  child: rowmenu("Baqi / Udhaar", CupertinoIcons.creditcard_fill),
                ),
              ),
              const SizedBox(width: 12),
              // Cash Button
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: () => onTabChanged(1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentIndex == 1 ? Colors.blue.withOpacity(0.08) : Colors.transparent,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.zero,
                  ).copyWith(
                    overlayColor: WidgetStateProperty.all(Colors.grey.withOpacity(0.1)),
                  ),
                  child: rowmenu("Diya / Cash", CupertinoIcons.checkmark_shield_fill),
                ),
              ),
            ],
          ),
        ),
      ),

      const SizedBox(height: 20),
      const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

      // --- 3. SWITCHING LOGIC ---
      Expanded(
        child: currentIndex == 0 
           ? const SplitLogScreen(filter: 'credit') 
           : const SplitLogScreen(filter: 'cash')
      ),
    ],
  );
}
