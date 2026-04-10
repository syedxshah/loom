import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Widget cash() {
  return Container(
    width: double.infinity,
    color: Colors.white,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.blueGrey.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            CupertinoIcons.book_fill,
            size: 80,
            color: Colors.blueGrey.withOpacity(0.2),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "Your Cash was Clear",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "All debts and payments are currently settled.\nPending balances will appear here.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.5),
        ),
      ],
    ),
  );
}
