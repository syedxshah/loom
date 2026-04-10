import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StatusStorage {
  // STRICT: Only uses Application Support Directory
  static Future<String> get _localPath async {
    final directory = await getApplicationSupportDirectory();
    // Ensure the directory exists (Windows pe kabhi kabhi create karni parti hai)
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  static Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/activation_status.json');
  }

  static Future<void> setActivationStatus(String key, String duration) async {
    final file = await _localFile;
    DateTime now = DateTime.now();
    DateTime expiry;

    // Fixed logic for Duration
    if (duration == 'trial') {
      expiry = now.add(const Duration(days: 7));
    } else if (duration == 'month1') {
      expiry = DateTime(now.year, now.month + 1, now.day);
    } else if (duration == 'month3') {
      expiry = DateTime(now.year, now.month + 3, now.day);
    } else if (duration == 'month6') {
      expiry = DateTime(now.year, now.month + 6, now.day);
    } else if (duration == 'month12') {
      expiry = DateTime(now.year + 1, now.month, now.day);
    } else if (duration == 'lifetime') {
      expiry = DateTime(9999, 12, 31);
    } else {
      expiry = now;
    }

    Map<String, dynamic> data = {
      "key": key,
      "activation_date": now.toIso8601String(),
      "expiry_date": expiry.toIso8601String(),
      "duration": duration,
      "is_active": true,
    };

    await file.writeAsString(json.encode(data));
  }

  static Future<Map<String, dynamic>?> getStatus() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) return null;

      String contents = await file.readAsString();
      return json.decode(contents) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearStatus() async {
    final file = await _localFile;
    if (await file.exists()) await file.delete();
  }
}
