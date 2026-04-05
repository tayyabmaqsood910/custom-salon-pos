import 'package:flutter/material.dart';
import 'dart:convert';
import '../constants/app_currency.dart';
import '../models/models.dart';
import '../database/database_helper.dart';

class StaffPayrollSnapshot {
  final int presentDays;
  final int halfDays;
  final int absentDays;
  final int servicesDone;
  final double salesTotal;
  final double commissionEarned;
  final double grossEarnings;
  final double payableNow;

  const StaffPayrollSnapshot({
    required this.presentDays,
    required this.halfDays,
    required this.absentDays,
    required this.servicesDone,
    required this.salesTotal,
    required this.commissionEarned,
    required this.grossEarnings,
    required this.payableNow,
  });
}

class AppProvider extends ChangeNotifier {
  static const String _menuSeedVersion = '2026-03-26-whatsapp-menu-v1';

  List<CustomerProfile> customers = [];
  List<ServiceItem> services = [];
  List<ParkedBill> parkedBills = [];
  List<StaffProfile> staff = [];
  List<InventoryItem> inventory = [];
  List<ExpenseItem> expenses = [];
  List<TransactionRecord> transactions = [];
  List<AttendanceRecord> attendance = [];
  Map<String, String> settings = {};

  bool isInitialized = false;

  Future<void> init() async {
    // Load all data from SQLite exclusively
    await _loadAllData();
    await _applyProvidedMenuSeedIfNeeded();
    await _ensurePkrCurrencyDefault();
    // Dummy data generation removed as requested.

    isInitialized = true;
    notifyListeners();
  }

  /// PKR by default; migrate legacy USD symbol from settings DB.
  Future<void> _ensurePkrCurrencyDefault() async {
    final sym = settings['currencySymbol'];
    if (sym == null || sym.isEmpty || sym == r'$') {
      await DatabaseHelper.instance.saveSetting(
        'currencySymbol',
        kDefaultCurrencySymbol,
      );
      settings['currencySymbol'] = kDefaultCurrencySymbol;
    }
  }

  Future<void> _loadAllData() async {
    final db = DatabaseHelper.instance;

    final customerData = await db.getAllCustomers();
    customers = customerData.map((e) => CustomerProfile.fromMap(e)).toList();

    final serviceData = await db.getAllServices();
    services = serviceData.map((e) => ServiceItem.fromMap(e)).toList();

    final parkedBillData = await db.getAllParkedBills();
    parkedBills = parkedBillData.map((e) => ParkedBill.fromMap(e)).toList();

    final staffData = await db.getAllStaff();
    staff = staffData.map((e) => StaffProfile.fromMap(e)).toList();

    final inventoryData = await db.getAllInventory();
    inventory = inventoryData.map((e) => InventoryItem.fromMap(e)).toList();

    final expenseData = await db.getAllExpenses();
    expenses = expenseData.map((e) => ExpenseItem.fromMap(e)).toList();

    final transactionData = await db.getAllTransactions();
    transactions = transactionData.map((e) => TransactionRecord.fromMap(e)).toList();

    final attendanceData = await db.getAllAttendance();
    attendance = attendanceData.map((e) => AttendanceRecord.fromMap(e)).toList();

    settings = await db.getAllSettings();
  }

  Future<void> _applyProvidedMenuSeedIfNeeded() async {
    if (settings['menuSeedVersion'] == _menuSeedVersion) return;

    // User requested replacing previous demo data with the provided menu.
    await DatabaseHelper.instance.clearData(false);

    for (final item in _providedMenuSeed) {
      await DatabaseHelper.instance.insertService({
        'name': item.name,
        'price': item.price,
        'category': item.category,
        'icon_code_point': item.iconCodePoint,
      });
    }

    await DatabaseHelper.instance.saveSetting('menuSeedVersion', _menuSeedVersion);
    settings['menuSeedVersion'] = _menuSeedVersion;
    await _loadAllData();
  }

  List<_MenuSeedItem> get _providedMenuSeed => [
    // Haircuts
    _MenuSeedItem('Haircut', 1000, 'Haircuts', Icons.content_cut),
    _MenuSeedItem('Fade Haircut', 1200, 'Haircuts', Icons.content_cut),
    _MenuSeedItem('Haircut by Senior Stylish Asif', 2000, 'Haircuts', Icons.star),
    _MenuSeedItem('Haircut by Senior Stylish Adeel', 1500, 'Haircuts', Icons.star),
    _MenuSeedItem('Haircut by Senior Stylish Pasha', 1500, 'Haircuts', Icons.star),
    _MenuSeedItem('Hair Wash', 100, 'Haircuts', Icons.shower),
    _MenuSeedItem('Hair Wash Loreal', 500, 'Haircuts', Icons.shower),
    _MenuSeedItem('Long Haircut', 1200, 'Haircuts', Icons.content_cut),

    // Shave
    _MenuSeedItem('Clear Shave', 500, 'Shave', Icons.face_retouching_natural),
    _MenuSeedItem('Beard Trimming', 500, 'Shave', Icons.face),
    _MenuSeedItem('Threading', 300, 'Shave', Icons.brush),

    // Executive
    _MenuSeedItem('Executive Haircut', 1500, 'Executive', Icons.content_cut),
    _MenuSeedItem('Executive Clear Shave', 700, 'Executive', Icons.face_retouching_natural),
    _MenuSeedItem('Executive Beard Trimming', 700, 'Executive', Icons.face),
    _MenuSeedItem('Executive Fade Haircut', 1500, 'Executive', Icons.content_cut),

    // Hair Treatments
    _MenuSeedItem('Hair Color High Length', 4000, 'Hair', Icons.color_lens),
    _MenuSeedItem('Hair Color Low Length', 3000, 'Hair', Icons.color_lens),
    _MenuSeedItem('Hair Rebonding (lower length)', 10000, 'Hair', Icons.spa),
    _MenuSeedItem('Hair Rebonding (full length)', 14000, 'Hair', Icons.spa),
    _MenuSeedItem('Hair Rebonding (upper head)', 5000, 'Hair', Icons.spa),
    _MenuSeedItem('Hair Keratin (full length)', 18000, 'Hair', Icons.spa),
    _MenuSeedItem('Hair Keratin (upper head)', 8000, 'Hair', Icons.spa),
    _MenuSeedItem('Hair Keratin (3 inch length)', 10000, 'Hair', Icons.spa),
    _MenuSeedItem('Hair Keratin (shoulder length)', 15000, 'Hair', Icons.spa),
    _MenuSeedItem('Loreal Protein Treatment', 4500, 'Hair', Icons.healing),
    _MenuSeedItem('Hair Perms (upper head)', 8000, 'Hair', Icons.waves),
    _MenuSeedItem('Hair Perms (full)', 12000, 'Hair', Icons.waves),
    _MenuSeedItem('Topic Styling', 800, 'Hair', Icons.auto_fix_high),
    _MenuSeedItem('Hair Styling', 500, 'Hair', Icons.auto_fix_high),
    _MenuSeedItem('Hair Treatment Framesi', 3500, 'Hair', Icons.medical_services),

    // Hair Color
    _MenuSeedItem('Keune Hair Colour', 1500, 'Hair Color', Icons.color_lens),
    _MenuSeedItem('Loreal Casting', 3500, 'Hair Color', Icons.color_lens),
    _MenuSeedItem('Loreal Majirel Color', 2000, 'Hair Color', Icons.color_lens),
    _MenuSeedItem('Framesi Hair Colour', 2500, 'Hair Color', Icons.color_lens),
    _MenuSeedItem('Just for Men', 3500, 'Hair Color', Icons.color_lens),
    _MenuSeedItem('Loreal Inoa', 2500, 'Hair Color', Icons.color_lens),
    _MenuSeedItem('Side Burn Dye', 700, 'Hair Color', Icons.color_lens),
    _MenuSeedItem('Hair Dye Application', 500, 'Hair Color', Icons.color_lens),
    _MenuSeedItem('Beard Dye Keune', 800, 'Hair Color', Icons.color_lens),
    _MenuSeedItem('Loreal Majirel Beard Dye', 1000, 'Hair Color', Icons.color_lens),
    _MenuSeedItem('Loreal Inoa Beard Dye', 1200, 'Hair Color', Icons.color_lens),
    _MenuSeedItem('Beard Dye Application', 500, 'Hair Color', Icons.color_lens),

    // Facials
    _MenuSeedItem('Dermalogica Facial', 12000, 'Facial', Icons.spa),
    _MenuSeedItem('Body Shop Facial', 7000, 'Facial', Icons.spa),
    _MenuSeedItem('Whitening Cleansing', 4500, 'Facial', Icons.spa),
    _MenuSeedItem('Body Shop Cleansing', 4000, 'Facial', Icons.spa),
    _MenuSeedItem('Normal Cleansing', 2500, 'Facial', Icons.spa),
    _MenuSeedItem('Black Head Strips', 150, 'Facial', Icons.spa),
    _MenuSeedItem('Make Up', 3000, 'Facial', Icons.brush),
    _MenuSeedItem('Face Polish', 1500, 'Facial', Icons.spa),

    // Male Staff Massage
    _MenuSeedItem('Swedish Massage (30 min)', 2500, 'Massage', Icons.self_improvement),
    _MenuSeedItem('Swedish Massage (60 min)', 3500, 'Massage', Icons.self_improvement),
    _MenuSeedItem('Thai Dry Massage (30 min)', 2000, 'Massage', Icons.self_improvement),
    _MenuSeedItem('Thai Dry Massage (60 min)', 3500, 'Massage', Icons.self_improvement),
    _MenuSeedItem('Thai Massage with Coconut Oil (30 min)', 2500, 'Massage', Icons.spa),
    _MenuSeedItem('Thai Massage with Coconut Oil (60 min)', 4000, 'Massage', Icons.spa),
    _MenuSeedItem('Thai Massage with Mustard Oil (30 min)', 2500, 'Massage', Icons.spa),
    _MenuSeedItem('Thai Massage with Mustard Oil (60 min)', 4000, 'Massage', Icons.spa),
    _MenuSeedItem('Thai Massage with Olive Oil (30 min)', 3000, 'Massage', Icons.spa),
    _MenuSeedItem('Thai Massage with Olive Oil (60 min)', 5000, 'Massage', Icons.spa),
    _MenuSeedItem('Stone Massage (50 min)', 5000, 'Massage', Icons.spa),
    _MenuSeedItem('Sports Massage (50 min)', 3500, 'Massage', Icons.sports),
    _MenuSeedItem('Foot Massage (20 min)', 1500, 'Massage', Icons.airline_seat_legroom_extra),
    _MenuSeedItem('Neck & Shoulder Massage (20 min)', 1800, 'Massage', Icons.accessibility_new),
    _MenuSeedItem('Hot Oil Massage (20 min)', 1000, 'Massage', Icons.local_fire_department),
    _MenuSeedItem('Body Scrub', 5000, 'Massage', Icons.clean_hands),
    _MenuSeedItem('Organic Body Scrub', 6000, 'Massage', Icons.eco),
    _MenuSeedItem('Deep Tissue Massage', 5000, 'Massage', Icons.self_improvement),
    _MenuSeedItem('Shower', 1000, 'Massage', Icons.shower),

    // Wax
    _MenuSeedItem('Wax Full Body', 12000, 'Wax', Icons.cleaning_services),
    _MenuSeedItem('Wax Chest', 3500, 'Wax', Icons.cleaning_services),
    _MenuSeedItem('Wax Back', 5000, 'Wax', Icons.cleaning_services),
    _MenuSeedItem('Wax Full Legs', 5000, 'Wax', Icons.cleaning_services),
    _MenuSeedItem('Wax Half Legs', 1500, 'Wax', Icons.cleaning_services),
    _MenuSeedItem('Wax Full Arms', 3000, 'Wax', Icons.cleaning_services),
    _MenuSeedItem('Wax Half Arms', 1500, 'Wax', Icons.cleaning_services),
    _MenuSeedItem('Wax Under Arms', 800, 'Wax', Icons.cleaning_services),
    _MenuSeedItem('Wax Shoulder', 1500, 'Wax', Icons.cleaning_services),
    _MenuSeedItem('Face Wax', 1000, 'Wax', Icons.cleaning_services),

    // Mani & Pedi Cure
    _MenuSeedItem('Manicure (Aroma)', 2500, 'Mani & Pedi', Icons.back_hand),
    _MenuSeedItem('Pedicure (Aroma)', 2500, 'Mani & Pedi', Icons.spa),
    _MenuSeedItem('Manicure + Pedicure (Aroma)', 5000, 'Mani & Pedi', Icons.spa),
    _MenuSeedItem('Manicure (Dermacos)', 2500, 'Mani & Pedi', Icons.back_hand),
    _MenuSeedItem('Pedicure (Dermacos)', 2500, 'Mani & Pedi', Icons.spa),
    _MenuSeedItem('Manicure + Pedicure (Dermacos)', 5000, 'Mani & Pedi', Icons.spa),
    _MenuSeedItem('Manicure (Organic Product)', 2500, 'Mani & Pedi', Icons.eco),
    _MenuSeedItem('Pedicure (Organic Product)', 2500, 'Mani & Pedi', Icons.eco),
    _MenuSeedItem('Manicure + Pedicure (Organic Product)', 5000, 'Mani & Pedi', Icons.eco),
    _MenuSeedItem('Nail Cut Hand + Filer + Buffer', 1000, 'Mani & Pedi', Icons.content_cut),
    _MenuSeedItem('Nail Cut Foot + Filer + Buffer', 1500, 'Mani & Pedi', Icons.content_cut),
    _MenuSeedItem('Nail Cut Hand + Foot + Filer + Buffer', 1300, 'Mani & Pedi', Icons.content_cut),
    _MenuSeedItem('Paraffin Wax Treatment', 3000, 'Mani & Pedi', Icons.spa),

    // Groom Packages
    _MenuSeedItem('Groom Package - Standard', 25000, 'Groom Packages', Icons.workspace_premium),
    _MenuSeedItem('Groom Package - Executive', 35000, 'Groom Packages', Icons.workspace_premium),
    _MenuSeedItem('Groom Package - Elite (Ultimate)', 42000, 'Groom Packages', Icons.workspace_premium),
  ];

  Future<void> saveSettings(Map<String, String> newSettings) async {
    for (var entry in newSettings.entries) {
      await DatabaseHelper.instance.saveSetting(entry.key, entry.value);
      settings[entry.key] = entry.value;
    }
    notifyListeners();
  }

  Future<String> exportAllDataAsJSON() async {
    final Map<String, dynamic> data = {
      'customers': await DatabaseHelper.instance.getAllRaw('customers'),
      'inventory': await DatabaseHelper.instance.getAllRaw('inventory'),
      'staff': await DatabaseHelper.instance.getAllRaw('staff'),
      'transactions': await DatabaseHelper.instance.getAllRaw('transactions'),
      'expenses': await DatabaseHelper.instance.getAllRaw('expenses'),
      'services': await DatabaseHelper.instance.getAllRaw('services'),
      'settings': await DatabaseHelper.instance.getAllSettings(),
    };
    return jsonEncode(data);
  }

  Future<void> clearAllData({bool keepStaffAndMenu = false}) async {
    await DatabaseHelper.instance.clearData(keepStaffAndMenu);
    await init();
  }

  Future<void> prepareForClient() async {
    await clearAllData(keepStaffAndMenu: false);
    
    final demoAdmin = StaffProfile(id: '1', name: 'admin', phone: 'admin', role: 'Admin', joinDate: DateTime.now());
    await DatabaseHelper.instance.insertStaff(demoAdmin.toMap());
    
    final demoManager = StaffProfile(id: '2', name: 'manager', phone: 'manager', role: 'Manager', joinDate: DateTime.now());
    await DatabaseHelper.instance.insertStaff(demoManager.toMap());
    
    final demoService = ServiceItem(id: '1', name: 'Demo Haircut', price: 15.0, category: 'Hair', iconCodePoint: Icons.cut.codePoint);
    await DatabaseHelper.instance.insertService(demoService.toMap());
    
    await init();
  }

  Future<void> factoryReset() async {
    await DatabaseHelper.instance.clearData(false);
    await DatabaseHelper.instance.clearSettings();
    await init();
  }

  Future<void> importAllDataFromJSON(String jsonStr) async {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    
    // Purge everything first for a clean restore
    await DatabaseHelper.instance.clearData(false);
    await DatabaseHelper.instance.clearSettings();

    // 1. Settings
    if (data['settings'] != null) {
      Map<String, dynamic> sets = data['settings'];
      for (var entry in sets.entries) {
        await DatabaseHelper.instance.saveSetting(entry.key, entry.value.toString());
      }
    }

    // 2. Services
    if (data['services'] != null) {
      for (var s in data['services']) {
        await DatabaseHelper.instance.insertService(s);
      }
    }

    // 3. Staff
    if (data['staff'] != null) {
      for (var s in data['staff']) {
        await DatabaseHelper.instance.insertStaff(s);
      }
    }

    // 4. Customers
    if (data['customers'] != null) {
      for (var c in data['customers']) {
        await DatabaseHelper.instance.insertCustomer(c);
      }
    }

    // 5. Inventory
    if (data['inventory'] != null) {
      for (var i in data['inventory']) {
        await DatabaseHelper.instance.insertInventory(i);
      }
    }

    // 6. Transactions
    if (data['transactions'] != null) {
      for (var t in data['transactions']) {
        await DatabaseHelper.instance.insertTransaction(t);
      }
    }

    // 7. Expenses
    if (data['expenses'] != null) {
      for (var e in data['expenses']) {
        await DatabaseHelper.instance.insertExpense(e);
      }
    }

    await init(); // Force reload everything from DB to UI
  }



  // --- CUSTOMERS ---
  Future<void> addCustomer(CustomerProfile item) async {
    int id = await DatabaseHelper.instance.insertCustomer(item.toMap());
    item.id = id.toString();
    await loadCustomers();
  }
  Future<bool> updateCustomerItem(CustomerProfile item) async {
    final id = int.tryParse(item.id);
    if (id == null) return false;
    await DatabaseHelper.instance.updateCustomer(id, item.toMap());
    await loadCustomers();
    return true;
  }
  Future<void> deleteCustomer(CustomerProfile item) async {
    if (int.tryParse(item.id) != null) {
      await DatabaseHelper.instance.deleteCustomer(int.parse(item.id));
      await loadCustomers();
    }
  }
  Future<void> loadCustomers() async {
    final data = await DatabaseHelper.instance.getAllCustomers();
    customers = data.map((e) => CustomerProfile.fromMap(e)).toList();
    notifyListeners();
  }

  // --- SERVICES ---
  Future<void> addService(ServiceItem item) async {
    int id = await DatabaseHelper.instance.insertService(item.toMap());
    item.id = id.toString();
    await loadServices();
  }
  Future<void> updateServiceItem(ServiceItem item) async {
    if (int.tryParse(item.id) != null) {
      await DatabaseHelper.instance.updateService(int.parse(item.id), item.toMap());
      await loadServices();
    }
  }
  Future<void> deleteService(ServiceItem item) async {
    if (int.tryParse(item.id) != null) {
      await DatabaseHelper.instance.deleteService(int.parse(item.id));
      await loadServices();
    }
  }
  Future<void> loadServices() async {
    final data = await DatabaseHelper.instance.getAllServices();
    services = data.map((e) => ServiceItem.fromMap(e)).toList();
    notifyListeners();
  }

  // --- PARKED BILLS ---
  Future<void> addParkedBill(ParkedBill item) async {
    int id = await DatabaseHelper.instance.insertParkedBill(item.toMap());
    item.id = id.toString();
    await loadParkedBills();
  }
  Future<void> deleteParkedBill(ParkedBill item) async {
    if (int.tryParse(item.id) != null) {
      await DatabaseHelper.instance.deleteParkedBill(int.parse(item.id));
      await loadParkedBills();
    }
  }
  Future<void> loadParkedBills() async {
    final data = await DatabaseHelper.instance.getAllParkedBills();
    parkedBills = data.map((e) => ParkedBill.fromMap(e)).toList();
    notifyListeners();
  }

  // --- STAFF ---
  Future<void> addStaff(StaffProfile item) async {
    int id = await DatabaseHelper.instance.insertStaff(item.toMap());
    item.id = id.toString();
    await loadStaff();
  }
  Future<bool> updateStaffItem(StaffProfile item) async {
    final id = int.tryParse(item.id);
    if (id == null) return false;
    await DatabaseHelper.instance.updateStaff(id, item.toMap());
    await loadStaff();
    return true;
  }
  Future<void> deleteStaff(StaffProfile item) async {
    if (int.tryParse(item.id) != null) {
      await DatabaseHelper.instance.deleteStaff(int.parse(item.id));
      await loadStaff();
    }
  }
  Future<void> loadStaff() async {
    final data = await DatabaseHelper.instance.getAllStaff();
    staff = data.map((e) => StaffProfile.fromMap(e)).toList();
    for (final s in staff) {
      s.attendanceHistory = attendance.where((a) => a.staffId == s.id).toList();
    }
    notifyListeners();
  }

  Future<void> markAttendanceForStaff(
    StaffProfile staffProfile,
    String status, {
    DateTime? date,
  }) async {
    final recordDate = date ?? DateTime.now();
    final rec = AttendanceRecord(
      staffId: staffProfile.id,
      date: DateTime(recordDate.year, recordDate.month, recordDate.day),
      status: status,
    );
    await addAttendance(rec);
    await loadStaff();
  }

  Future<void> recordStaffPayment(
    StaffProfile staffProfile,
    double amount, {
    required bool isAdvance,
  }) async {
    if (amount <= 0) return;
    if (isAdvance) {
      staffProfile.totalAdvanceTaken += amount;
    } else {
      staffProfile.totalPaid += amount;
    }
    await updateStaffItem(staffProfile);
  }

  StaffPayrollSnapshot payrollForStaff(
    StaffProfile staffProfile, {
    DateTime? month,
  }) {
    final now = month ?? DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);

    final staffAttendance = attendance.where((a) {
      final d = a.date;
      return a.staffId == staffProfile.id &&
          !d.isBefore(monthStart) &&
          d.isBefore(nextMonthStart);
    }).toList();

    int present = 0;
    int half = 0;
    int absent = 0;
    for (final a in staffAttendance) {
      final s = a.status.toLowerCase();
      if (s == 'present') {
        present++;
      } else if (s == 'half day') {
        half++;
      } else {
        absent++;
      }
    }

    int servicesDone = 0;
    double salesTotal = 0;
    for (final tx in transactions) {
      final d = tx.date;
      if (d.isBefore(monthStart) || !d.isBefore(nextMonthStart)) continue;
      for (final item in tx.items) {
        if (item.assignedStaff.trim().toLowerCase() ==
            staffProfile.name.trim().toLowerCase()) {
          servicesDone++;
          salesTotal += item.finalPrice;
        }
      }
    }

    double commission = 0;
    if (staffProfile.structure == PaymentStructure.commissionOnly ||
        staffProfile.structure == PaymentStructure.hybrid) {
      if (staffProfile.isCommissionPercentage) {
        commission = salesTotal * (staffProfile.commissionRate / 100);
      } else {
        commission = servicesDone * staffProfile.commissionRate;
      }
    }

    final attendanceUnits = present + (half * 0.5);
    double base = 0;
    if (staffProfile.structure == PaymentStructure.fixedSalary ||
        staffProfile.structure == PaymentStructure.hybrid) {
      base = staffProfile.baseSalary;
    } else if (staffProfile.structure == PaymentStructure.dailyWage) {
      base = attendanceUnits * staffProfile.baseSalary;
    }

    final gross = base + commission;
    final payable = gross - staffProfile.totalAdvanceTaken - staffProfile.totalPaid;

    return StaffPayrollSnapshot(
      presentDays: present,
      halfDays: half,
      absentDays: absent,
      servicesDone: servicesDone,
      salesTotal: salesTotal,
      commissionEarned: commission,
      grossEarnings: gross,
      payableNow: payable,
    );
  }

  // --- INVENTORY ---
  Future<void> addInventory(InventoryItem item) async {
    int id = await DatabaseHelper.instance.insertInventory(item.toMap());
    item.id = id.toString();
    await loadInventory();
  }
  Future<void> updateInventoryItem(InventoryItem item) async {
    if (int.tryParse(item.id) != null) {
      await DatabaseHelper.instance.updateInventory(int.parse(item.id), item.toMap());
      await loadInventory();
    }
  }
  Future<void> deleteInventory(InventoryItem item) async {
    if (int.tryParse(item.id) != null) {
      await DatabaseHelper.instance.deleteInventory(int.parse(item.id));
      await loadInventory();
    }
  }
  Future<void> loadInventory() async {
    final data = await DatabaseHelper.instance.getAllInventory();
    inventory = data.map((e) => InventoryItem.fromMap(e)).toList();
    notifyListeners();
  }

  Future<void> applyGlobalLowStockThreshold(int threshold) async {
    for (final item in inventory) {
      if (int.tryParse(item.id) == null) continue;
      final updated = InventoryItem(
        id: item.id,
        name: item.name,
        category: item.category,
        unit: item.unit,
        purchasePrice: item.purchasePrice,
        sellingPrice: item.sellingPrice,
        quantity: item.quantity,
        minThreshold: threshold,
        linkedServices: item.linkedServices,
      );
      await DatabaseHelper.instance.updateInventory(int.parse(item.id), updated.toMap());
    }
    await loadInventory();
  }

  // --- EXPENSES ---
  Future<void> addExpense(ExpenseItem item) async {
    int id = await DatabaseHelper.instance.insertExpense(item.toMap());
    item.id = id.toString();
    await loadExpenses();
  }
  Future<void> updateExpenseItem(ExpenseItem item) async {
    if (int.tryParse(item.id) != null) {
      await DatabaseHelper.instance.updateExpense(int.parse(item.id), item.toMap());
      await loadExpenses();
    }
  }
  Future<void> deleteExpense(ExpenseItem item) async {
    if (int.tryParse(item.id) != null) {
      await DatabaseHelper.instance.deleteExpense(int.parse(item.id));
      await loadExpenses();
    }
  }
  Future<void> loadExpenses() async {
    final data = await DatabaseHelper.instance.getAllExpenses();
    expenses = data.map((e) => ExpenseItem.fromMap(e)).toList();
    notifyListeners();
  }

  // --- TRANSACTIONS ---
  Future<void> addTransaction(TransactionRecord item) async {
    int id = await DatabaseHelper.instance.insertTransaction(item.toMap());
    item.id = id.toString();
    await loadTransactions();
  }
  Future<void> updateTransactionItem(TransactionRecord item) async {
    if (int.tryParse(item.id) != null) {
      await DatabaseHelper.instance.updateTransaction(int.parse(item.id), item.toMap());
      await loadTransactions();
    }
  }
  Future<void> deleteTransaction(TransactionRecord item) async {
    if (int.tryParse(item.id) != null) {
      await DatabaseHelper.instance.deleteTransaction(int.parse(item.id));
      await loadTransactions();
    }
  }
  Future<void> loadTransactions() async {
    final data = await DatabaseHelper.instance.getAllTransactions();
    transactions = data.map((e) => TransactionRecord.fromMap(e)).toList();
    notifyListeners();
  }

  // --- ATTENDANCE ---
  Future<void> addAttendance(AttendanceRecord item) async {
    int id = await DatabaseHelper.instance.insertAttendance(item.toMap());
    item.id = id.toString();
    await loadAttendance();
  }
  Future<void> deleteAttendance(AttendanceRecord item) async {
    if (int.tryParse(item.id ?? '') != null) {
      await DatabaseHelper.instance.deleteAttendance(int.parse(item.id!));
      await loadAttendance();
    }
  }
  Future<void> loadAttendance() async {
    final data = await DatabaseHelper.instance.getAllAttendance();
    attendance = data.map((e) => AttendanceRecord.fromMap(e)).toList();
    notifyListeners();
  }

  // To preserve backwards compatibility with save/update calls:
  void updateCustomer() {} 
  void updateStaff() {}
  void updateInventory() {}
  void updateExpense() {}
}

class _MenuSeedItem {
  final String name;
  final double price;
  final String category;
  final int iconCodePoint;

  _MenuSeedItem(
    this.name,
    this.price,
    this.category,
    IconData icon,
  ) : iconCodePoint = icon.codePoint;
}
