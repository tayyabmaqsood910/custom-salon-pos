import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('salon_pos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    String path;
    if (kIsWeb) {
      path = filePath; // Web uses indexeddb with this path
    } else {
      final directory = await getApplicationDocumentsDirectory();
      path = join(directory.path, filePath);
    }

    var db = await openDatabase(path, version: 1, onCreate: _createDB);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await _ensureStaffColumns(db);

    return db;
  }

  Future<void> _ensureStaffColumns(Database db) async {
    // Backfill newly tracked staff details for existing databases.
    const staffColumns = <String, String>{
      'cnic': "TEXT DEFAULT ''",
      'address': "TEXT DEFAULT ''",
      'emergency_contact': "TEXT DEFAULT ''",
      'is_commission_percentage': 'INTEGER DEFAULT 1',
      'total_advance_taken': 'REAL DEFAULT 0',
      'total_paid': 'REAL DEFAULT 0',
      'total_earned': 'REAL DEFAULT 0',
      'services_done_this_month': 'INTEGER DEFAULT 0',
    };

    for (final entry in staffColumns.entries) {
      try {
        await db.execute(
          'ALTER TABLE staff ADD COLUMN ${entry.key} ${entry.value}',
        );
      } catch (_) {
        // Column already exists on upgraded installs.
      }
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        gender TEXT,
        total_visits INTEGER DEFAULT 0,
        total_spent REAL DEFAULT 0.0,
        loyalty_points INTEGER DEFAULT 0,
        tier TEXT DEFAULT 'Regular',
        notes TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE staff (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        role TEXT,
        phone TEXT,
        cnic TEXT DEFAULT '',
        address TEXT DEFAULT '',
        emergency_contact TEXT DEFAULT '',
        payroll_type TEXT,
        commission_rate REAL,
        is_commission_percentage INTEGER DEFAULT 1,
        fixed_salary REAL,
        daily_wage REAL,
        total_advance_taken REAL DEFAULT 0,
        total_paid REAL DEFAULT 0,
        total_earned REAL DEFAULT 0,
        services_done_this_month INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER,
        customer_name TEXT,
        staff_id INTEGER,
        staff_name TEXT,
        services TEXT,
        subtotal REAL,
        discount REAL,
        tip REAL,
        loyalty_redeemed REAL,
        total REAL,
        payment_method TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT,
        stock REAL DEFAULT 0,
        unit TEXT,
        min_threshold REAL DEFAULT 5,
        purchase_price REAL,
        retail_price REAL,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT,
        amount REAL,
        description TEXT,
        payment_method TEXT,
        is_recurring INTEGER DEFAULT 0,
        receipt_attached INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        staff_id INTEGER,
        date TEXT,
        status TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE parked_bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reference TEXT,
        cart_data TEXT,
        customer_name TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE services (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL,
        category TEXT,
        icon_code_point INTEGER
      )
    ''');
  }

  Future<void> clearSettings() async {
    final db = await instance.database;
    await db.delete('settings');
  }

  Future<void> clearData(bool keepStaffAndMenu) async {
    final db = await instance.database;
    await db.delete('transactions');
    await db.delete('customers');
    await db.delete('expenses');
    await db.delete('parked_bills');
    
    if (!keepStaffAndMenu) {
      await db.delete('staff');
      await db.delete('attendance');
      await db.delete('inventory');
      await db.delete('services');
    }
  }

  // Customers
  Future<int> insertCustomer(Map<String, dynamic> customer) async {
    final db = await instance.database;
    return await db.insert('customers', customer);
  }

  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final db = await instance.database;
    return await db.query('customers', orderBy: 'id DESC');
  }

  Future<int> updateCustomer(int id, Map<String, dynamic> data) async {
    final db = await instance.database;
    return await db.update('customers', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCustomer(int id) async {
    final db = await instance.database;
    return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getCustomerById(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  // Staff
  Future<int> insertStaff(Map<String, dynamic> staff) async {
    final db = await instance.database;
    return await db.insert('staff', staff);
  }

  Future<List<Map<String, dynamic>>> getAllStaff() async {
    final db = await instance.database;
    return await db.query('staff', orderBy: 'id DESC');
  }

  Future<int> updateStaff(int id, Map<String, dynamic> data) async {
    final db = await instance.database;
    return await db.update('staff', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteStaff(int id) async {
    final db = await instance.database;
    return await db.delete('staff', where: 'id = ?', whereArgs: [id]);
  }

  // Transactions
  Future<int> insertTransaction(Map<String, dynamic> transaction) async {
    final db = await instance.database;
    return await db.insert('transactions', transaction);
  }

  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    final db = await instance.database;
    return await db.query('transactions', orderBy: 'id DESC');
  }

  Future<int> updateTransaction(int id, Map<String, dynamic> data) async {
    final db = await instance.database;
    return await db.update('transactions', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // Inventory
  Future<int> insertInventory(Map<String, dynamic> item) async {
    final db = await instance.database;
    return await db.insert('inventory', item);
  }

  Future<List<Map<String, dynamic>>> getAllInventory() async {
    final db = await instance.database;
    return await db.query('inventory', orderBy: 'id DESC');
  }

  Future<int> updateInventory(int id, Map<String, dynamic> data) async {
    final db = await instance.database;
    return await db.update('inventory', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteInventory(int id) async {
    final db = await instance.database;
    return await db.delete('inventory', where: 'id = ?', whereArgs: [id]);
  }

  // Expenses
  Future<int> insertExpense(Map<String, dynamic> expense) async {
    final db = await instance.database;
    return await db.insert('expenses', expense);
  }

  Future<List<Map<String, dynamic>>> getAllExpenses() async {
    final db = await instance.database;
    return await db.query('expenses', orderBy: 'id DESC');
  }

  Future<int> updateExpense(int id, Map<String, dynamic> data) async {
    final db = await instance.database;
    return await db.update('expenses', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteExpense(int id) async {
    final db = await instance.database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // Attendance
  Future<int> insertAttendance(Map<String, dynamic> record) async {
    final db = await instance.database;
    return await db.insert('attendance', record);
  }

  Future<List<Map<String, dynamic>>> getAllAttendance() async {
    final db = await instance.database;
    return await db.query('attendance', orderBy: 'id DESC');
  }

  Future<int> deleteAttendance(int id) async {
    final db = await instance.database;
    return await db.delete('attendance', where: 'id = ?', whereArgs: [id]);
  }

  // Parked Bills
  Future<int> insertParkedBill(Map<String, dynamic> bill) async {
    final db = await instance.database;
    return await db.insert('parked_bills', bill);
  }

  Future<List<Map<String, dynamic>>> getAllParkedBills() async {
    final db = await instance.database;
    return await db.query('parked_bills', orderBy: 'id DESC');
  }

  Future<int> deleteParkedBill(int id) async {
    final db = await instance.database;
    return await db.delete('parked_bills', where: 'id = ?', whereArgs: [id]);
  }

  // Services
  Future<int> insertService(Map<String, dynamic> service) async {
    final db = await instance.database;
    return await db.insert('services', service);
  }

  Future<List<Map<String, dynamic>>> getAllServices() async {
    final db = await instance.database;
    return await db.query('services', orderBy: 'id DESC');
  }

  Future<int> updateService(int id, Map<String, dynamic> data) async {
    final db = await instance.database;
    return await db.update('services', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteService(int id) async {
    final db = await instance.database;
    return await db.delete('services', where: 'id = ?', whereArgs: [id]);
  }

  // Settings
  Future<void> saveSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('settings');
    Map<String, String> result = {};
    for (var m in maps) {
      result[m['key'] as String] = m['value'] as String;
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getAllRaw(String table) async {
    final db = await instance.database;
    return await db.query(table);
  }
}
