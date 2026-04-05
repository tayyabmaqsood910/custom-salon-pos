import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_currency.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../utils/material_icon_from_codepoint.dart';
import 'receipt_pdf_generator.dart';
import '../utils/responsive_layout.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final ScrollController _categoryScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _paymentMethod = context.read<AppProvider>().settings['defaultPaymentMethod'] ?? 'Cash';
        });
      }
    });
  }

  @override
  void dispose() {
    _categoryScrollCtrl.dispose();
    _receivedAmountCtrl.dispose();
    super.dispose();
  }
  String get _currency =>
      context.read<AppProvider>().settings['currencySymbol'] ??
      kDefaultCurrencySymbol;

  String _selectedCategory = 'All';
  String _searchQuery = '';
  List<CartItem> _cart = [];
  String _paymentMethod = 'Cash'; // Cash, Card, Mobile, Split
  final TextEditingController _receivedAmountCtrl = TextEditingController();
  double _receivedAmount = 0.0;

  // Billing discounts & additions
  double _orderDiscount = 0.0;
  bool _isOrderDiscountPercent = false;
  double _tip = 0.0;
  int _redeemedPoints = 0; // The actual flat amount of points subtracted
  Map<String, double> _splitPayments = {}; // Example: {'Cash': 50, 'Card': 25}

  // Customer logic
  CustomerProfile? _customer;

  int _availableLoyaltyPoints(CustomerProfile? customer) {
    if (customer == null) return 0;
    final settings = context.read<AppProvider>().settings;
    final enabled = (settings['enableLoyalty'] ?? 'true') == 'true';
    if (!enabled) return 0;

    final expiry = settings['pointsExpiry'] ?? 'Never Expire';
    if (expiry == 'Never Expire') return customer.loyaltyPoints;

    final now = DateTime.now();
    int maxAgeDays = 0;
    if (expiry == '6 Months') maxAgeDays = 180;
    if (expiry == '12 Months') maxAgeDays = 365;
    if (maxAgeDays <= 0) return customer.loyaltyPoints;

    final age = now.difference(customer.memberSince).inDays;
    return age > maxAgeDays ? 0 : customer.loyaltyPoints;
  }

  List<String> get _categories {
    final services = context.read<AppProvider>().services;
    final set = <String>{};
    for (final s in services) {
      final c = s.category.trim();
      if (c.isNotEmpty) set.add(c);
    }
    final sorted = set.toList()..sort((a, b) => a.compareTo(b));
    return ['All', ...sorted];
  }

  List<String> get _staffList {
    final staff = context.watch<AppProvider>().staff;
    return ['Any', ...staff.map((s) => s.name)];
  }

  List<ServiceItem> get _filteredServices {
    final allServices = context.watch<AppProvider>().services;
    final activeCategory = _categories.contains(_selectedCategory)
        ? _selectedCategory
        : 'All';
    return allServices.where((s) {
      final matchesCategory =
          activeCategory == 'All' || s.category == activeCategory;
      final matchesSearch = s.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      return matchesCategory && matchesSearch;
    }).toList();
  }

  // Calculations
  double get _subtotal =>
      _cart.fold(0, (sum, item) => sum + item.service.price);

  double get _itemDiscountsTotal => _cart.fold(0, (sum, item) {
    if (item.isPercentDiscount) {
      return sum + (item.service.price * (item.discount / 100));
    }
    return sum + item.discount;
  });

  double get _orderDiscountTotal {
    double tempSub = _subtotal - _itemDiscountsTotal;
    if (_isOrderDiscountPercent) {
      return tempSub * (_orderDiscount / 100);
    }
    return _orderDiscount;
  }

  double get _pointsDiscountTotal {
    double redeemRate = double.tryParse(context.read<AppProvider>().settings['pointsRedeemRate'] ?? '10') ?? 10.0;
    if (redeemRate <= 0) return 0.0;
    return _redeemedPoints / redeemRate;
  }

  double get _total {
    double t =
        _subtotal -
        _itemDiscountsTotal -
        _orderDiscountTotal -
        _pointsDiscountTotal;
    if (t < 0) t = 0;
    return t + _tip;
  }

  double get _change => _receivedAmount > _total ? _receivedAmount - _total : 0.0;
  double get _splitReceived =>
      (_splitPayments['Cash'] ?? 0) + (_splitPayments['Card'] ?? 0);
  double get _effectiveReceived {
    switch (_paymentMethod) {
      case 'Cash':
        return _receivedAmount;
      case 'Split':
        return _splitReceived;
      default:
        return _total;
    }
  }
  double get _amountShort =>
      _effectiveReceived < _total ? (_total - _effectiveReceived) : 0.0;

  // DIALOG CONTROLLERS
  void _showDiscountDialog({CartItem? item}) {
    double tempAmount = item != null ? item.discount : _orderDiscount;
    bool tempPercent = item != null
        ? item.isPercentDiscount
        : _isOrderDiscountPercent;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: Text(item != null ? 'Item Discount' : 'Bill Discount'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: Text('$_currency Fixed'),
                      selected: !tempPercent,
                      onSelected: (val) =>
                          setStateSB(() => tempPercent = false),
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text('% Percent'),
                      selected: tempPercent,
                      onSelected: (val) => setStateSB(() => tempPercent = true),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  onChanged: (val) => tempAmount = double.tryParse(val) ?? 0.0,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    if (item != null) {
                      item.discount = tempAmount;
                      item.isPercentDiscount = tempPercent;
                    } else {
                      _orderDiscount = tempAmount;
                      _isOrderDiscountPercent = tempPercent;
                    }
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLoyaltyDialog() {
    final available = _availableLoyaltyPoints(_customer);
    if (_customer == null || available <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No redeemable points available.')),
      );
      return;
    }
    int pointsToRedeem = 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Redeem Loyalty Points'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available Points: $available'),
            Text(
              '(${context.read<AppProvider>().settings['pointsRedeemRate'] ?? '10'} points = ${_currency}1.00 deduction)',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Points to redeem'),
              onChanged: (val) {
                int p = int.tryParse(val) ?? 0;
                pointsToRedeem = p > available
                    ? available
                    : p;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _redeemedPoints = pointsToRedeem;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
  }

  void _showSplitPaymentDialog() {
    double tempCash = 0;
    double tempCard = 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Split Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total Due: $_currency${_total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cash Amount'),
              onChanged: (val) => tempCash = double.tryParse(val) ?? 0,
            ),
            const SizedBox(height: 8),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Card Amount'),
              onChanged: (val) => tempCard = double.tryParse(val) ?? 0,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _paymentMethod = 'Split';
                _splitPayments = {'Cash': tempCash, 'Card': tempCard};
              });
              Navigator.pop(ctx);
            },
            child: const Text('Confirm Split'),
          ),
        ],
      ),
    );
  }

  void _showTipDialog() {
    double tempTip = 0.0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Staff Tip'),
        content: TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Tip Amount ($_currency)'),
          onChanged: (val) => tempTip = double.tryParse(val) ?? 0.0,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _tip = tempTip);
              Navigator.pop(ctx);
            },
            child: const Text('Add Tip'),
          ),
        ],
      ),
    );
  }

  void _parkBill() {
    if (_cart.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) {
        String refName =
            'Bill ${context.read<AppProvider>().parkedBills.length + 1}';
        return AlertDialog(
          title: const Text('Hold / Park Bill'),
          content: TextField(
            decoration: const InputDecoration(
              labelText: 'Reference Name / Note',
            ),
            onChanged: (val) => refName = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  context.read<AppProvider>().addParkedBill(
                    ParkedBill(
                      reference: refName,
                      cart: List.from(_cart),
                      time: DateTime.now(),
                      customerId: _customer?.id ?? 'Walk-in',
                    ),
                  );
                  _cart.clear();
                  _resetBillingModifiers();
                });
                Navigator.pop(ctx);
              },
              child: const Text('Hold Bill'),
            ),
          ],
        );
      },
    );
  }

  void _showParkedBills() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Parked Bills'),
        content: SizedBox(
          width: 400,
          child: Consumer<AppProvider>(
            builder: (ctx, provider, _) {
              final parkedBills = provider.parkedBills;
              if (parkedBills.isEmpty) {
                return const Center(child: Text('No saved bills yet.'));
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: parkedBills.length,
                itemBuilder: (ctx, idx) {
                  final pb = parkedBills[idx];
                  final custName = pb.customerId == 'Walk-in'
                      ? 'Walk-in'
                      : (provider.customers
                                .where((c) => c.id == pb.customerId)
                                .isNotEmpty
                            ? provider.customers
                                  .firstWhere((c) => c.id == pb.customerId)
                                  .name
                            : 'Unknown');
                  return ListTile(
                    title: Text(pb.reference),
                    subtitle: Text('$custName - ${pb.cart.length} items'),
                    trailing: Text(
                      '${pb.time.hour}:${pb.time.minute.toString().padLeft(2, '0')}',
                    ),
                    onTap: () {
                      setState(() {
                        _cart = List.from(pb.cart);
                        if (pb.customerId == 'Walk-in') {
                          _customer = null;
                        } else {
                          try {
                            _customer = provider.customers.firstWhere(
                              (c) => c.id == pb.customerId,
                            );
                          } catch (_) {
                            _customer = null;
                          }
                        }
                        provider.deleteParkedBill(pb);
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEditTransactionDialog(TransactionRecord tx) {
    final customerCtrl = TextEditingController(
      text: tx.customerName.isNotEmpty ? tx.customerName : 'Walk-in Customer',
    );
    String paymentMethod = tx.paymentMethod;
    final methods = const ['Cash', 'Card', 'Mobile', 'Split'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) => AlertDialog(
          title: const Text('Edit Sale'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: customerCtrl,
                  decoration: const InputDecoration(labelText: 'Customer Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: methods.contains(paymentMethod)
                      ? paymentMethod
                      : 'Cash',
                  decoration: const InputDecoration(labelText: 'Payment Method'),
                  items: methods
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setStateSB(() => paymentMethod = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                tx.customerName = customerCtrl.text.trim().isEmpty
                    ? 'Walk-in Customer'
                    : customerCtrl.text.trim();
                tx.paymentMethod = paymentMethod;
                await context.read<AppProvider>().updateTransactionItem(tx);
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sale updated')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSalesHistoryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sales History'),
        content: SizedBox(
          width: 650,
          height: 420,
          child: Consumer<AppProvider>(
            builder: (ctx, provider, _) {
              final transactions = provider.transactions;
              if (transactions.isEmpty) {
                return const Center(child: Text('No sales found yet.'));
              }
              return ListView.separated(
                itemCount: transactions.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: Colors.white12),
                itemBuilder: (ctx, i) {
                  final tx = transactions[i];
                  return ListTile(
                    title: Text(
                      tx.servicesSummary.isNotEmpty
                          ? tx.servicesSummary
                          : 'Sale #${tx.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${tx.customerName.isNotEmpty ? tx.customerName : 'Walk-in Customer'} · ${tx.paymentMethod} · ${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        Text(
                          '$_currency${tx.total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blueAccent),
                          tooltip: 'Edit sale',
                          onPressed: () => _showEditTransactionDialog(tx),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          tooltip: 'Delete sale',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (confirmCtx) => AlertDialog(
                                title: const Text('Delete Sale'),
                                content: const Text(
                                  'Are you sure you want to delete this sale?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(confirmCtx),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                    ),
                                    onPressed: () async {
                                      await provider.deleteTransaction(tx);
                                      if (!mounted) return;
                                      Navigator.pop(confirmCtx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Sale deleted'),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _resetBillingModifiers() {
    _orderDiscount = 0;
    _isOrderDiscountPercent = false;
    _tip = 0;
    _redeemedPoints = 0;
    _paymentMethod = context.read<AppProvider>().settings['defaultPaymentMethod'] ?? 'Cash';
    _splitPayments = {};
    _customer = null;
    _receivedAmount = 0;
    _receivedAmountCtrl.clear();
  }

  void _showOrderSuccessDialog({
    required String orderId,
    required List<CartItem> items,
    required double subtotal,
    required double totalDiscount,
    required double total,
    required double received,
    required double change,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161618),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                   Icon(Icons.check_circle, color: Colors.greenAccent, size: 28),
                   SizedBox(width: 12),
                   Text('Order Placed!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(orderId, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Colors.white10),
              ),
              // Item List
              ...items.map((it) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(it.service.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    Row(
                      children: [
                        Text('x1', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        const SizedBox(width: 12),
                        Text('$_currency${it.finalPrice.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFFF6231), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 8),
              _buildSummaryRow('Subtotal', '$_currency${subtotal.toStringAsFixed(0)}', color: Colors.grey[600]!),
              if (totalDiscount > 0)
                _buildSummaryRow('Discount', '-$_currency${totalDiscount.toStringAsFixed(0)}', color: Colors.redAccent),
              _buildSummaryRow('Total', '$_currency${total.toStringAsFixed(0)}', color: Colors.white, bold: true, fontSize: 20),
              const SizedBox(height: 8),
              _buildSummaryRow('Received', '$_currency${received.toStringAsFixed(0)}', color: Colors.grey[600]!),
              _buildSummaryRow('Change', '$_currency${change.toStringAsFixed(0)}', color: Colors.greenAccent, bold: true),
              
              const SizedBox(height: 32),
              Row(
                children: [
                   Expanded(
                     child: OutlinedButton(
                       onPressed: () {
                         Navigator.pop(ctx);
                         // Re-print logic if needed, but usually already printed
                       },
                       style: OutlinedButton.styleFrom(
                         padding: const EdgeInsets.symmetric(vertical: 16),
                         side: const BorderSide(color: Color(0xFFFF6231)),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                       ),
                       child: const Text('Print Receipt', style: TextStyle(color: Color(0xFFFF6231), fontWeight: FontWeight.bold)),
                     ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: ElevatedButton(
                       onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _cart.clear();
                            _resetBillingModifiers();
                          });
                       },
                       style: ElevatedButton.styleFrom(
                         padding: const EdgeInsets.symmetric(vertical: 16),
                         backgroundColor: const Color(0xFFFF6231),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                       ),
                       child: const Text('New Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                     ),
                   ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppBreakpoints.pagePadding(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < AppBreakpoints.tablet;
          final isPhone = constraints.maxWidth < AppBreakpoints.mobile;

          if (isPhone) {
            final serviceHeight = constraints.maxHeight * 0.42;
            final cartHeight = constraints.maxHeight * 0.9;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  _buildCategories(),
                  const SizedBox(height: 16),
                  SizedBox(height: serviceHeight, child: _buildServiceGrid()),
                  const SizedBox(height: 16),
                  SizedBox(height: cartHeight, child: _buildCartPanel()),
                ],
              ),
            );
          }

          if (isSmall) {
            return Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSearchBar(),
                      const SizedBox(height: 20),
                      _buildCategories(),
                      const SizedBox(height: 20),
                      Expanded(child: _buildServiceGrid()),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(flex: 4, child: _buildCartPanel()),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT COLUMN: Services Catalog
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 20),
                    _buildCategories(),
                    const SizedBox(height: 20),
                    Expanded(child: _buildServiceGrid()),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // RIGHT COLUMN: Cart / Billing
              Expanded(flex: 3, child: _buildCartPanel()),
            ],
          );
        },
      ),
    );
  }

  // ----------- SERVICE MANAGEMENT METHODS -----------

  final Map<String, IconData> _availableIcons = {
    'Scissors': Icons.content_cut,
    'Face': Icons.face,
    'Spa': Icons.spa,
    'Water Drop': Icons.water_drop,
    'Hand': Icons.back_hand,
    'Star': Icons.star,
    'Color Lens': Icons.color_lens,
    'Child': Icons.child_care,
    'Face Natural': Icons.face_retouching_natural,
    'Brush': Icons.brush,
    'Self Care': Icons.self_improvement,
    'Favorite': Icons.favorite,
    'Diamond': Icons.diamond,
    'Auto Awesome': Icons.auto_awesome,
    'Edit': Icons.edit,
  };

  void _showAddEditServiceDialog([ServiceItem? existing]) {
    final isEditing = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.price.toStringAsFixed(2) : '',
    );
    final categoryOptions = _categories.where((c) => c != 'All').toList();
    String selectedCategory = existing?.category ??
        (categoryOptions.isNotEmpty ? categoryOptions.first : 'General');
    if (categoryOptions.isNotEmpty &&
        !categoryOptions.contains(selectedCategory)) {
      selectedCategory = categoryOptions.first;
    }
    String selectedIconKey = _availableIcons.entries
        .firstWhere(
          (e) =>
              e.value.codePoint ==
              (existing?.iconCodePoint ?? Icons.content_cut.codePoint),
          orElse: () => _availableIcons.entries.first,
        )
        .key;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: Text(isEditing ? 'Edit Service' : 'Add New Service'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Service Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Price ($_currency)',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: [
                        for (final c in categoryOptions)
                          DropdownMenuItem(value: c, child: Text(c)),
                        if (categoryOptions.isEmpty)
                          const DropdownMenuItem(
                            value: 'General',
                            child: Text('General'),
                          ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setStateSB(() => selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Icon',
                        border: OutlineInputBorder(),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableIcons.entries.map((entry) {
                          final isSelected = selectedIconKey == entry.key;
                          return InkWell(
                            onTap: () =>
                                setStateSB(() => selectedIconKey = entry.key),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(
                                        context,
                                      ).primaryColor.withValues(alpha: 0.2)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : Colors.white24,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                entry.value,
                                size: 24,
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: Icon(isEditing ? Icons.save : Icons.add, size: 18),
                label: Text(isEditing ? 'Save' : 'Add Service'),
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final price = double.tryParse(priceCtrl.text) ?? 0.0;
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Service name is required')),
                    );
                    return;
                  }

                  final iconCodePoint =
                      _availableIcons[selectedIconKey]!.codePoint;

                  if (isEditing) {
                    existing.name = name;
                    existing.price = price;
                    existing.category = selectedCategory;
                    existing.iconCodePoint = iconCodePoint;
                    context.read<AppProvider>().updateServiceItem(existing);
                  } else {
                    final newService = ServiceItem(
                      id: '',
                      name: name,
                      price: price,
                      category: selectedCategory,
                      iconCodePoint: iconCodePoint,
                    );
                    context.read<AppProvider>().addService(newService);
                  }
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEditing ? 'Service updated!' : 'Service added!',
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteServiceConfirmation(ServiceItem service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text(
          'Are you sure you want to delete "${service.name}"?\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              context.read<AppProvider>().deleteService(service);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"${service.name}" deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showManageServicesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Manage Services'),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
              tooltip: 'Add Service',
              onPressed: () {
                Navigator.pop(ctx);
                _showAddEditServiceDialog();
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: Consumer<AppProvider>(
            builder: (ctx, provider, _) {
              if (provider.services.isEmpty) {
                return const Center(child: Text('No services yet. Add one!'));
              }
              return ListView.builder(
                itemCount: provider.services.length,
                itemBuilder: (ctx, idx) {
                  final s = provider.services[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListTile(
                      leading: Icon(
                        s.icon,
                        color: Theme.of(context).primaryColor,
                      ),
                      title: Text(
                        s.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${s.category} • $_currency${s.price.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              size: 18,
                              color: Colors.blueAccent,
                            ),
                            tooltip: 'Edit',
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showAddEditServiceDialog(s);
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                            tooltip: 'Delete',
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showDeleteServiceConfirmation(s);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1100;
        final searchBox = Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              icon: Icon(Icons.search, color: Colors.grey[400]),
              hintText: 'Search services...',
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey[600]),
            ),
          ),
        );

        final actions = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _showManageServicesDialog,
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('Manage'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).cardColor,
                  foregroundColor: Colors.white,
                  iconColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showSalesHistoryDialog,
                icon: const Icon(Icons.history),
                label: const Text('Sales History'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).cardColor,
                  foregroundColor: Colors.white,
                  iconColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showParkedBills,
                icon: const Icon(Icons.list_alt),
                label: Consumer<AppProvider>(
                  builder: (ctx, provider, _) =>
                      Text('Saved Bills (${provider.parkedBills.length})'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).cardColor,
                  foregroundColor: Colors.white,
                  iconColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              searchBox,
              const SizedBox(height: 12),
              actions,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchBox),
            const SizedBox(width: 12),
            Flexible(child: actions),
          ],
        );
      },
    );
  }

  Widget _buildCategories() {
    void slideBy(double offset) {
      if (!_categoryScrollCtrl.hasClients) return;
      final pos = _categoryScrollCtrl.position;
      final target = (_categoryScrollCtrl.offset + offset).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      );
      _categoryScrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 640;
        return Row(
          children: [
            if (!isCompact)
              IconButton(
                tooltip: 'Slide left',
                onPressed: () => slideBy(-220),
                icon: const Icon(Icons.chevron_left),
              ),
            Expanded(
              child: Scrollbar(
                controller: _categoryScrollCtrl,
                thumbVisibility: true,
                interactive: true,
                radius: const Radius.circular(999),
                child: SingleChildScrollView(
                  controller: _categoryScrollCtrl,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (selected) =>
                              setState(() => _selectedCategory = cat),
                          backgroundColor: Theme.of(context).cardColor,
                          selectedColor: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey[400],
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            if (!isCompact)
              IconButton(
                tooltip: 'Slide right',
                onPressed: () => slideBy(220),
                icon: const Icon(Icons.chevron_right),
              ),
          ],
        );
      },
    );
  }

  Widget _buildServiceGrid() {
    return LayoutBuilder(
      builder: (context, c) {
        final tileExtent = c.maxWidth < 420
            ? 120.0
            : (c.maxWidth < 600 ? 145.0 : 170.0);
        final tileAspect = c.maxWidth < 420
            ? 0.90
            : (c.maxWidth < 600 ? 1.0 : 1.12);
        return GridView.builder(
      itemCount: _filteredServices.length + 1,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: tileExtent,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: tileAspect,
      ),
      itemBuilder: (context, index) {
        // Last card is the "+ Add Service" card
        if (index == _filteredServices.length) {
          return InkWell(
            onTap: () => _showAddEditServiceDialog(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    color: Theme.of(context).primaryColor,
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add Service',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final service = _filteredServices[index];
        return InkWell(
          onTap: () {
            if (service.name == 'Custom Amount') {
              _showCustomPriceDialog(service);
            } else {
              setState(() => _cart.add(CartItem(service: service)));
            }
          },
          onLongPress: () {
            showModalBottomSheet(
              context: context,
              builder: (ctx) => SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit, color: Colors.blueAccent),
                      title: const Text('Edit Service'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showAddEditServiceDialog(service);
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.delete,
                        color: Colors.redAccent,
                      ),
                      title: const Text('Delete Service'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showDeleteServiceConfirmation(service);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.close),
                      title: const Text('Cancel'),
                      onTap: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  service.icon,
                  color: Theme.of(context).primaryColor,
                  size: c.maxWidth < 420 ? 22 : 26,
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    service.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: c.maxWidth < 420 ? 13 : 14,
                      height: 1.05,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  service.name == 'Custom Amount'
                      ? 'Variables'
                      : '$_currency${service.price.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: c.maxWidth < 420 ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
        );
      },
    );
  }

  void _showCustomPriceDialog(ServiceItem baseService) {
    double tempPrice = 0;
    String tempName = "Custom Service";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom Service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Description'),
              onChanged: (val) =>
                  tempName = val.isEmpty ? "Custom Service" : val,
            ),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Price ($_currency)'),
              onChanged: (val) => tempPrice = double.tryParse(val) ?? 0,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                _cart.add(
                  CartItem(
                    service: ServiceItem(
                      id: 'c',
                      name: tempName,
                      price: tempPrice,
                      category: 'Custom',
                      iconCodePoint: Icons.edit.codePoint,
                    ),
                  ),
                );
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildCartPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          // Cart Header
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current Bill',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _cart.clear();
                    _resetBillingModifiers();
                  }),
                  child: const Text(
                    'Clear All',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white24),

          // Customer Selection
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Consumer<AppProvider>(
                      builder: (ctx, provider, _) {
                        return DropdownButtonHideUnderline(
                          child: DropdownButton<CustomerProfile?>(
                            value: _customer,
                            isExpanded: true,
                            dropdownColor: Theme.of(context).cardColor,
                            items: [
                              const DropdownMenuItem<CustomerProfile?>(
                                value: null,
                                child: Text('Walk-in Customer'),
                              ),
                              ...provider.customers.map((e) {
                                final availablePts = _availableLoyaltyPoints(e);
                                return DropdownMenuItem<CustomerProfile?>(
                                  value: e,
                                  child: Text(
                                    availablePts > 0 &&
                                            (provider.settings['enableLoyalty'] ?? 'true') ==
                                                'true'
                                        ? '${e.name} ($availablePts pts)'
                                        : e.name,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _customer = val;
                                _redeemedPoints = 0; // reset
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (_customer != null &&
                    _availableLoyaltyPoints(_customer) > 0 &&
                    (context.watch<AppProvider>().settings['enableLoyalty'] ?? 'true') ==
                        'true')
                  IconButton(
                    icon: const Icon(Icons.stars, color: Colors.amber),
                    tooltip: 'Redeem Points',
                    onPressed: _showLoyaltyDialog,
                  ),
              ],
            ),
          ),

          // Cart Items List
          Expanded(
            child: _cart.isEmpty
                ? const Center(
                    child: Text(
                      'No services added yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.service.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$_currency${item.finalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () =>
                                      setState(() => _cart.removeAt(index)),
                                ),
                              ],
                            ),
                            if (item.discount > 0)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Disc: -${item.isPercentDiscount ? '${item.discount}%' : '$_currency${item.discount}'}',
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            Row(
                              children: [
                                const Text(
                                  'Staff:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: item.assignedStaff,
                                      isExpanded: true,
                                      iconSize: 16,
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontSize: 12,
                                      ),
                                      items: _staffList
                                          .map(
                                            (e) => DropdownMenuItem(
                                              value: e,
                                              child: Text(e),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(
                                            () => item.assignedStaff = val,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.local_offer_outlined,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () =>
                                      _showDiscountDialog(item: item),
                                  tooltip: 'Item Discount',
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Totals and Payment Section
          Container(
            constraints: BoxConstraints(
              maxHeight: _paymentMethod == 'Cash'
                  ? MediaQuery.of(context).size.height * 0.48
                  : MediaQuery.of(context).size.height * 0.36,
            ),
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                _buildSummaryRow(
                  'Subtotal',
                  '$_currency${_subtotal.toStringAsFixed(2)}',
                ),
                if (_itemDiscountsTotal > 0)
                  _buildSummaryRow(
                    'Item Discounts',
                    '-$_currency${_itemDiscountsTotal.toStringAsFixed(2)}',
                    color: Colors.redAccent,
                  ),
                if (_orderDiscountTotal > 0)
                  _buildSummaryRow(
                    'Order Discount',
                    '-$_currency${_orderDiscountTotal.toStringAsFixed(2)}',
                    color: Colors.redAccent,
                  ),
                if (_pointsDiscountTotal > 0)
                  _buildSummaryRow(
                    'Points Redemption',
                    '-$_currency${_pointsDiscountTotal.toStringAsFixed(2)}',
                    color: Colors.amber,
                  ),

                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    InkWell(
                      onTap: () => _showDiscountDialog(),
                      child: const Text(
                        '+ Add Discount',
                        style: TextStyle(color: Colors.blueAccent),
                      ),
                    ),
                    if ((context.watch<AppProvider>().settings['enableTip'] ?? 'true') == 'true')
                      InkWell(
                        onTap: _showTipDialog,
                        child: Text(
                          _tip > 0
                              ? 'Tip: $_currency${_tip.toStringAsFixed(2)}'
                              : '+ Add Tip',
                          style: const TextStyle(color: Colors.greenAccent),
                        ),
                      ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Colors.white24),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$_currency${_total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Payment Methods
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildPaymentBtn('Cash', Icons.money),
                    _buildPaymentBtn('Card', Icons.credit_card),
                    _buildPaymentBtn('Mobile', Icons.phone_android),
                    _buildPaymentBtn('Split', Icons.pie_chart),
                  ],
                ),
                if (_paymentMethod == 'Split')
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Cash: $_currency${_splitPayments['Cash'] ?? 0} | Card: $_currency${_splitPayments['Card'] ?? 0}',
                    ),
                  ),
                if (_amountShort > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Pending: $_currency${_amountShort.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                
                if (_paymentMethod == 'Cash') ...[
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Amount Received', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _receivedAmountCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: 'Enter amount...',
                          filled: true,
                          fillColor: Colors.black26,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onChanged: (v) => setState(() => _receivedAmount = double.tryParse(v) ?? 0.0),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [500, 1000, 2000, 5000].map((amt) => InkWell(
                          onTap: () {
                            setState(() {
                              _receivedAmount = amt.toDouble();
                              _receivedAmountCtrl.text = amt.toString();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text('$_currency$amt', style: const TextStyle(fontSize: 12)),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Change', style: TextStyle(color: Colors.grey)),
                          Text(
                            '$_currency${_change.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                // Actions
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _parkBill,
                        icon: const Icon(
                          Icons.pause,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          'Hold',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _cart.isEmpty
                            ? null
                            : () async {
                                if (_amountShort > 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Payment is short by $_currency${_amountShort.toStringAsFixed(2)}. Please collect full amount before checkout.',
                                      ),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                  return;
                                }

                                final subtotalSnapshot = _subtotal;
                                final totalDiscountSnapshot =
                                    _orderDiscountTotal + _itemDiscountsTotal;
                                final totalSnapshot = _total;
                                final receivedSnapshot = _effectiveReceived;
                                final changeSnapshot =
                                    receivedSnapshot > totalSnapshot
                                        ? (receivedSnapshot - totalSnapshot)
                                        : 0.0;

                                final provider = context.read<AppProvider>();
                                final settings = provider.settings;
                                await ReceiptGenerator.printReceipt(
                                  cart: _cart,
                                  customerName: _customer?.name ?? 'Walk-in Customer',
                                  subtotal: subtotalSnapshot,
                                  itemDiscounts: _itemDiscountsTotal,
                                  orderDiscount: _orderDiscountTotal,
                                  redeemedPointsDiscount: _pointsDiscountTotal,
                                  tip: _tip,
                                  total: totalSnapshot,
                                  paymentMethod: _paymentMethod,
                                  splits: _splitPayments,
                                  currencySymbol: _currency,
                                  salonName: settings['salonName'] ?? 'STYLES POS',
                                  address: settings['address'] ?? 'Hair & Beauty Salon\n123 Main Street',
                                  footerMessage: settings['receiptFooter'] ?? 'Thank you for your visit!',
                                );

                                final tx = TransactionRecord(
                                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                                  date: DateTime.now(),
                                  items: List.from(_cart),
                                  subtotal: subtotalSnapshot,
                                  discount: totalDiscountSnapshot,
                                  tip: _tip,
                                  total: totalSnapshot,
                                  customerId: _customer?.id ?? 'Walk-in',
                                  customerName: _customer?.name ?? 'Walk-in Customer',
                                  staffName: _cart
                                      .map((e) => e.assignedStaff.trim())
                                      .where(
                                        (n) =>
                                            n.isNotEmpty &&
                                            n.toLowerCase() != 'any',
                                      )
                                      .toSet()
                                      .join(', '),
                                  paymentMethod: _paymentMethod,
                                );
                                await provider.addTransaction(tx);

                                if (_customer != null) {
                                  final availableBefore =
                                      _availableLoyaltyPoints(_customer);
                                  final redeemApplied = _redeemedPoints > availableBefore
                                      ? availableBefore
                                      : _redeemedPoints;
                                  if (redeemApplied > 0) {
                                    _customer!.loyaltyPoints -= redeemApplied;
                                  }
                                  if ((settings['enableLoyalty'] ?? 'true') == 'true') {
                                    final earnRate = double.tryParse(settings['pointsEarnRate'] ?? '10') ?? 10.0;
                                    if (earnRate > 0) {
                                      _customer!.loyaltyPoints += (totalSnapshot / earnRate).toInt();
                                    }
                                  }
                                  await provider.updateCustomerItem(_customer!);
                                }

                                if ((settings['autoDeductStock'] ?? 'true') == 'true') {
                                  var invSnapshot = List<InventoryItem>.from(provider.inventory);
                                  for (final cartItem in _cart) {
                                    for (var i = 0; i < invSnapshot.length; i++) {
                                      final invItem = invSnapshot[i];
                                      if (!invItem.linkedServices.contains(cartItem.service.name)) {
                                        continue;
                                      }
                                      final nextQty = invItem.quantity > 0 ? invItem.quantity - 1 : 0;
                                      final updated = InventoryItem(
                                        id: invItem.id,
                                        name: invItem.name,
                                        category: invItem.category,
                                        unit: invItem.unit,
                                        purchasePrice: invItem.purchasePrice,
                                        sellingPrice: invItem.sellingPrice,
                                        quantity: nextQty,
                                        minThreshold: invItem.minThreshold,
                                        linkedServices: invItem.linkedServices,
                                      );
                                      await provider.updateInventoryItem(updated);
                                      invSnapshot[i] = updated;
                                    }
                                  }
                                }

                                if (!mounted) return;
                                _showOrderSuccessDialog(
                                  orderId: 'ORD-${tx.id.length >= 8 ? tx.id.substring(tx.id.length - 8).toUpperCase() : tx.id.toUpperCase()}',
                                  items: List.from(_cart),
                                  subtotal: subtotalSnapshot,
                                  totalDiscount: totalDiscountSnapshot,
                                  total: totalSnapshot,
                                  received: receivedSnapshot,
                                  change: changeSnapshot,
                                );

                                setState(() {
                                  _cart.clear();
                                  _resetBillingModifiers();
                                });
                              },
                        icon: const Icon(
                          Icons.receipt_long,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          'Pay & Print',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String title,
    String value, {
    Color color = Colors.grey,
    bool bold = false,
    double fontSize = 14,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: color, fontSize: fontSize),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                fontSize: fontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBtn(String method, IconData icon) {
    final isSelected = _paymentMethod == method;
    return InkWell(
      onTap: () {
        if (method == 'Split') {
          _showSplitPaymentDialog();
        } else {
          setState(() => _paymentMethod = method);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.white24,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            ),
            const SizedBox(height: 4),
            Text(
              method,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
