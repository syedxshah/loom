import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

class BCustomerLedgerDB {
  // Table and Column Constants
  static const T_active_customers = 'T_active_customers';
  static const C_id = 'id';
  static const C_invoice_id = 'invoice_id';
  static const C_item = 'item';
  static const C_meter = 'meter';
  static const C_than = 'than';
  static const C_total = 'total';
  static const C_type = 'type'; // "purchased" or "return"
  static const C_date = 'date';
  static const C_paid = 'paid_amount';
  static const C_credit = 'credit_amount';

  BCustomerLedgerDB._();
  static final BCustomerLedgerDB getInstance = BCustomerLedgerDB._();

  // Cache opened databases to prevent memory leaks
  final Map<String, Database> _databases = {};

  /// Gets the specific database for a customer.
  /// If it doesn't exist, it creates the .db file and the table.
  Future<Database> getDatabase(String uid) async {
    if (_databases.containsKey(uid) && _databases[uid]!.isOpen) return _databases[uid]!;

    Database db = await _initDatabase(uid);
    _databases[uid] = db;
    return db;
  }

  Future<Database> _initDatabase(String uid) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final directory = await getApplicationSupportDirectory();
    final path = join(
      directory.path,
      "CUSTOMER",
      "AllCustomer_Data",
      "customer_$uid.db",
    );

    // Ensure the folder exists
    final file = File(path);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createTable(db); // Ensure table exists before migrating
        await _migrate(db);
      },
      onOpen: (db) async {
        await _createTable(db);
        await _migrate(db);
      },
    );
  }

  Future<void> _createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $T_active_customers (
        $C_id INTEGER PRIMARY KEY AUTOINCREMENT,
        $C_invoice_id TEXT,
        $C_item TEXT,
        $C_meter TEXT,
        $C_than TEXT,
        $C_total TEXT,
        $C_type TEXT,
        $C_date TEXT,
        $C_paid TEXT,
        $C_credit TEXT
      )
    ''');
  }

  Future<void> _migrate(Database db) async {
    final List<String> columnsToAdd = [
      "ALTER TABLE $T_active_customers ADD COLUMN $C_date TEXT DEFAULT ''",
      "ALTER TABLE $T_active_customers ADD COLUMN $C_paid TEXT DEFAULT '0'",
      "ALTER TABLE $T_active_customers ADD COLUMN $C_credit TEXT DEFAULT '0'",
    ];

    for (final col in columnsToAdd) {
      try {
        await db.execute(col);
      } catch (e) {
        // Column probably exists or table doesn't exist (handled by _createTable)
      }
    }
  }

  // Helper method to add a transaction to a specific customer's DB
  Future<int> addTransaction(String uid, Map<String, dynamic> data) async {
    final db = await getDatabase(uid);
    return await db.insert(
      T_active_customers,
      data,
    );
  }

  // Helper method to fetch all transactions for a specific customer
  Future<List<Map<String, dynamic>>> getTransactions(String uid) async {
    final db = await getDatabase(uid);
    return await db.query(T_active_customers, orderBy: "$C_id DESC");
  }

  /// Syncs the opening balance from the main customer record to their private ledger.
  /// Only adds if an 'OPENING_BAL' invoice doesn't exist yet.
  Future<void> syncOpeningBalance(String uid, String balance, String date) async {
    final db = await getDatabase(uid);
    final List<Map<String, dynamic>> existing = await db.query(
      T_active_customers,
      where: "$C_invoice_id = ?",
      whereArgs: ["OPENING_BAL"],
    );

    if (existing.isEmpty && double.tryParse(balance) != 0) {
      await db.insert(T_active_customers, {
        C_invoice_id: "OPENING_BAL",
        C_item: "Opening Balance",
        C_meter: "N/A",
        C_than: "N/A",
        C_total: balance,
        C_type: "Initial",
        C_date: date,
        C_paid: "0",
        C_credit: balance,
      });
    }
  }
}
