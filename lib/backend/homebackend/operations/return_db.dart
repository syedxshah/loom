import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ReturnDB {
  static const String DB_NAME = "returns.db";
  static const String TABLE_NAME = "return_log";

  static const String C_ID = "id";
  static const String C_UID = "uid";
  static const String C_NAME = "name";
  static const String C_TYPE = "type"; // 'Return' or 'Damage'
  static const String C_DATE = "date";
  static const String C_REASON = "reason";
  static const String C_METERS = "meters";
  static const String C_PRICE = "price";

  ReturnDB._();
  static final ReturnDB getInstance = ReturnDB._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final directory = await getApplicationSupportDirectory();
    final String pathDir = join(directory.path, "OPERATOR");
    final Directory operatorDir = Directory(pathDir);

    if (!await operatorDir.exists()) {
      await operatorDir.create(recursive: true);
    }

    final String dbPath = join(pathDir, DB_NAME);

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $TABLE_NAME (
            $C_ID INTEGER PRIMARY KEY AUTOINCREMENT,
            $C_UID TEXT,
            $C_NAME TEXT,
            $C_TYPE TEXT,
            $C_DATE TEXT,
            $C_REASON TEXT,
            $C_METERS REAL,
            $C_PRICE REAL
          )
        ''');
      },
    );
  }

  Future<int> addReturn({
    required String uid,
    required String name,
    required String type,
    required String date,
    required String reason,
    required double meters,
    required double price,
  }) async {
    final client = await db;
    return await client.insert(TABLE_NAME, {
      C_UID: uid,
      C_NAME: name,
      C_TYPE: type,
      C_DATE: date,
      C_REASON: reason,
      C_METERS: meters,
      C_PRICE: price,
    });
  }

  Future<List<Map<String, dynamic>>> getAllReturns() async {
    final client = await db;
    return await client.query(TABLE_NAME, orderBy: "$C_ID DESC");
  }

  Future<int> deleteReturn(int id) async {
    final client = await db;
    return await client.delete(TABLE_NAME, where: "$C_ID = ?", whereArgs: [id]);
  }
}
