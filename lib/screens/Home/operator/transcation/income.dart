import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Widget income() {
  return Container(
    width: double.infinity,
    color: Colors.white,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.05), // Green for Transactions
            shape: BoxShape.circle,
          ),
          child: Icon(
            CupertinoIcons.list_bullet_indent,
            size: 80,
            color: Colors.green.withOpacity(0.2),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "No Transactions Yet",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "All your income will appear here in a detailed list.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.5),
        ),
      ],
    ),
  );
}
