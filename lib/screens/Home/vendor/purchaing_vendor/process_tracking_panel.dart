import 'package:flutter/material.dart';
import 'package:loom/screens/Home/vendor/purchaing_vendor/step_%20list/dying.dart';
import 'package:loom/screens/Home/vendor/purchaing_vendor/step_%20list/kharai.dart';
import 'package:loom/screens/Home/vendor/purchaing_vendor/step_%20list/print.dart';
import 'package:loom/screens/Home/vendor/purchaing_vendor/step_%20list/ready.dart';
import 'package:loom/screens/Home/vendor/purchaing_vendor/step_%20list/shrink.dart';
import 'package:loom/screens/Home/vendor/purchaing_vendor/step_%20list/packing.dart';

class ProcessTrackingPanel extends StatefulWidget {
  final double totalMeters;
  final String suid;
  final String id; // Added: Original ID from parent
  final String clothName; // Added: Cloth name from parent
  final String vendorName; // Added: Vendor name from parent
  final double originalPricePerMeter;

  const ProcessTrackingPanel({
    super.key,
    required this.totalMeters,
    required this.suid,
    required this.id,
    required this.clothName,
    required this.vendorName,
    required this.originalPricePerMeter,
  });

  @override
  State<ProcessTrackingPanel> createState() => _ProcessTrackingPanelState();
}

class _ProcessTrackingPanelState extends State<ProcessTrackingPanel> {
  String _activeStep = "Dying";

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 20,
                left: 30,
                right: 30,
                child: Container(height: 2, color: Colors.grey.shade300),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _buildProcessStep(1, Icons.colorize, "Dying"),
                  _buildProcessStep(2, Icons.print, "Print"),
                  _buildProcessStep(3, Icons.gesture, "Karhai"),
                  _buildProcessStep(4, Icons.compress, "Shrink"),
                  _buildProcessStep(5, Icons.inventory_2, "Packing"),
                  _buildProcessStep(6, Icons.verified_outlined, "Ready"),
                ],
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(child: _buildBottomContent()),
      ],
    );
  }

  Widget _buildBottomContent() {
    if (_activeStep == "Dying") {
      return Dying(
        totalMeters: widget.totalMeters,
        suid: widget.suid,
        id: widget.id,
        clothName: widget.clothName,
        vendorName: widget.vendorName,
        originalPricePerMeter: widget.originalPricePerMeter,
      );
    } else if (_activeStep == "Print") {
      return PrintScreen(
        totalMeters: widget.totalMeters,
        suid: widget.suid,
        id: widget.id,
        clothName: widget.clothName,
        vendorName: widget.vendorName,
      );
    } else if (_activeStep == "Karhai") {
      return KhariScreen(
        suid: widget.suid,
        vendorName: widget.vendorName,
        clothName: widget.clothName,
      );
    } else if (_activeStep == "Shrink") {
      return ShrinkScreen(
        suid: widget.suid,
        vendorName: widget.vendorName,
        clothName: widget.clothName,
      );
    } else if (_activeStep == "Packing") {
      return PackingScreen(
        suid: widget.suid,
        vendorName: widget.vendorName,
        clothName: widget.clothName,
      );
    } else if (_activeStep == "Ready") {
      return ReadyScreen(
        suid: widget.suid,
        vendorName: widget.vendorName,
        clothName: widget.clothName,
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction, color: Colors.amber, size: 40),
            const SizedBox(height: 10),
            Text(
              _activeStep.isEmpty
                  ? "Select a process"
                  : "$_activeStep: Under Development",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildProcessStep(int stepNumber, IconData icon, String label) {
    bool isActive = _activeStep == label;
    return InkWell(
      onTap: () => setState(() => _activeStep = label),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? Colors.blue : const Color(0xFF455A64),
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isActive ? Colors.blue : const Color(0xFF455A64),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Step $stepNumber",
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
