import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

class Bvendor {
  static const T_vendor = 'T_vendor';
  static const C_id = 'id';
  static const C_uid = 'uid';
  static const C_name = 'name';
  static const C_phone = 'phone';
  static const C_address = 'address';
  static const C_email = 'email';
  static const C_balance = 'balance';
  static const C_complete = 'iscomplete'; // Added for profile status

  Bvendor._();
  static final Bvendor getInstance = Bvendor._();
  Database? _database;

  Future<Database> get database async {
    _database ??= await openVendorDB();
    return _database!;
  }

  Future<Database> openVendorDB() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final directory = await getApplicationSupportDirectory();
    final path = join(directory.path, "VENDOR\\vendor.db");

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $T_vendor (
            $C_id INTEGER PRIMARY KEY AUTOINCREMENT,
            $C_name TEXT,
            $C_uid TEXT,
            $C_phone TEXT,
            $C_address TEXT,
            $C_email TEXT,
            $C_balance TEXT,
            $C_complete INTEGER DEFAULT 0
          )
        ''');
      },

      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE $T_vendor ADD COLUMN $C_complete INTEGER DEFAULT 0",
          );
        }
      },
    );
  }

  Future<bool> insertVendor(
    String name,
    String uid,
    String phone,
    String address,
    String email,
    String balance,
  ) async {
    final db = await database;
    // Marked complete only if Name, Phone, and Email are present
    int completeStatus =
        (name.isNotEmpty && phone.isNotEmpty && email.isNotEmpty) ? 1 : 0;

    int result = await db.insert(T_vendor, {
      C_name: name,
      C_uid: uid,
      C_phone: phone,
      C_address: address,
      C_email: email,
      C_balance: balance,
      C_complete: completeStatus,
    });
    return result > 0;
  }

  Future<bool> updateVendor(
    int id,
    String name,
    String phone,
    String address,
    String email,
    String balance,
  ) async {
    final db = await database;
    int completeStatus =
        (name.isNotEmpty && phone.isNotEmpty && email.isNotEmpty) ? 1 : 0;

    int result = await db.update(
      T_vendor,
      {
        C_name: name,
        C_phone: phone,
        C_address: address,
        C_email: email,
        C_balance: balance,
        C_complete: completeStatus,
      },
      where: "$C_id = ?",
      whereArgs: [id],
    );
    return result > 0;
  }

  Future<bool> updateVendorBalance(String uid, String newBalance) async {
    final db = await database;
    int result = await db.update(
      T_vendor,
      {C_balance: newBalance},
      where: "$C_uid = ?",
      whereArgs: [uid],
    );
    return result > 0;
  }

  Future<bool> deleteVendor(String uid) async {
    final db = await database;
    int result = await db.delete(
      T_vendor,
      where: "$C_uid = ?",
      whereArgs: [uid],
    );
    return result > 0;
  }

  Future<List<Map<String, dynamic>>> getAllVendors() async {
    final db = await database;
    return await db.query(T_vendor, orderBy: "$C_id DESC");
  }

  Future<List<Map<String, dynamic>>> getallVendors() async {
    final db = await database; // Ensure your database getter is called

    // This returns all columns (id, name, phone, address, etc.) as a List of Maps
    final List<Map<String, dynamic>> maps = await db.query(T_vendor);

    return maps;
  }
}
