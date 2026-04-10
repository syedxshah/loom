import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SellingDB {
  static const String DB_NAME = "selling.db";
  static const String TABLE_NAME = "selling_table";

  static const String C_ID = "id";
  static const String C_NAME = "name";
  static const String C_UID = "uid";
  static const String C_TOTAL_METER = "total_meter";
  static const String C_THAN = "than";
  static const String C_PER_METER_PRICE = "per_meter_price";
  static const String C_TOTAL_PRICE = "total_price";
  static const String C_DATE = "date";
  static const String C_PAYMENT_MODE = "payment_mode";
  static const String C_TOTAL_PROFIT = "total_profit";
  static const String C_PREV_BALANCE = "previous_balance";

  SellingDB._();
  static final SellingDB getInstance = SellingDB._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    // Windows initialization check inside the DB class for safety
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
      version: 6,
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
      "ALTER TABLE $TABLE_NAME ADD COLUMN $C_THAN INTEGER DEFAULT 0",
      "ALTER TABLE $TABLE_NAME ADD COLUMN $C_TOTAL_PRICE REAL DEFAULT 0",
      "ALTER TABLE $TABLE_NAME ADD COLUMN $C_DATE TEXT DEFAULT ''",
      "ALTER TABLE $TABLE_NAME ADD COLUMN $C_PAYMENT_MODE TEXT DEFAULT 'Cash'",
      "ALTER TABLE $TABLE_NAME ADD COLUMN $C_TOTAL_PROFIT REAL DEFAULT 0",
      "ALTER TABLE $TABLE_NAME ADD COLUMN $C_PREV_BALANCE REAL DEFAULT 0",
    ]) {
      try {
        await db.execute(col);
      } catch (e) {
        // Column already exists or table not ready
      }
    }
  }

  Future<void> _createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $TABLE_NAME (
        $C_ID INTEGER PRIMARY KEY AUTOINCREMENT, 
        $C_NAME TEXT,
        $C_UID TEXT,
        $C_TOTAL_METER REAL,
        $C_THAN INTEGER,
        $C_PER_METER_PRICE REAL,
        $C_TOTAL_PRICE REAL,
        $C_DATE TEXT,
        $C_PAYMENT_MODE TEXT,
        $C_TOTAL_PROFIT REAL,
        $C_PREV_BALANCE REAL
      )
    ''');
  }

  Future<int> addSelling({
    required String name,
    required String uid,
    required double totalMeter,
    int than = 0,
    required double perMeterPrice,
    required double totalPrice,
    required String date,
    String paymentMode = 'Cash',
    double totalProfit = 0.0,
    double previousBalance = 0.0,
  }) async {
    final client = await db;
    return await client.insert(TABLE_NAME, {
      C_NAME: name,
      C_UID: uid,
      C_TOTAL_METER: totalMeter,
      C_THAN: than,
      C_PER_METER_PRICE: perMeterPrice,
      C_TOTAL_PRICE: totalPrice,
      C_DATE: date,
      C_PAYMENT_MODE: paymentMode,
      C_TOTAL_PROFIT: totalProfit,
      C_PREV_BALANCE: previousBalance,
    });
  }

  Future<List<Map<String, dynamic>>> getAvailableStock() async {
    final client = await db;
    return await client.query(
      TABLE_NAME,
      where: "$C_UID NOT LIKE ?",
      whereArgs: ['BILL_%'],
      orderBy: "$C_ID DESC",
    );
  }

  Future<List<Map<String, dynamic>>> getBillHistory() async {
    final client = await db;
    return await client.query(
      TABLE_NAME,
      where: "$C_UID LIKE ?",
      whereArgs: ['BILL_%'],
      orderBy: "$C_ID DESC",
    );
  }

  Future<Map<String, dynamic>?> getSaleByUID(String uid) async {
    final client = await db;
    final results = await client.query(
      TABLE_NAME,
      where: "$C_UID = ?",
      whereArgs: [uid],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> deleteSelling(int id) async {
    final client = await db;
    return await client.delete(TABLE_NAME, where: "$C_ID = ?", whereArgs: [id]);
  }

  Future<int> updateStockMeters(int id, double newMeters, int newThan) async {
    final client = await db;
    if (newMeters <= 0) {
      return await client.delete(
        TABLE_NAME,
        where: "$C_ID = ?",
        whereArgs: [id],
      );
    }
    return await client.update(
      TABLE_NAME,
      {C_TOTAL_METER: newMeters, C_THAN: newThan},
      where: "$C_ID = ?",
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getAllSellings() async {
    final client = await db;
    return await client.query(TABLE_NAME, orderBy: "$C_ID DESC");
  }
}
