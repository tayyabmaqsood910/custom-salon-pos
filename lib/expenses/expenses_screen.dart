import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../constants/app_currency.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../utils/responsive_layout.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String _selectedCategory = 'All';
  String _dateRange = 'This Month'; // Filter option

  final List<String> _categories = [
    'Rent',
    'Utilities',
    'Staff Salary',
    'Product Purchase',
    'Equipment / Repair',
    'Cleaning & Supplies',
    'Marketing',
    'Miscellaneous',
  ];

  final List<String> _paymentMethods = [
    'Cash',
    'Credit Card',
    'Bank Transfer',
    'Mobile Wallet',
  ];

  List<ExpenseItem> get _filteredExpenses {
    final list = context.watch<AppProvider>().expenses;
    return list.where((e) {
      final matchCat =
          _selectedCategory == 'All' || e.category == _selectedCategory;
      // Date filter mock for "This Month"
      final isThisMonth =
          e.date.month == DateTime.now().month &&
          e.date.year == DateTime.now().year;
      final matchDate = _dateRange == 'All Time' ? true : isThisMonth;
      return matchCat && matchDate;
    }).toList();
  }

  double get _totalExpenses =>
      _filteredExpenses.fold(0, (sum, e) => sum + e.amount);
  int get _recurringCount =>
      _filteredExpenses.where((e) => e.isRecurring).length;

  String get _topExpenseCategory {
    if (_filteredExpenses.isEmpty) return '—';
    final totals = <String, double>{};
    for (final e in _filteredExpenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }
    var top = _filteredExpenses.first.category;
    var maxAmt = 0.0;
    totals.forEach((cat, sum) {
      if (sum > maxAmt) {
        maxAmt = sum;
        top = cat;
      }
    });
    return top;
  }

  List<BarChartGroupData> _generateChartData() {
    final expenses = context.watch<AppProvider>().expenses;
    final now = DateTime.now();
    List<double> monthlyTotals = List.filled(6, 0.0);

    for (var exp in expenses) {
      int monthDiff =
          (now.year - exp.date.year) * 12 + now.month - exp.date.month;
      if (monthDiff >= 0 && monthDiff < 6) {
        monthlyTotals[5 - monthDiff] += exp.amount;
      }
    }

    return List.generate(6, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: monthlyTotals[index],
            color: Colors.redAccent.withValues(alpha: index == 5 ? 1.0 : 0.5),
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });
  }

  void _showAddEditDialog([ExpenseItem? item]) {
    final currency =
        context.read<AppProvider>().settings['currencySymbol'] ??
            kDefaultCurrencySymbol;
    final isEditing = item != null;
    final descCtrl = TextEditingController(text: item?.description ?? '');
    final amountCtrl = TextEditingController(
      text: item?.amount.toString() ?? '',
    );
    String cat = item?.category ?? _categories[0];
    String payMethod = item?.paymentMethod ?? _paymentMethods[0];
    bool isRecurring = item?.isRecurring ?? false;
    bool hasReceipt = item?.hasReceipt ?? false;
    DateTime selectedDate = item?.date ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: Text(isEditing ? 'Edit Expense' : 'Add New Expense'),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (d != null) setStateSB(() => selectedDate = d);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date',
                              ),
                              child: Text(
                                '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: cat,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                            ),
                            items: _categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setStateSB(() => cat = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: amountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Amount ($currency)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: payMethod,
                            decoration: const InputDecoration(
                              labelText: 'Payment Method',
                            ),
                            items: _paymentMethods
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setStateSB(() => payMethod = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Switch(
                              value: isRecurring,
                              onChanged: (val) =>
                                  setStateSB(() => isRecurring = val),
                              activeThumbColor: Theme.of(context).primaryColor,
                            ),
                            const Text('Recurring monthly?'),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            setStateSB(() => hasReceipt = true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Simulated receipt photo attached.',
                                ),
                              ),
                            );
                          },
                          icon: Icon(
                            hasReceipt ? Icons.check_circle : Icons.camera_alt,
                            color: hasReceipt ? Colors.green : Colors.grey,
                          ),
                          label: Text(
                            hasReceipt ? 'Receipt Attached' : 'Attach Receipt',
                          ),
                        ),
                      ],
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
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    if (isEditing) {
                      item.date = selectedDate;
                      item.category = cat;
                      item.description = descCtrl.text;
                      item.amount = double.tryParse(amountCtrl.text) ?? 0;
                      item.paymentMethod = payMethod;
                      item.isRecurring = isRecurring;
                      item.hasReceipt = hasReceipt;
                      context.read<AppProvider>().updateExpense();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Expense updated successfully!'),
                        ),
                      );
                    } else {
                      final newExp = ExpenseItem(
                        id: DateTime.now().toString(),
                        date: selectedDate,
                        category: cat,
                        description: descCtrl.text,
                        amount: double.tryParse(amountCtrl.text) ?? 0,
                        paymentMethod: payMethod,
                        isRecurring: isRecurring,
                        hasReceipt: hasReceipt,
                      );
                      context.read<AppProvider>().addExpense(newExp);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('New expense logged!')),
                      );
                    }
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Save Expense'),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < AppBreakpoints.mobile;
        final pad = AppBreakpoints.pagePadding(context);

        final metricsColumn = Column(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Total Expenses ($_dateRange)',
                value: '$currency${_totalExpenses.toStringAsFixed(2)}',
                icon: Icons.money_off,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: 'Recurring Setup',
                      value: '$_recurringCount Active',
                      icon: Icons.autorenew,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      title: 'Top Expense Category',
                      value: _topExpenseCategory,
                      icon: Icons.business,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final chartPanel = Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Expense Trend (Past 6 Months)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceEvenly,
                    maxY: 4000,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            const style = TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            );
                            final now = DateTime.now();
                            final months = [
                              'Jan',
                              'Feb',
                              'Mar',
                              'Apr',
                              'May',
                              'Jun',
                              'Jul',
                              'Aug',
                              'Sep',
                              'Oct',
                              'Nov',
                              'Dec',
                            ];

                            int monthIndex =
                                now.month - 1 - (5 - value.toInt());
                            if (monthIndex < 0) monthIndex += 12;

                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                months[monthIndex],
                                style: style,
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: _generateChartData(),
                  ),
                ),
              ),
            ],
          ),
        );

        return Padding(
          padding: pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (narrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Expense Management',
                      style: TextStyle(
                        fontSize: narrow ? 22 : 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track outgoing business costs and asset purchases',
                      style: TextStyle(
                        fontSize: narrow ? 13 : 14,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddEditDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Log Expense'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          backgroundColor: Theme.of(context).colorScheme.error,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Expense Management',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Track outgoing business costs and asset purchases',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Log Expense'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              if (narrow) ...[
                SizedBox(height: 220, child: metricsColumn),
                const SizedBox(height: 16),
                SizedBox(height: 240, child: chartPanel),
              ] else
                SizedBox(
                  height: 268,
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: metricsColumn),
                      const SizedBox(width: 24),
                      Expanded(flex: 3, child: chartPanel),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // FILTERS
              narrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _dateRange,
                              isExpanded: true,
                              dropdownColor: Theme.of(context).cardColor,
                              items: ['This Month', 'All Time']
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text('Date Range: $c'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _dateRange = val!),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
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
                              items: ['All', ..._categories]
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text('Category: $c'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedCategory = val!),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _dateRange,
                                isExpanded: true,
                                dropdownColor: Theme.of(context).cardColor,
                                items: ['This Month', 'All Time']
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text('Date Range: $c'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _dateRange = val!),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
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
                                items: ['All', ..._categories]
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text('Category: $c'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedCategory = val!),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 16),

              // DATA TABLE
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
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 1240),
                        child: MediaQuery(
                          // Keep table labels readable even when global UI scale is large.
                          data: MediaQuery.of(context).copyWith(
                            textScaler: const TextScaler.linear(0.95),
                          ),
                          child: DataTable(
                            columnSpacing: 22,
                            headingRowHeight: 60,
                            dataRowMinHeight: 56,
                            dataRowMaxHeight: 72,
                            headingTextStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            columns: const [
                              DataColumn(label: SizedBox(width: 86, child: Text('Date'))),
                              DataColumn(label: SizedBox(width: 120, child: Text('Category'))),
                              DataColumn(label: SizedBox(width: 210, child: Text('Description'))),
                              DataColumn(label: SizedBox(width: 104, child: Text('Amount'))),
                              DataColumn(label: SizedBox(width: 96, child: Text('Payment'))),
                              DataColumn(label: SizedBox(width: 108, child: Text('Recurring?'))),
                              DataColumn(label: SizedBox(width: 86, child: Text('Receipt'))),
                              DataColumn(label: SizedBox(width: 92, child: Text('Actions'))),
                            ],
                          rows: _filteredExpenses.map((exp) {
                            return DataRow(
                              cells: [
                          DataCell(
                            Text(
                              '${exp.date.day}/${exp.date.month}/${exp.date.year}',
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                exp.category,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              exp.description,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '$currency${exp.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                          DataCell(Text(exp.paymentMethod)),
                          DataCell(
                            Icon(
                              exp.isRecurring ? Icons.repeat : Icons.remove,
                              color: exp.isRecurring
                                  ? Colors.amber
                                  : Colors.grey,
                              size: 20,
                            ),
                          ),
                          DataCell(
                            Icon(
                              exp.hasReceipt
                                  ? Icons.receipt
                                  : Icons.cancel_outlined,
                              color: exp.hasReceipt
                                  ? Colors.green
                                  : Colors.grey,
                              size: 20,
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 84,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 34,
                                      minHeight: 34,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blueAccent,
                                      size: 18,
                                    ),
                                    onPressed: () => _showAddEditDialog(exp),
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 34,
                                      minHeight: 34,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: const Text('Delete Expense'),
                                          content: const Text(
                                            'Are you sure you want to delete this expense?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(c),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.redAccent,
                                              ),
                                              onPressed: () {
                                                context
                                                    .read<AppProvider>()
                                                    .deleteExpense(exp);
                                                Navigator.pop(c);
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Expense deleted',
                                                    ),
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
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
