import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SperatevenderlistInPurchaing {

  SperatevenderlistInPurchaing._();
  static final SperatevenderlistInPurchaing getInstance =
      SperatevenderlistInPurchaing._();

  Database? _db;

  Future<Database> openPurchasingDB(String uid) async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final directory = await getApplicationSupportDirectory();
    final String dbPath = join(
      directory.path,
      "VENDOR",
      "AllVendorsList",
      "$uid.db",
    );

    final Directory vendorDir = Directory(
      join(directory.path, "VENDOR", "AllVendorsList"),
    );
    if (!await vendorDir.exists()) {
      await vendorDir.create(recursive: true);
    }

    _db = await openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, version) async {
        await _createTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE stock ADD COLUMN cash REAL DEFAULT 0.0",
          );
          await db.execute(
            "ALTER TABLE stock ADD COLUMN credit REAL DEFAULT 0.0",
          );
        }
        if (oldVersion < 3) {
          await db.execute("ALTER TABLE stock ADD COLUMN suid TEXT");
          await db.execute("ALTER TABLE stock ADD COLUMN p_or_r TEXT");
        }
      },
    );

    return _db!;
  }

  Future<void> _createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock (
        id TEXT PRIMARY KEY, 
        cloth_name TEXT,
        vendor_name TEXT,
        uid TEXT,
        suid TEXT,
        date TEXT,
        than INTEGER,
        meter REAL,
        price_per_meter REAL,
        bilti_per_meter REAL,
        total REAL,
        cash REAL,
        credit REAL,
        type TEXT,
        condition TEXT,
        p_or_r TEXT
      )
    ''');
  }

  Future<void> addStock(Map<String, dynamic> data, String uid) async {
    final db = await openPurchasingDB(uid);
    await _createTable(db);
    await db.insert(
      'stock',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // New Update Method for transitioning stock phases
  Future<void> updateStock(
    String id,
    Map<String, dynamic> data,
    String uid,
  ) async {
    final db = await openPurchasingDB(uid);
    await db.update('stock', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getVendorStock(String uid) async {
    final db = await openPurchasingDB(uid);
    try {
      return await db.query('stock', orderBy: "CAST(id AS INTEGER) DESC");
    } catch (e) {
      return [];
    }
  }

  Future<String> getNextId(String uid) async {
    final db = await openPurchasingDB(uid);
    try {
      final List<Map<String, dynamic>> res = await db.rawQuery(
        'SELECT MAX(CAST(uid AS INTEGER)) as max_id FROM stock',
      );
      int maxId = (res.first['max_id'] as int?) ?? 0;
      return (maxId + 1).toString();
    } catch (e) {
      // Fallback in case of table not existing yet or other errors
      return "1";
    }
  }
}
