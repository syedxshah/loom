import 'package:flutter/material.dart';

Widget rowbutton(String data, IconData icon) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F6FA),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFDCE4EC)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          data,
          style: const TextStyle(
            color: Color(0xFF2F4A62),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Icon(icon, color: const Color(0xFF2F4A62), size: 18),
      ],
    ),
  );
}
