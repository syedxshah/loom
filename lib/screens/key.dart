import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:loom/backend/keygen.dart';
import 'package:loom/backend/password.dart';
import 'package:loom/backend/status.dart';
import 'package:loom/widget/app_logo.dart';
import 'package:loom/widget/popup.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

class KeyGen extends StatefulWidget {
  const KeyGen({super.key});
  @override
  State<KeyGen> createState() => _KeyGenState();
}

class _KeyGenState extends State<KeyGen> {
  String _activationStatus = "";
  String _detectedDuration = "";
  final TextEditingController _licenseInputController = TextEditingController();
  String _generatedSystemKey = "";
  bool _isValidating = false;
  final Generator _generator = Generator();

  @override
  void initState() {
    super.initState();
    _initSystemKey();
  }

  void _initSystemKey() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    String rawKey = String.fromCharCodes(
      Iterable.generate(16, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
    setState(() {
      _generatedSystemKey =
          "${rawKey.substring(0, 4)}-${rawKey.substring(4, 8)}-${rawKey.substring(8, 12)}-${rawKey.substring(12, 16)}";
    });
  }

  Future<void> _handleActivation() async {
    final userInput = _licenseInputController.text.trim();
    if (userInput.isEmpty) {
      _showError("Please enter the License Key");
      return;
    }

    setState(() => _isValidating = true);

    try {
      final Map<String, String> result = await _generator.genkey(
        _generatedSystemKey,
        'Liaqat',
      );

      String matchedDuration = "";
      result.forEach((tier, key) {
        if (userInput == key) matchedDuration = tier;
      });

      if (matchedDuration.isNotEmpty) {
        setState(() {
          _activationStatus = userInput;
          _detectedDuration = matchedDuration;
        });
        _showPasswordPopup();
      } else {
        _showError("Invalid License. Key does not match system.");
      }
    } catch (e) {
      _showError("Activation Error: $e");
    } finally {
      setState(() => _isValidating = false);
    }
  }

  void _showPasswordPopup() {
    final passController = TextEditingController();
    final confirmPassController = TextEditingController();

    showAddPopup(
      context: context,
      title: "Set Admin Password",
      fields: [
        buildPopupField(
          passController,
          "New Password",
          LucideIcons.lockKeyhole,
        ),
        buildPopupField(
          confirmPassController,
          "Confirm Password",
          LucideIcons.checkCircle,
        ),
      ],
      onSubmit: () async {
        if (passController.text.isNotEmpty &&
            passController.text == confirmPassController.text) {
          await PasswordStorage.setPassword(passController.text);
          await StatusStorage.setActivationStatus(
            _activationStatus,
            _detectedDuration,
          );

          if (!mounted) return;
          Navigator.of(context, rootNavigator: true).pop();
          Navigator.pushReplacementNamed(context, '/password');
        } else {
          _showError("Passwords do not match!");
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("License Activation"),
        centerTitle: true,
        elevation: 0.5,
      ),
      body: Center(
        // Center for Windows alignment
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 500,
          ), // Better for Desktop
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogo(height: 80),
              const SizedBox(height: 40),
              const Text(
                "SYSTEM KEY",
                style: TextStyle(
                  color: Colors.grey,
                  letterSpacing: 1.5,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              _buildSystemKeyTile(),
              const SizedBox(height: 30),
              TextField(
                controller: _licenseInputController,
                decoration: const InputDecoration(
                  labelText: "Enter License Key",
                  prefixIcon: const Icon(LucideIcons.ticket, size: 20),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isValidating ? null : _handleActivation,
                  child: _isValidating
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "ACTIVATE NOW",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: _contactSupport,
                icon: const Icon(
                  LucideIcons.messageCircle,
                  color: Colors.green,
                  size: 20,
                ),
                label: const Text("Get Key from Developer"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemKeyTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _generatedSystemKey,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.blue),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _generatedSystemKey));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("System Key Copied!")),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _contactSupport() async {
    final Uri url = Uri.parse("https://wa.me/923197081824");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication))
      _showError("WhatsApp not found");
  }
}
