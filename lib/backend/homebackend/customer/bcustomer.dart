import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

class BCustomer {
  static const T_customer = 'T_customer';
  static const C_customerid = 'id';
  static const C_customeruid = 'uid';
  static const C_customername = 'name';
  static const C_customerphone = 'phone';
  static const C_customeraddress = 'address';
  static const C_customercity = 'city';
  static const C_customerbalance = 'obalance';
  static const C_complete = 'iscomplete';

  BCustomer._();
  static final BCustomer getInstance = BCustomer._();
  Database? _mycustomer;

  Future<Database> getcustomer() async {
    _mycustomer ??= await opencustomerDB();
    return _mycustomer!;
  }

  Future<Database> opencustomerDB() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final directory = await getApplicationSupportDirectory();
    var path = join(directory.path, "CUSTOMER\\customer.db");
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          "CREATE TABLE $T_customer ("
          "$C_customerid INTEGER PRIMARY KEY AUTOINCREMENT,"
          "$C_customername TEXT,"
          "$C_customeruid TEXT,"
          "$C_customerphone TEXT,"
          "$C_customeraddress TEXT,"
          "$C_customercity TEXT,"
          "$C_customerbalance TEXT,"
          "$C_complete INTEGER DEFAULT 0"
          ")",
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    Database db = await getcustomer();
    return await db.query(T_customer, orderBy: "$C_customerid DESC");
  }

  Future<int> getLastUid() async {
    final db = await getcustomer();
    var res = await db.rawQuery(
      "SELECT MAX(CAST($C_customeruid AS INTEGER)) as last_id FROM $T_customer",
    );
    if (res.first['last_id'] == null) return 0;
    return res.first['last_id'] as int;
  }

  Future<bool> addcustomer(
    String name,
    String uid,
    String phone,
    String address,
    String city,
    String balance,
  ) async {
    Database db = await getcustomer();
    // Complete if all major fields are filled
    int completeStatus =
        (name.isNotEmpty &&
            phone.isNotEmpty &&
            city.isNotEmpty &&
            address.isNotEmpty)
        ? 1
        : 0;

    int result = await db.insert(T_customer, {
      C_customername: name,
      C_customeruid: uid,
      C_customerphone: phone,
      C_customeraddress: address,
      C_customercity: city,
      C_customerbalance: balance,
      C_complete: completeStatus,
    });
    return result > 0;
  }

  Future<bool> deleteCustomer(String uid) async {
    Database db = await getcustomer();
    int result = await db.delete(
      T_customer,
      where: "$C_customeruid = ?",
      whereArgs: [uid],
    );
    return result > 0;
  }

  // --- UPDATE METHOD ---
  Future<bool> updateCustomer(
    String id, // Internal SQLite ID
    String name,
    String phone,
    String address,
    String city,
    String balance,
  ) async {
    Database db = await getcustomer();

    // Recalculate completeness
    int completeStatus =
        (name.isNotEmpty &&
            phone.isNotEmpty &&
            city.isNotEmpty &&
            address.isNotEmpty)
        ? 1
        : 0;

    int result = await db.update(
      T_customer,
      {
        C_customername: name,
        C_customerphone: phone,
        C_customeraddress: address,
        C_customercity: city,
        C_customerbalance: balance,
        C_complete: completeStatus,
      },
      where: "$C_customerid = ?",
      whereArgs: [id],
    );
    return result > 0;
  }

  Future<bool> updateCustomerBalance(String uid, String balance) async {
    Database db = await getcustomer();
    int result = await db.update(
      T_customer,
      {C_customerbalance: balance},
      where: "$C_customeruid = ?",
      whereArgs: [uid],
    );
    return result > 0;
  }
}
