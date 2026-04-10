import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SaleDB {
  static const String DB_NAME = "sale.db";
  static const String TABLE_NAME = "sales_table";

  static const String C_ID = "id";
  static const String C_INV_UID = "inv_uid";
  static const String C_NAME = "name";
  static const String C_THAN = "than";
  static const String C_METER = "meter";
  static const String C_PER_METER_AMOUNT = "per_meter_amount";
  static const String C_COST_PRICE = "cost_price";
  static const String C_TOTAL_AMOUNT = "total_amount";
  static const String C_DATE = "date";

  SaleDB._();
  static final SaleDB getInstance = SaleDB._();
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
      version: 3,
      onCreate: (db, version) async => await _createTable(db),
      onUpgrade: (db, oldVersion, newVersion) async => await _migrate(db),
      onOpen: (db) async {
        await _createTable(db);
        await _migrate(db);
      },
    );
  }

  Future<void> _migrate(Database db) async {
    for (final col in [
      "ALTER TABLE $TABLE_NAME ADD COLUMN $C_COST_PRICE REAL DEFAULT 0",
    ]) {
      try {
        await db.execute(col);
      } catch (e) {
        // Already exists
      }
    }
  }

  Future<void> _createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $TABLE_NAME (
        $C_ID INTEGER PRIMARY KEY AUTOINCREMENT, 
        $C_INV_UID TEXT,
        $C_NAME TEXT,
        $C_THAN INTEGER,
        $C_METER REAL,
        $C_PER_METER_AMOUNT REAL,
        $C_COST_PRICE REAL,
        $C_TOTAL_AMOUNT REAL,
        $C_DATE TEXT
      )
    ''');
  }

  Future<int> addSale({
    required String invUid,
    required String name,
    required int than,
    required double meter,
    required double perMeterAmount,
    required double costPrice,
    required double totalAmount,
    required String date,
  }) async {
    final client = await db;
    return await client.insert(TABLE_NAME, {
      C_INV_UID: invUid,
      C_NAME: name,
      C_THAN: than,
      C_METER: meter,
      C_PER_METER_AMOUNT: perMeterAmount,
      C_COST_PRICE: costPrice,
      C_TOTAL_AMOUNT: totalAmount,
      C_DATE: date,
    });
  }

  Future<List<Map<String, dynamic>>> getAllSales() async {
    final client = await db;
    return await client.query(TABLE_NAME, orderBy: "$C_ID DESC");
  }

  Future<Map<String, dynamic>?> getSaleById(int id) async {
    final client = await db;
    final results = await client.query(
      TABLE_NAME,
      where: "$C_ID = ?",
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getSalesByInvoice(String invUid) async {
    final client = await db;
    return await client.query(
      TABLE_NAME,
      where: "$C_INV_UID = ?",
      whereArgs: [invUid],
      orderBy: "$C_ID DESC",
    );
  }
}
