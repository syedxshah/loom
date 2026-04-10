import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SplitPaymentDB {
  static const String DB_NAME = "split_payments.db";
  static const String TABLE_NAME = "split_payment_log";

  static const String C_ID = "id";
  static const String C_NAME = "name";
  static const String C_SUID = "suid";
  static const String C_PAYMENT_CREDIT = "debit";
  static const String C_PAYMENT_CASH = "cash";
  static const String C_TOTAL = "total";
  static const String C_TABLE_NAME = "table_name";
  static const String C_DATE = "date";

  SplitPaymentDB._();
  static final SplitPaymentDB getInstance = SplitPaymentDB._();
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
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $TABLE_NAME (
            $C_ID INTEGER PRIMARY KEY AUTOINCREMENT,
            $C_NAME TEXT,
            $C_SUID TEXT,
            $C_PAYMENT_CREDIT REAL,
            $C_PAYMENT_CASH REAL,
            $C_TOTAL REAL,
            $C_TABLE_NAME TEXT,
            $C_DATE TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            // Migration: Rename old internal column names to new ones
            await db.execute("ALTER TABLE $TABLE_NAME RENAME COLUMN paymentcredit TO $C_PAYMENT_CREDIT");
            await db.execute("ALTER TABLE $TABLE_NAME RENAME COLUMN paymentcash TO $C_PAYMENT_CASH");
          } catch (e) {
            print("Migration Error: $e");
            // If RENAME fails (older SQLite), try adding columns or handled by app deletion
          }
        }
      },
    );
  }

  Future<int> addSplitRecord({
    required String name,
    required String suid,
    required double debit,
    required double cash,
    required double total,
    required String tableName,
    required String date,
  }) async {
    final client = await db;
    return await client.insert(TABLE_NAME, {
      C_NAME: name,
      C_SUID: suid,
      C_PAYMENT_CREDIT: debit,
      C_PAYMENT_CASH: cash,
      C_TOTAL: total,
      C_TABLE_NAME: tableName,
      C_DATE: date,
    });
  }

  Future<List<Map<String, dynamic>>> getAllRecords() async {
    final client = await db;
    return await client.query(TABLE_NAME, orderBy: "$C_ID DESC");
  }
}
