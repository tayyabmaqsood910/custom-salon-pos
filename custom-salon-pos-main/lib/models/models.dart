import 'package:flutter/material.dart';
import 'dart:convert';

// ---------------- CUSTOMERS ----------------

class VisitRecord {
  final DateTime date;
  final String services;
  final String staff;
  final double amountPaid;
  final int pointsEarned;

  VisitRecord({
    required this.date,
    required this.services,
    required this.staff,
    required this.amountPaid,
    required this.pointsEarned,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'services': services,
      'staff': staff,
      'amountPaid': amountPaid,
      'pointsEarned': pointsEarned,
    };
  }

  factory VisitRecord.fromMap(Map<String, dynamic> map) {
    return VisitRecord(
      date: DateTime.parse(map['date']),
      services: map['services'] ?? '',
      staff: map['staff'] ?? '',
      amountPaid: (map['amountPaid'] as num).toDouble(),
      pointsEarned: map['pointsEarned'] ?? 0,
    );
  }
}

class CustomerProfile {
  String id;
  String name;
  String phone;
  String email;
  String gender;
  DateTime? dob;
  String notes;
  DateTime memberSince;
  int totalVisits;
  double totalSpent;
  int loyaltyPoints;
  List<VisitRecord> history;

  CustomerProfile({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.gender = '',
    this.dob,
    this.notes = '',
    required this.memberSince,
    this.totalVisits = 0,
    this.totalSpent = 0.0,
    this.loyaltyPoints = 0,
    this.history = const [],
  });

  String get tier {
    if (loyaltyPoints >= 500) return 'Gold';
    if (loyaltyPoints >= 200) return 'Silver';
    return 'Bronze';
  }

  Color get tierColor {
    if (tier == 'Gold') return Colors.amber;
    if (tier == 'Silver') return Colors.grey[400]!;
    return Colors.brown[400]!;
  }

  Map<String, dynamic> toMap() {
    return {
      if (int.tryParse(id) != null) 'id': int.tryParse(id),
      'name': name,
      'phone': phone,
      'email': email,
      'gender': gender,
      'total_visits': totalVisits,
      'total_spent': totalSpent,
      'loyalty_points': loyaltyPoints,
      'tier': tier,
      'notes': notes,
      'created_at': memberSince.toIso8601String(),
    };
  }

  factory CustomerProfile.fromMap(Map<String, dynamic> map) {
    return CustomerProfile(
      id: map['id'].toString(),
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      gender: map['gender'] ?? '',
      memberSince: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      totalVisits: map['total_visits'] ?? 0,
      totalSpent: (map['total_spent'] ?? 0.0).toDouble(),
      loyaltyPoints: map['loyalty_points'] ?? 0,
      notes: map['notes'] ?? '',
    );
  }
}

// ---------------- SERVICES & BILLING ----------------

class ServiceItem {
  String id;
  String name;
  double price;
  String category;
  int iconCodePoint;

  ServiceItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.iconCodePoint,
  });

  Map<String, dynamic> toMap() {
    return {
      if (int.tryParse(id) != null) 'id': int.tryParse(id),
      'name': name,
      'price': price,
      'category': category,
      'icon_code_point': iconCodePoint,
    };
  }

  factory ServiceItem.fromMap(Map<String, dynamic> map) {
    return ServiceItem(
      id: map['id'].toString(),
      name: map['name'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      category: map['category'] ?? '',
      iconCodePoint: map['icon_code_point'] ?? Icons.cut.codePoint,
    );
  }
}

class CartItem {
  ServiceItem service;
  String assignedStaff;
  double discount;
  bool isPercentDiscount;

  CartItem({
    required this.service,
    this.assignedStaff = 'Any',
    this.discount = 0.0,
    this.isPercentDiscount = false,
  });

  double get finalPrice {
    if (isPercentDiscount) {
      return service.price - (service.price * (discount / 100));
    }
    return service.price - discount;
  }

  Map<String, dynamic> toMap() {
    return {
      'service': service.toMap(),
      'assignedStaff': assignedStaff,
      'discount': discount,
      'isPercentDiscount': isPercentDiscount,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      service: ServiceItem.fromMap(map['service']),
      assignedStaff: map['assignedStaff'] ?? 'Any',
      discount: (map['discount'] ?? 0.0).toDouble(),
      isPercentDiscount: map['isPercentDiscount'] ?? false,
    );
  }
}

class ParkedBill {
  String
  id; // Actually no, it didn't have ID. Wait, ParkedBill didn't have ID string in hive. I should add `id` string for SQLite
  String reference;
  List<CartItem> cart;
  DateTime time;
  String customerId;

  ParkedBill({
    this.id = '',
    required this.reference,
    required this.cart,
    required this.time,
    required this.customerId,
  });

  Map<String, dynamic> toMap() {
    return {
      if (int.tryParse(id) != null) 'id': int.tryParse(id),
      'reference': reference,
      'cart_data': jsonEncode(cart.map((e) => e.toMap()).toList()),
      'customer_name': customerId, // saving customerId to DB column
      'created_at': time.toIso8601String(),
    };
  }

  factory ParkedBill.fromMap(Map<String, dynamic> map) {
    List<CartItem> cartItems = [];
    if (map['cart_data'] != null) {
      try {
        List data = jsonDecode(map['cart_data']);
        cartItems = data.map((e) => CartItem.fromMap(e)).toList();
      } catch (e) {}
    }

    return ParkedBill(
      id: map['id'].toString(),
      reference: map['reference'] ?? '',
      cart: cartItems,
      customerId: map['customer_name'] ?? '',
      time: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }
}

// ---------------- STAFF ----------------

enum PaymentStructure { commissionOnly, fixedSalary, dailyWage, hybrid }

class AttendanceRecord {
  String? id;
  String? staffId;
  DateTime date;
  String status;

  AttendanceRecord({
    this.id,
    this.staffId,
    required this.date,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      if (int.tryParse(id ?? '') != null) 'id': int.tryParse(id!),
      if (int.tryParse(staffId ?? '') != null)
        'staff_id': int.tryParse(staffId!),
      'date': date.toIso8601String(),
      'status': status,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'].toString(),
      staffId: map['staff_id']?.toString(),
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      status: map['status'] ?? '',
    );
  }
}

class CommissionRecord {
  final DateTime date;
  final String service;
  final double amount;
  final double commission;

  CommissionRecord({
    required this.date,
    required this.service,
    required this.amount,
    required this.commission,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'service': service,
      'amount': amount,
      'commission': commission,
    };
  }

  factory CommissionRecord.fromMap(Map<String, dynamic> map) {
    return CommissionRecord(
      date: DateTime.parse(map['date']),
      service: map['service'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      commission: (map['commission'] as num).toDouble(),
    );
  }
}

class StaffProfile {
  String id;
  String name;
  String phone;
  String role;
  String cnic;
  String address;
  String emergencyContact;
  DateTime joinDate;
  bool isActive;

  PaymentStructure structure;
  double baseSalary;
  double commissionRate;
  bool isCommissionPercentage;

  double totalAdvanceTaken;
  double totalPaid;
  double totalEarned;
  int servicesDoneThisMonth;

  List<AttendanceRecord> attendanceHistory;
  List<CommissionRecord> commissionHistory;

  StaffProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.cnic = '',
    this.address = '',
    this.emergencyContact = '',
    required this.joinDate,
    this.isActive = true,
    this.structure = PaymentStructure.commissionOnly,
    this.baseSalary = 0,
    this.commissionRate = 0,
    this.isCommissionPercentage = true,
    this.totalAdvanceTaken = 0,
    this.totalPaid = 0,
    this.totalEarned = 0,
    this.servicesDoneThisMonth = 0,
    this.attendanceHistory = const [],
    this.commissionHistory = const [],
  });

  double get outstandingBalance => totalEarned - totalPaid - totalAdvanceTaken;

  String get structureName {
    switch (structure) {
      case PaymentStructure.commissionOnly:
        return 'Commission Only';
      case PaymentStructure.fixedSalary:
        return 'Fixed Monthly';
      case PaymentStructure.dailyWage:
        return 'Daily Wage';
      case PaymentStructure.hybrid:
        return 'Hybrid (Base + Comm)';
    }
  }

  Map<String, dynamic> toMap() {
    String pt = structureName;
    return {
      if (int.tryParse(id) != null) 'id': int.tryParse(id),
      'name': name,
      'role': role,
      'phone': phone,
      'cnic': cnic,
      'address': address,
      'emergency_contact': emergencyContact,
      'payroll_type': pt,
      'commission_rate': commissionRate,
      'is_commission_percentage': isCommissionPercentage ? 1 : 0,
      'fixed_salary': baseSalary, // Store baseSalary in fixed_salary
      'daily_wage': structure == PaymentStructure.dailyWage ? baseSalary : 0,
      'total_advance_taken': totalAdvanceTaken,
      'total_paid': totalPaid,
      'total_earned': totalEarned,
      'services_done_this_month': servicesDoneThisMonth,
      'is_active': isActive ? 1 : 0,
      'created_at': joinDate.toIso8601String(),
    };
  }

  factory StaffProfile.fromMap(Map<String, dynamic> map) {
    PaymentStructure pt = PaymentStructure.commissionOnly;
    String mappedPT = map['payroll_type'] ?? '';
    if (mappedPT == 'Fixed Monthly') {
      pt = PaymentStructure.fixedSalary;
    } else if (mappedPT == 'Daily Wage')
      pt = PaymentStructure.dailyWage;
    else if (mappedPT == 'Hybrid (Base + Comm)')
      pt = PaymentStructure.hybrid;

    return StaffProfile(
      id: map['id'].toString(),
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? '',
      cnic: map['cnic'] ?? '',
      address: map['address'] ?? '',
      emergencyContact: map['emergency_contact'] ?? '',
      joinDate: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      isActive: (map['is_active'] ?? 1) == 1,
      structure: pt,
      commissionRate: (map['commission_rate'] ?? 0.0).toDouble(),
      isCommissionPercentage: (map['is_commission_percentage'] ?? 1) == 1,
      baseSalary: (map['fixed_salary'] ?? 0.0).toDouble(),
      totalAdvanceTaken: (map['total_advance_taken'] ?? 0.0).toDouble(),
      totalPaid: (map['total_paid'] ?? 0.0).toDouble(),
      totalEarned: (map['total_earned'] ?? 0.0).toDouble(),
      servicesDoneThisMonth: (map['services_done_this_month'] ?? 0).toInt(),
    );
  }
}

// ---------------- INVENTORY ----------------

class InventoryItem {
  String id;
  String name;
  String category;
  String unit;
  double purchasePrice;
  double sellingPrice;
  int quantity;
  int minThreshold;
  List<String> linkedServices;

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.quantity,
    required this.minThreshold,
    this.linkedServices = const [],
  });

  double get totalValue => purchasePrice * quantity;
  bool get isLowStock => quantity <= minThreshold;

  Map<String, dynamic> toMap() {
    return {
      if (int.tryParse(id) != null) 'id': int.tryParse(id),
      'name': name,
      'category': category,
      'stock': quantity,
      'unit': unit,
      'min_threshold': minThreshold,
      'purchase_price': purchasePrice,
      'retail_price': sellingPrice,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'].toString(),
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      unit: map['unit'] ?? '',
      quantity: (map['stock'] ?? 0.0).toInt(),
      minThreshold: (map['min_threshold'] ?? 5.0).toInt(),
      purchasePrice: (map['purchase_price'] ?? 0.0).toDouble(),
      sellingPrice: (map['retail_price'] ?? 0.0).toDouble(),
    );
  }
}

// ---------------- EXPENSES ----------------

class ExpenseItem {
  String id;
  DateTime date;
  String category;
  String description;
  double amount;
  String paymentMethod;
  bool isRecurring;
  bool hasReceipt;

  ExpenseItem({
    required this.id,
    required this.date,
    required this.category,
    required this.description,
    required this.amount,
    required this.paymentMethod,
    this.isRecurring = false,
    this.hasReceipt = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (int.tryParse(id) != null) 'id': int.tryParse(id),
      'category': category,
      'amount': amount,
      'description': description,
      'payment_method': paymentMethod,
      'is_recurring': isRecurring ? 1 : 0,
      'receipt_attached': hasReceipt ? 1 : 0,
      'created_at': date.toIso8601String(),
    };
  }

  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    return ExpenseItem(
      id: map['id'].toString(),
      date: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      category: map['category'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      description: map['description'] ?? '',
      paymentMethod: map['payment_method'] ?? '',
      isRecurring: (map['is_recurring'] ?? 0) == 1,
      hasReceipt: (map['receipt_attached'] ?? 0) == 1,
    );
  }
}

// ---------------- TRANSACTIONS ----------------

class TransactionRecord {
  String id;
  DateTime date;
  List<CartItem> items;
  /// Comma-separated service names from SQLite (`services` column) when items were not hydrated.
  String servicesSummary;
  double subtotal;
  double discount;
  double tip;
  double total;
  String customerId;
  String customerName;
  String staffId;
  String staffName;
  String paymentMethod;

  TransactionRecord({
    required this.id,
    required this.date,
    required this.items,
    this.servicesSummary = '',
    required this.subtotal,
    required this.discount,
    required this.tip,
    required this.total,
    required this.customerId,
    this.customerName = '',
    this.staffId = '',
    this.staffName = '',
    this.paymentMethod = 'Cash',
  });

  Map<String, dynamic> toMap() {
    final serviceLines = items
        .map((e) => '${e.service.name} [Staff: ${e.assignedStaff}]')
        .join(' | ');
    final staffSet = <String>{};
    for (final i in items) {
      final n = i.assignedStaff.trim();
      if (n.isEmpty || n.toLowerCase() == 'any') continue;
      staffSet.add(n);
    }

    return {
      if (int.tryParse(id) != null) 'id': int.tryParse(id),
      if (int.tryParse(customerId) != null)
        'customer_id': int.tryParse(customerId),
      'customer_name': customerName,
      if (int.tryParse(staffId) != null) 'staff_id': int.tryParse(staffId),
      'staff_name': staffName.isNotEmpty ? staffName : staffSet.join(', '),
      'services': serviceLines,
      'subtotal': subtotal,
      'discount': discount,
      'tip': tip,
      'loyalty_redeemed': 0.0,
      'total': total,
      'payment_method': paymentMethod,
      'created_at': date.toIso8601String(),
    };
  }

  factory TransactionRecord.fromMap(Map<String, dynamic> map) {
    return TransactionRecord(
      id: map['id'].toString(),
      date: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      items: [],
      servicesSummary: map['services']?.toString() ?? '',
      subtotal: (map['subtotal'] ?? 0.0).toDouble(),
      discount: (map['discount'] ?? 0.0).toDouble(),
      tip: (map['tip'] ?? 0.0).toDouble(),
      total: (map['total'] ?? 0.0).toDouble(),
      customerId: map['customer_id']?.toString() ?? '',
      customerName: map['customer_name'] ?? '',
      staffId: map['staff_id']?.toString() ?? '',
      staffName: map['staff_name'] ?? '',
      paymentMethod: map['payment_method'] ?? 'Cash',
    );
  }
}
