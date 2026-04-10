import 'package:flutter/material.dart';

const String appLogoAssetPath = 'assests/images/icon.jpeg';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.height = 44,
    this.showWordmark = false,
    this.wordmarkColor = const Color(0xFF173A5A),
  });

  final double height;
  final bool showWordmark;
  final Color wordmarkColor;

  @override
  Widget build(BuildContext context) {
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(height * 0.18),
      child: Image.asset(
        appLogoAssetPath,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );

    if (!showWordmark) {
      return logo;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 8),
        Text(
          "Loom",
          style: TextStyle(
            fontSize: height * 0.46,
            fontWeight: FontWeight.w700,
            color: wordmarkColor,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
