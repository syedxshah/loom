import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/intl.dart';

class KHisabDB {
  static const String DB_NAME = "hisab.db";
  static const String TABLE_NAME = "hisab";

  static const String C_ID = "id";
  static const String C_NAME = "name";
  static const String C_DESCRIPTION = "description";
  static const String C_AMOUNT = "amount";
  static const String C_CONDITION = "condition";
  static const String C_DATE = "date";

  KHisabDB._();
  static final KHisabDB getInstance = KHisabDB._();
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

    // Get the Application Support Directory
    final directory = await getApplicationSupportDirectory();
    
    // Using 'OPERATOR' directory to keep it consistent with other operation databases
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
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $TABLE_NAME ADD COLUMN $C_CONDITION TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE $TABLE_NAME ADD COLUMN $C_DATE TEXT');
        }
      },
      onOpen: (db) async => await _createTable(db),
    );
  }

  Future<void> _createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $TABLE_NAME (
        $C_ID INTEGER PRIMARY KEY AUTOINCREMENT, 
        $C_NAME TEXT,
        $C_DESCRIPTION TEXT,
        $C_AMOUNT REAL,
        $C_CONDITION TEXT,
        $C_DATE TEXT
      )
    ''');
  }

  // CRUD Operations

  Future<int> addHisab({
    required String name,
    required String description,
    required double amount,
    String? condition,
    String? date,
  }) async {
    final client = await db;
    return await client.insert(TABLE_NAME, {
      C_NAME: name,
      C_DESCRIPTION: description,
      C_AMOUNT: amount,
      C_CONDITION: condition,
      C_DATE: date ?? DateFormat('dd-MM-yyyy').format(DateTime.now()),
    });
  }

  Future<List<Map<String, dynamic>>> getAllHisabs() async {
    final client = await db;
    try {
      return await client.query(TABLE_NAME, orderBy: "$C_ID DESC");
    } catch (e) {
      return [];
    }
  }

  Future<int> deleteHisab(int id) async {
    final client = await db;
    return await client.delete(TABLE_NAME, where: "$C_ID = ?", whereArgs: [id]);
  }

  Future<int> updateHisab({
    required int id,
    String? name,
    String? description,
    double? amount,
    String? condition,
    String? date,
  }) async {
    final client = await db;
    Map<String, dynamic> values = {};
    if (name != null) values[C_NAME] = name;
    if (description != null) values[C_DESCRIPTION] = description;
    if (amount != null) values[C_AMOUNT] = amount;
    if (condition != null) values[C_CONDITION] = condition;
    if (date != null) values[C_DATE] = date;
    
    if (values.isEmpty) return 0;

    return await client.update(
      TABLE_NAME, 
      values, 
      where: "$C_ID = ?", 
      whereArgs: [id]
    );
  }
}
