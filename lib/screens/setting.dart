import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingState();
}

class _SettingState extends State<SettingPage> {
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: Could not open link")),
        );
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.info, color: Colors.blueGrey, size: 22),
            SizedBox(width: 10),
            Text("Developer Info"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(LucideIcons.user, "Dev: Syed Ansar Ali", null),
            _infoRow(LucideIcons.building2, "Company: IAnsar", null),
            _infoRow(
              LucideIcons.phone,
              "WhatsApp: +923197081824",
              () => _launchURL("https://wa.me/923197081824"),
            ),
            _infoRow(
              LucideIcons.mail,
              "Email: syedansaroffical@gmail.com",
              () => _launchURL("mailto:syedansaroffical@gmail.com?subject=Loom Business Support"),
            ),
            const Divider(height: 30),
            const Center(
              child: Text(
                "License: 100% Free",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ),
            const Center(
              child: Text(
                "Subscription Based Model",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(icon, size: 18, color: onTap != null ? Colors.blueAccent : Colors.blueGrey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: onTap != null ? Colors.blueAccent : Colors.black87,
                  decoration: onTap != null ? TextDecoration.underline : TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(String title, String hint) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Save")),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete All Data?"),
        content: const Text(
          "Warning: This will wipe all your business records from this device permanently.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("DELETE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blueGrey,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          _sectionHeader("Subscription & License"),
          _settingTile(
            "Subscription Status",
            LucideIcons.badgeCheck,
            Colors.green,
            () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Subscription: Active (Free Tier)")),
            ),
          ),

          _sectionHeader("Profile & Security"),
          _settingTile(
            "Change Business Name",
            LucideIcons.userCog,
            Colors.blue,
            () => _showEditDialog("Change Name", "Enter new name"),
          ),
          _settingTile(
            "Change Password",
            LucideIcons.shieldCheck,
            Colors.orange,
            () => _showEditDialog("Change Password", "Enter new password"),
          ),

          _sectionHeader("Data Management"),
          _settingTile(
            "Backup to Cloud",
            LucideIcons.cloudUpload,
            Colors.indigo,
            () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Backup started...")),
            ),
          ),
          _settingTile(
            "Restore from Backup",
            LucideIcons.cloudDownload,
            Colors.teal,
            () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Searching files...")),
            ),
          ),

          _sectionHeader("About & Support"),
          _settingTile(
            "Developer Information",
            LucideIcons.info,
            Colors.blueGrey,
            () => _showAboutDialog(context),
          ),

          _sectionHeader("Danger Zone"),
          _settingTile(
            "Delete All Data",
            LucideIcons.trash2,
            Colors.red,
            () => _showDeleteConfirmation(context),
            isDestructive: true,
          ),

          const SizedBox(height: 50),
          const Center(
            child: Text(
              "Loom Business v1.0.0",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _settingTile(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDestructive ? Colors.red : Colors.black87,
          ),
        ),
        trailing: const Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
