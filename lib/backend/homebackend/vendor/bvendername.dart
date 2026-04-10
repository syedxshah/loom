import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class Bvendername {
  Bvendername._();
  static final Bvendername getInstance = Bvendername._();

  // Cache databases per vendor name to prevent cross-contamination
  final Map<String, Database> _databases = {};

  Future<Database> openVendorLedgerDB(String vendorName) async {
    // Return cached db if still open
    if (_databases.containsKey(vendorName) && _databases[vendorName]!.isOpen) {
      return _databases[vendorName]!;
    }

    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final directory = await getApplicationSupportDirectory();
    
    // Path: VENDORS/ALLVENDERLEedger/vendername.db
    final String dbPath = join(
      directory.path,
      "VENDORS",
      "ALLVENDERLEedger",
      "$vendorName.db",
    );

    final Directory ledgerDir = Directory(
      join(directory.path, "VENDORS", "ALLVENDERLEedger"),
    );
    
    if (!await ledgerDir.exists()) {
      await ledgerDir.create(recursive: true);
    }

    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await _createTable(db);
      },
      onOpen: (db) async {
        await _createTable(db);
      },
    );

    _databases[vendorName] = db;
    return db;
  }

  Future<void> _createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        date TEXT,
        uid TEXT,
        totalmeter REAL,
        total_price REAL,
        per_meter REAL,
        cash REAL,
        debit REAL
      )
    ''');
  }

  Future<void> addLedgerEntry(String vendorName, Map<String, dynamic> data) async {
    final db = await openVendorLedgerDB(vendorName);
    await db.insert(
      'ledger',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getLedgerEntries(String vendorName) async {
    final db = await openVendorLedgerDB(vendorName);
    try {
      return await db.query('ledger', orderBy: "id DESC");
    } catch (e) {
      return [];
    }
  }

  /// Returns only entries with actual data (filters out NULL/empty rows)
  Future<List<Map<String, dynamic>>> getValidLedgerEntries(String vendorName) async {
    final all = await getLedgerEntries(vendorName);
    return all.where((e) {
      double d = double.tryParse(e['debit']?.toString() ?? '0') ?? 0;
      double c = double.tryParse(e['cash']?.toString() ?? '0') ?? 0;
      return d != 0 || c != 0 || (e['name'] != null && e['name'].toString().isNotEmpty);
    }).toList();
  }

  /// Vendor balance rules:
  /// Rule 1: Only 1 row (Opening Balance) → cash column value. -1200 = Udhaar, 1200 = Jamah.
  /// Rule 2: Multiple rows → LAST row's debit value only. Negative = Udhaar, Positive = Jamah.
  Future<double> getRunningBalance(String vendorName) async {
    final entries = await getValidLedgerEntries(vendorName);
    
    if (entries.isEmpty) return 0.0;

    // Rule 1: Only 1 row (Opening Balance) → return cash value directly
    if (entries.length == 1) {
      return double.tryParse(entries.first['cash']?.toString() ?? '0') ?? 0.0;
    }

    // Rule 2: Multiple rows → return last (most recent) row's debit value
    // entries are ordered by id DESC, so entries.first = most recent row
    return double.tryParse(entries.first['debit']?.toString() ?? '0') ?? 0.0;
  }

  Future<void> deleteLedgerEntry(String vendorName, int id) async {
    final db = await openVendorLedgerDB(vendorName);
    await db.delete('ledger', where: 'id = ?', whereArgs: [id]);
  }

  /// Cleans up any NULL/empty rows from the ledger
  Future<void> cleanupNullRows(String vendorName) async {
    final db = await openVendorLedgerDB(vendorName);
    await db.delete(
      'ledger',
      where: 'name IS NULL AND date IS NULL AND uid IS NULL AND cash IS NULL AND debit IS NULL',
    );
  }

  Future<void> syncOpeningBalance(String vendorName, String balanceStr, String date) async {
    if (vendorName.isEmpty) return;

    // First, clean up any NULL rows that may have been created previously
    await cleanupNullRows(vendorName);

    final db = await openVendorLedgerDB(vendorName);
    final List<Map<String, dynamic>> existing = await db.query(
      'ledger',
      where: "uid = ?",
      whereArgs: ["OPENING_BAL"],
    );

    double bal = double.tryParse(balanceStr) ?? 0;

    if (existing.isEmpty && bal != 0) {
      // The user specifically requested that the vendor's opening balance MUST always be stored in the 'cash' column
      await db.insert('ledger', {
        'name': "Opening Balance",
        'uid': "OPENING_BAL",
        'date': date,
        'totalmeter': 0.0,
        'total_price': 0.0,
        'per_meter': 0.0,
        'cash': bal,
        'debit': 0.0,
      });
    }
  }

  Future<void> updateLedgerEntry(String vendorName, int id, Map<String, dynamic> data) async {
    final db = await openVendorLedgerDB(vendorName);
    await db.update('ledger', data, where: 'id = ?', whereArgs: [id]);
  }
}
