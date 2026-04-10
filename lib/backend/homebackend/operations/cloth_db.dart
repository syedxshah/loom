import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class Bcloth {
  static const String DB_NAME = "cloth.db";
  static const String TABLE_NAME = "cloth_table";
  static const String C_ID = "id";
  static const String C_NAME = "name";

  Bcloth._();
  static final Bcloth getInstance = Bcloth._();
  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDatabase();
    return _db!;
  }

  /// Internal method to initialize the database factory for Windows
  void _initializeWindowsFFI() {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI if running on Windows
    _initializeWindowsFFI();

    // Get the Application Support Directory
    final directory = await getApplicationSupportDirectory();

    // Construct path: OPERATOR/cloth.db
    final String path = join(directory.path, "OPERATOR", DB_NAME);

    // Ensure the OPERATOR directory exists
    final Directory operatorDir = Directory(join(directory.path, "OPERATOR"));
    if (!await operatorDir.exists()) {
      await operatorDir.create(recursive: true);
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await _createTable(db);
      },
      // Ensure table exists if the file was created manually or empty
      onOpen: (db) async {
        await _createTable(db);
      },
    );
  }

  Future<void> _createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $TABLE_NAME (
        $C_ID INTEGER PRIMARY KEY AUTOINCREMENT, 
        $C_NAME TEXT
      )
    ''');
  }

  Future<int> addCloth(String name) async {
    var client = await db;
    return await client.insert(TABLE_NAME, {C_NAME: name});
  }

  Future<List<Map<String, dynamic>>> getAllCloths() async {
    var client = await db;
    try {
      return await client.query(TABLE_NAME, orderBy: "$C_ID DESC");
    } catch (e) {
      return [];
    }
  }

  Future<int> deleteCloth(int id) async {
    var client = await db;
    return await client.delete(TABLE_NAME, where: "$C_ID = ?", whereArgs: [id]);
  }
}
