import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_currency.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../utils/responsive_layout.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Hair Products',
    'Skin & Face',
    'Beard Products',
    'Tools & Equipment',
    'Disposables',
    'Miscellaneous',
  ];

  final List<String> _units = ['pcs', 'ml', 'grams', 'boxes', 'liters'];

  List<String> get _categoryOptions {
    final fromData = context.read<AppProvider>().inventory
        .map((e) => e.category.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final all = <String>{..._categories.where((c) => c != 'All'), ...fromData};
    final sorted = all.toList()..sort((a, b) => a.compareTo(b));
    return ['All', ...sorted];
  }

  List<InventoryItem> get _filteredItems {
    final list = context.watch<AppProvider>().inventory;
    return list.where((i) {
      final itemCategory = i.category.trim().toLowerCase();
      final selected = _selectedCategory.trim().toLowerCase();
      final matchCat = selected == 'all' || itemCategory == selected;
      final matchQuery = i.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      return matchCat && matchQuery;
    }).toList();
  }

  double get _totalValuation {
    final list = context.read<AppProvider>().inventory;
    return list.fold(0, (sum, i) => sum + i.totalValue);
  }

  int get _lowStockCount {
    final list = context.read<AppProvider>().inventory;
    return list.where((i) => i.isLowStock).length;
  }

  void _showAddEditDialog([InventoryItem? item]) {
    final currency =
        context.read<AppProvider>().settings['currencySymbol'] ??
            kDefaultCurrencySymbol;
    final isEditing = item != null;
    final previousQty = item?.quantity ?? 0;
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    String cat = item?.category ?? 'Hair Products';
    String unit = item?.unit ?? 'pcs';
    final pPriceCtrl = TextEditingController(
      text: item?.purchasePrice.toString() ?? '',
    );
    final sPriceCtrl = TextEditingController(
      text: item?.sellingPrice.toString() ?? '',
    );
    final qtyCtrl = TextEditingController(
      text: item?.quantity.toString() ?? '',
    );
    final minCtrl = TextEditingController(
      text: item?.minThreshold.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: Text(isEditing ? 'Edit Item' : 'Add New Item'),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Item Name'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: cat,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categoryOptions
                          .where((c) => c != 'All')
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) => setStateSB(() => cat = v!),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: unit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                            ),
                            items: _units
                                .map(
                                  (u) => DropdownMenuItem(
                                    value: u,
                                    child: Text(u),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setStateSB(() => unit = v!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Current Qty',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: minCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Min Alert',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pPriceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Purchase Price ($currency)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: sPriceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Retail Price ($currency)',
                              helperText: '(Optional if not for sale)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isEditing) ...[
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Auto-Deduct Services:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        item.linkedServices.isEmpty
                            ? 'None'
                            : item.linkedServices.join(', '),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.link),
                        label: const Text('Link / Unlink Services'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final provider = context.read<AppProvider>();
                  if (isEditing) {
                    final oldQty = previousQty;
                    item.name = nameCtrl.text;
                    item.category = cat;
                    item.unit = unit;
                    item.purchasePrice = double.tryParse(pPriceCtrl.text) ?? 0;
                    item.sellingPrice = double.tryParse(sPriceCtrl.text) ?? 0;
                    item.quantity = int.tryParse(qtyCtrl.text) ?? 0;
                    item.minThreshold = int.tryParse(minCtrl.text) ?? 0;
                    await provider.updateInventoryItem(item);

                    // If quantity increased from edit form, log that increase as purchase expense.
                    final addedQty = item.quantity - oldQty;
                    if (addedQty > 0 && item.purchasePrice > 0) {
                      final exp = ExpenseItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        date: DateTime.now(),
                        category: 'Product Purchases',
                        description:
                            'Stock increase (edit): ${item.name} x $addedQty',
                        amount: addedQty * item.purchasePrice,
                        paymentMethod: 'Cash',
                      );
                      await provider.addExpense(exp);
                    }

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Item updated successfully'),
                      ),
                    );
                  } else {
                    final newItem = InventoryItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameCtrl.text,
                      category: cat,
                      unit: unit,
                      purchasePrice: double.tryParse(pPriceCtrl.text) ?? 0,
                      sellingPrice: double.tryParse(sPriceCtrl.text) ?? 0,
                      quantity: int.tryParse(qtyCtrl.text) ?? 0,
                      minThreshold: int.tryParse(minCtrl.text) ?? 0,
                    );
                    await provider.addInventory(newItem);

                    // Log opening stock as a purchase expense so it appears in Expenses.
                    if (newItem.quantity > 0 && newItem.purchasePrice > 0) {
                      final exp = ExpenseItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        date: DateTime.now(),
                        category: 'Product Purchases',
                        description:
                            'Opening stock: ${newItem.name} x ${newItem.quantity}',
                        amount: newItem.quantity * newItem.purchasePrice,
                        paymentMethod: 'Cash',
                      );
                      await provider.addExpense(exp);
                    }

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('New item added')),
                    );
                  }
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                },
                child: const Text('Save Item'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAdjustStockDialog(InventoryItem item) {
    final currency =
        context.read<AppProvider>().settings['currencySymbol'] ??
            kDefaultCurrencySymbol;
    bool isAdding = true;
    final qtyCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: Text('Adjust Stock: ${item.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Text(
                          'Add (+)',
                          style: TextStyle(
                            color: isAdding ? Colors.green : Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: isAdding,
                        onSelected: (val) => setStateSB(() => isAdding = true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: Text(
                          'Reduce (−)',
                          style: TextStyle(
                            color: !isAdding
                                ? Colors.redAccent
                                : Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: !isAdding,
                        onSelected: (val) => setStateSB(() => isAdding = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setStateSB(() {}),
                  decoration: InputDecoration(
                    labelText: 'Quantity to ${isAdding ? 'Add' : 'Remove'}',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reason / Note (e.g. New Purchase, Wastage)',
                  ),
                ),
                const SizedBox(height: 8),
                if (isAdding)
                  Text(
                    'Note: Auto-logs $currency${((double.tryParse(qtyCtrl.text) ?? 0) * item.purchasePrice).toStringAsFixed(2)} as shop expense',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amount = int.tryParse(qtyCtrl.text);
                  if (amount != null && amount > 0) {
                    final provider = context.read<AppProvider>();
                    if (isAdding) {
                      item.quantity += amount;
                      await provider.updateInventoryItem(item);
                      // Auto-log to Expenses
                      final exp = ExpenseItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        date: DateTime.now(),
                        category: 'Product Purchases',
                        description: 'Stock addition: ${item.name} x $amount',
                        amount: amount * item.purchasePrice,
                        paymentMethod: 'Cash',
                      );
                      await provider.addExpense(exp);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Increased stock & logged $currency${(amount * item.purchasePrice).toStringAsFixed(2)} expense',
                          ),
                        ),
                      );
                    } else {
                      item.quantity -= amount;
                      if (item.quantity < 0) item.quantity = 0;
                      await provider.updateInventoryItem(item);
                    }
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Confirm Adjustment'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        context.watch<AppProvider>().settings['currencySymbol'] ??
            kDefaultCurrencySymbol;
    return Padding(
      padding: AppBreakpoints.pagePadding(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < AppBreakpoints.mobile;
          final summaryGap = narrow ? 12.0 : 24.0;

          final headerTitle = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inventory Management',
                style: TextStyle(
                  fontSize: narrow ? 22 : 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Track supplies, retail products, and asset values',
                style: TextStyle(
                  fontSize: narrow ? 13 : 14,
                  color: Colors.grey[400],
                ),
              ),
            ],
          );

          final headerActions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Refresh inventory',
                onPressed: () async {
                  await context.read<AppProvider>().loadInventory();
                  if (!mounted) return;
                  setState(() {
                    if (!_categoryOptions.contains(_selectedCategory)) {
                      _selectedCategory = 'All';
                    }
                  });
                },
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: () => _showAddEditDialog(),
                icon: const Icon(Icons.add_box),
                label: Text(narrow ? 'Add' : 'Add New Item'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: narrow ? 12 : 20,
                    vertical: narrow ? 12 : 16,
                  ),
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          );

          final summaryRow = narrow
              ? Column(
                  children: [
                    Consumer<AppProvider>(
                      builder: (ctx, _, _) => _SummaryCard(
                        title: 'Total Items',
                        value: context
                            .read<AppProvider>()
                            .inventory
                            .length
                            .toString(),
                        icon: Icons.inventory,
                        color: Colors.blueAccent,
                      ),
                    ),
                    SizedBox(height: summaryGap),
                    _SummaryCard(
                      title: 'Low Stock Alerts',
                      value: _lowStockCount.toString(),
                      icon: Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                    ),
                    SizedBox(height: summaryGap),
                    _SummaryCard(
                      title: 'Stock Valuation',
                      value: '$currency${_totalValuation.toStringAsFixed(2)}',
                      icon: Icons.account_balance_wallet,
                      color: Colors.greenAccent,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Consumer<AppProvider>(
                        builder: (ctx, _, _) => _SummaryCard(
                          title: 'Total Items',
                          value: context
                              .read<AppProvider>()
                              .inventory
                              .length
                              .toString(),
                          icon: Icons.inventory,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                    SizedBox(width: summaryGap),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Low Stock Alerts',
                        value: _lowStockCount.toString(),
                        icon: Icons.warning_amber_rounded,
                        color: Colors.redAccent,
                      ),
                    ),
                    SizedBox(width: summaryGap),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Stock Valuation',
                        value:
                            '$currency${_totalValuation.toStringAsFixed(2)}',
                        icon: Icons.account_balance_wallet,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ],
                );

          final searchField = Container(
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
                hintText: 'Search by item name...',
                border: InputBorder.none,
              ),
            ),
          );

          final categoryFilter = Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategory,
                isExpanded: true,
                dropdownColor: Theme.of(context).cardColor,
                items: _categoryOptions
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) =>
                    setState(() => _selectedCategory = val ?? 'All'),
              ),
            ),
          );

          final filters = narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 12),
                    categoryFilter,
                  ],
                )
              : Row(
                  children: [
                    Expanded(flex: 2, child: searchField),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: categoryFilter),
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (narrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    headerTitle,
                    const SizedBox(height: 12),
                    headerActions,
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: headerTitle),
                    headerActions,
                  ],
                ),
              SizedBox(height: narrow ? 16 : 24),
              summaryRow,
              SizedBox(height: narrow ? 16 : 24),
              filters,
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth > 720
                            ? constraints.maxWidth
                            : 720,
                      ),
                      child: SingleChildScrollView(
                        child: DataTable(
                          columnSpacing: 40,
                        headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        columns: const [
                          DataColumn(label: Text('Item Name')),
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Stock/Unit')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Avg Purchase')),
                          DataColumn(label: Text('Retail Price')),
                          DataColumn(label: Text('Total Value')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _filteredItems.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  item.category,
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${item.quantity} ${item.unit}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: item.isLowStock
                                        ? Colors.red.withValues(alpha: 0.1)
                                        : Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item.isLowStock ? 'LOW STOCK' : 'IN STOCK',
                                    style: TextStyle(
                                      color: item.isLowStock
                                          ? Colors.redAccent
                                          : Colors.greenAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '$currency${item.purchasePrice.toStringAsFixed(2)}',
                                ),
                              ),
                              DataCell(
                                Text(
                                  item.sellingPrice > 0
                                      ? '$currency${item.sellingPrice.toStringAsFixed(2)}'
                                      : 'N/A',
                                  style: TextStyle(
                                    color: item.sellingPrice > 0
                                        ? Colors.blueAccent
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '$currency${item.totalValue.toStringAsFixed(2)}',
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.blueAccent,
                                        size: 20,
                                      ),
                                      tooltip: 'Edit',
                                      onPressed: () => _showAddEditDialog(item),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.sync_alt,
                                        color: Colors.orangeAccent,
                                        size: 20,
                                      ),
                                      tooltip: 'Adjust Stock',
                                      onPressed: () =>
                                          _showAdjustStockDialog(item),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      tooltip: 'Delete',
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (c) => AlertDialog(
                                            title: const Text('Delete Item'),
                                            content: const Text(
                                              'Are you sure you want to delete this inventory item?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(c),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.redAccent,
                                                ),
                                                onPressed: () {
                                                  context
                                                      .read<AppProvider>()
                                                      .deleteInventory(item);
                                                  Navigator.pop(c);
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content:
                                                          Text('Item deleted'),
                                                    ),
                                                  );
                                                },
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
