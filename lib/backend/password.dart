import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PasswordStorage {
  static const _keyPassword = 'user_password';

  static Future<File> _storeFile() async {
    final directory = await getApplicationSupportDirectory();

    return File('${directory.path}${Platform.pathSeparator}password.json');
  }

  static Future<Map<String, dynamic>> _readStore() async {
    final file = await _storeFile();
    if (!await file.exists()) {
      return <String, dynamic>{};
    }
    final content = await file.readAsString();
    if (content.isEmpty) {
      return <String, dynamic>{};
    }
    return jsonDecode(content) as Map<String, dynamic>;
  }

  static Future<void> _writeStore(Map<String, dynamic> store) async {
    final file = await _storeFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(store));
  }

  static Future<void> setPassword(String password) async {
    final store = await _readStore();
    store[_keyPassword] = password;
    await _writeStore(store);
  }

  static Future<String?> getPassword() async {
    final store = await _readStore();
    final value = store[_keyPassword];
    return value is String ? value : null;
  }

  static Future<void> deletePassword() async {
    final store = await _readStore();
    store.remove(_keyPassword);
    await _writeStore(store);
  }
}
