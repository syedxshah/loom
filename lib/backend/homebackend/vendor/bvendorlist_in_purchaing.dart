import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

class BvendorlistInPurchaing {
  static const T_active_vendors = 'T_active_vendors';
  static const C_id = 'id';
  static const C_name = 'name';
  static const C_uid = 'uid';

  BvendorlistInPurchaing._();
  static final BvendorlistInPurchaing getInstance = BvendorlistInPurchaing._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final directory = await getApplicationSupportDirectory();
    final path = join(directory.path, "VENDOR", "PurchasingActiveList.db");

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $T_active_vendors (
            $C_id INTEGER PRIMARY KEY AUTOINCREMENT,
            $C_name TEXT,
            $C_uid TEXT UNIQUE
          )
        ''');
      },
    );
  }

  Future<int> addActiveVendor(String name, String uid) async {
    final db = await database;
    return await db.insert(T_active_vendors, {
      C_name: name,
      C_uid: uid,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, dynamic>>> getActiveVendors() async {
    final db = await database;
    return await db.query(T_active_vendors, orderBy: "$C_id DESC");
  }

  Future<int> removeActiveVendor(String uid) async {
    final db = await database;
    return await db.delete(
      T_active_vendors,
      where: '$C_uid = ?',
      whereArgs: [uid],
    );
  }
}
