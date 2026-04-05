import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../utils/responsive_layout.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback? onNewSale;
  final VoidCallback? onAddCustomer;
  final VoidCallback? onAddExpense;

  const DashboardScreen({
    super.key,
    this.onNewSale,
    this.onAddCustomer,
    this.onAddExpense,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final now = DateTime.now();
    double todayRevenue = 0;
    int todayTransactions = 0;
    Set<String> todayCustomers = {};

    for (var t in provider.transactions) {
      if (t.date.year == now.year &&
          t.date.month == now.month &&
          t.date.day == now.day) {
        todayRevenue += t.total;
        todayTransactions++;
        if (t.customerId != 'Walk-in') {
          todayCustomers.add(t.customerId);
        }
      }
    }

    double totalRevenue = provider.transactions.fold(
      0.0,
      (sum, t) => sum + t.total,
    );
    double totalExpense = provider.expenses.fold(
      0.0,
      (sum, e) => sum + e.amount,
    );
    double netProfit = totalRevenue - totalExpense;
    bool isNetPositive = netProfit >= 0;
    final currency = provider.settings['currencySymbol'] ?? '\$';

    return Padding(
      padding: AppBreakpoints.pagePadding(context),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            // SUMMARY CARDS
            LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxWidth < 800;
                final isTiny = constraints.maxWidth < 520;
                final tiles = <Widget>[
                  _SummaryCard(
                    title: "Today's Revenue",
                    value: '$currency${todayRevenue.toStringAsFixed(2)}',
                    icon: Icons.attach_money,
                    iconColor: AppColors.oliveDark,
                    trend: 'Daily Metrics',
                    positive: true,
                    onTap: () =>
                        _showTodayTransactions(context, provider, currency),
                  ),
                  _SummaryCard(
                    title: 'Transactions',
                    value: '$todayTransactions',
                    icon: Icons.receipt_long,
                    iconColor: AppColors.sage,
                    trend: 'Daily Metrics',
                    positive: true,
                  ),
                  _SummaryCard(
                    title: 'Customers Served',
                    value: '${todayCustomers.length}',
                    icon: Icons.people,
                    iconColor: AppColors.chartAccent,
                    trend: 'Unique Profiles',
                    positive: true,
                  ),
                  _SummaryCard(
                    title: 'Net Value',
                    value:
                        '${isNetPositive ? '+' : ''}$currency${netProfit.toStringAsFixed(2)}',
                    icon: Icons.account_balance_wallet,
                    iconColor: isNetPositive
                        ? AppColors.sage
                        : AppColors.trendDown,
                    trend: 'All-Time Profit',
                    positive: isNetPositive,
                  ),
                ];

                if (isTiny) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < tiles.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        tiles[i],
                      ],
                    ],
                  );
                }

                if (isSmall) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: tiles[0]),
                          const SizedBox(width: 16),
                          Expanded(child: tiles[1]),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: tiles[2]),
                          const SizedBox(width: 16),
                          Expanded(child: tiles[3]),
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: tiles[0]),
                    const SizedBox(width: 16),
                    Expanded(child: tiles[1]),
                    const SizedBox(width: 16),
                    Expanded(child: tiles[2]),
                    const SizedBox(width: 16),
                    Expanded(child: tiles[3]),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            // MAIN CONTENT AREA
            LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxWidth < 1000;

                if (isSmall) {
                  return Column(
                    children: [
                      _buildRevenueChart(context, provider),
                      const SizedBox(height: 24),
                      _buildLiveQueue(provider),
                    ],
                  );
                }

                return SizedBox(
                  height: 400,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildRevenueChart(context, provider),
                      ),
                      const SizedBox(width: 24),
                      Expanded(flex: 1, child: _buildLiveQueue(provider)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            _buildRecentTransactions(),
            const SizedBox(height: 24),
            _buildExpenseSummary(
              context,
              totalRevenue,
              totalExpense,
              isNetPositive,
              currency,
              netProfit,
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, c) {
                if (c.maxWidth < 880) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopServices(provider, currency),
                      const SizedBox(height: 16),
                      _buildTopStaff(provider, currency),
                      const SizedBox(height: 16),
                      _buildLowStockAlerts(provider),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildTopServices(provider, currency)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildTopStaff(provider, currency)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildLowStockAlerts(provider)),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 640;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard Overview',
              style: TextStyle(
                fontSize: narrow ? 22 : 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Welcome back! Here\'s what\'s happening today.',
              style: TextStyle(
                fontSize: narrow ? 13 : 14,
                color: AppColors.moss,
              ),
            ),
          ],
        );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.start,
          children: [
            _buildQuickActionBtn(
              context,
              icon: Icons.add_circle,
              label: 'New Sale',
              primary: true,
              onTap: onNewSale,
            ),
            _buildQuickActionBtn(
              context,
              icon: Icons.person_add,
              label: 'Add Customer',
              onTap: onAddCustomer,
            ),
            _buildQuickActionBtn(
              context,
              icon: Icons.money_off,
              label: 'Add Expense',
              onTap: onAddExpense,
            ),
          ],
        );
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 16),
              actions,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: title),
            const SizedBox(width: 12),
            actions,
          ],
        );
      },
    );
  }

  Widget _buildQuickActionBtn(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool primary = false,
    VoidCallback? onTap,
  }) {
    final color = primary
        ? Theme.of(context).colorScheme.primary
        : Colors.white;
    final textColor =
        primary ? Theme.of(context).colorScheme.onPrimary : AppColors.oliveDark;

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: primary
                ? null
                : Border.all(color: AppColors.stoneOlive.withValues(alpha: 0.85)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueChart(BuildContext context, AppProvider provider) {
    double w1 = 0, w2 = 0, w3 = 0, w4 = 0;
    final now = DateTime.now();
    for (var t in provider.transactions) {
      if (t.date.year == now.year && t.date.month == now.month) {
        if (t.date.day <= 7) {
          w1 += t.total;
        } else if (t.date.day <= 14)
          w2 += t.total;
        else if (t.date.day <= 21)
          w3 += t.total;
        else
          w4 += t.total;
      }
    }
    double maxY = [w1, w2, w3, w4].reduce((a, b) => a > b ? a : b);
    if (maxY == 0) maxY = 1000;
    maxY = maxY + (maxY * 0.2); // add 20% headroom

    return _DashboardCard(
      title: 'Revenue Trend (Current Month)',
      child: SizedBox(
        height: 250,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final style = TextStyle(
                      color: AppColors.moss,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    );
                    Widget text;
                    switch (value.toInt()) {
                      case 0:
                        text = Text('W1', style: style);
                        break;
                      case 1:
                        text = Text('W2', style: style);
                        break;
                      case 2:
                        text = Text('W3', style: style);
                        break;
                      case 3:
                        text = Text('W4', style: style);
                        break;
                      default:
                        text = Text('', style: style);
                        break;
                    }
                    return SideTitleWidget(meta: meta, child: text);
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      '${value.toInt()}',
                      style: const TextStyle(
                        color: AppColors.moss,
                        fontSize: 10,
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(
                  color: AppColors.stoneOlive.withValues(alpha: 0.9),
                  strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barGroups: [
              BarChartGroupData(
                x: 0,
                barRods: [
                  BarChartRodData(
                    toY: w1,
                    color: AppColors.sage,
                    width: 22,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
              BarChartGroupData(
                x: 1,
                barRods: [
                  BarChartRodData(
                    toY: w2,
                    color: AppColors.sage,
                    width: 22,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
              BarChartGroupData(
                x: 2,
                barRods: [
                  BarChartRodData(
                    toY: w3,
                    color: AppColors.chartAccent,
                    width: 22,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
              BarChartGroupData(
                x: 3,
                barRods: [
                  BarChartRodData(
                    toY: w4,
                    color: AppColors.sage,
                    width: 22,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveQueue(AppProvider provider) {
    final bills = provider.parkedBills.take(5).toList();
    return _DashboardCard(
      title: 'Pending Held Bills',
      actionWidget: const Icon(
        Icons.timer_outlined,
        size: 18,
        color: AppColors.moss,
      ),
      child: Column(
        children: bills.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No holding bills'),
                ),
              ]
            : bills.map((b) {
                String name = 'Walk-in';
                if (b.customerId != 'Walk-in' && b.customerId.isNotEmpty) {
                  final idx = provider.customers.indexWhere(
                    (c) => c.id == b.customerId,
                  );
                  if (idx != -1) name = provider.customers[idx].name;
                }
                return _QueueItem(
                  name: name,
                  service: b.reference,
                  time:
                      '${b.time.hour}:${b.time.minute.toString().padLeft(2, '0')}',
                  status: 'Hold',
                );
              }).toList(),
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Consumer<AppProvider>(
      builder: (ctx, provider, _) {
        final txs = provider.transactions.reversed.take(5).toList();
        return _DashboardCard(
          title: 'Recent Transactions',
          child: Column(
            children: txs.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No transactions yet'),
                    ),
                  ]
                : [
                    for (int i = 0; i < txs.length; i++) ...[
                      _TransactionRow(
                        id: '#TRX-${txs[i].id.length > 4 ? txs[i].id.substring(txs[i].id.length - 4) : txs[i].id}',
                        service: txs[i].items.isNotEmpty
                            ? txs[i].items.first.service.name
                            : 'Unknown',
                        staff: txs[i].items.isNotEmpty
                            ? txs[i].items.first.assignedStaff
                            : 'Unknown',
                        amount: '\$${txs[i].total.toStringAsFixed(2)}',
                        time:
                            '${txs[i].date.hour}:${txs[i].date.minute.toString().padLeft(2, '0')}',
                      ),
                      if (i < txs.length - 1)
                        Divider(color: AppColors.sand.withValues(alpha: 0.9)),
                    ],
                  ],
          ),
        );
      },
    );
  }

  Widget _buildTopServices(AppProvider provider, String currency) {
    Map<String, int> counts = {};
    for (var t in provider.transactions) {
      for (var item in t.items) {
        counts[item.service.name] = (counts[item.service.name] ?? 0) + 1;
      }
    }
    var sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var top3 = sorted.take(3).toList();

    return _DashboardCard(
      title: 'Top Services All-Time',
      child: Column(
        children: top3.isEmpty
            ? [
                const Text('No data', style: TextStyle(color: AppColors.moss)),
              ]
            : top3
                  .map((e) => _TopItem(title: e.key, count: '${e.value} Sold'))
                  .toList(),
      ),
    );
  }

  Widget _buildTopStaff(AppProvider provider, String currency) {
    Map<String, double> revenue = {};
    Map<String, int> cuts = {};
    for (var t in provider.transactions) {
      for (var item in t.items) {
        revenue[item.assignedStaff] =
            (revenue[item.assignedStaff] ?? 0.0) + item.finalPrice;
        cuts[item.assignedStaff] = (cuts[item.assignedStaff] ?? 0) + 1;
      }
    }
    var sorted = revenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var top3 = sorted.take(3).toList();

    return _DashboardCard(
      title: 'Top Staff Performance',
      child: Column(
        children: top3.isEmpty
            ? [
                const Text('No data', style: TextStyle(color: AppColors.moss)),
              ]
            : top3
                  .map(
                    (e) => _TopItem(
                      title: e.key,
                      count:
                          '$currency${e.value.toStringAsFixed(2)} (${cuts[e.key]} done)',
                    ),
                  )
                  .toList(),
      ),
    );
  }

  Widget _buildLowStockAlerts(AppProvider provider) {
    final lowStock = provider.inventory
        .where((i) => i.isLowStock)
        .take(3)
        .toList();
    return _DashboardCard(
      title: 'Low Stock Alerts',
      child: Column(
        children: lowStock.isEmpty
            ? [
                const Text(
                  'All stock levels are good!',
                  style: TextStyle(color: AppColors.trendUp),
                ),
              ]
            : lowStock
                  .map(
                    (i) => _StockAlert(
                      item: i.name,
                      remaining: i.quantity.toInt(),
                    ),
                  )
                  .toList(),
      ),
    );
  }

  Widget _buildExpenseSummary(
    BuildContext context,
    double totalRevenue,
    double totalExpense,
    bool isNetPositive,
    String currency,
    double netProfit,
  ) {
    return _DashboardCard(
      title: 'Expense vs Revenue (All-Time)',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Revenue', style: TextStyle(color: AppColors.moss)),
              Text(
                '$currency${totalRevenue.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Expenses', style: TextStyle(color: AppColors.moss)),
              Text(
                '$currency${totalExpense.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.stoneOlive.withValues(alpha: 0.9)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Net Profit',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.sand,
                ),
              ),
              Text(
                '${isNetPositive ? '+' : ''}$currency${netProfit.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isNetPositive
                      ? Theme.of(context).colorScheme.secondary
                      : AppColors.trendDown,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTodayTransactions(
    BuildContext context,
    AppProvider provider,
    String currency,
  ) {
    final now = DateTime.now();
    final todayTxs = provider.transactions
        .where(
          (t) =>
              t.date.year == now.year &&
              t.date.month == now.month &&
              t.date.day == now.day,
        )
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Today's Transactions"),
        content: SizedBox(
          width: 500,
          child: todayTxs.isEmpty
              ? const Text('No transactions today.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: todayTxs.length,
                  separatorBuilder: (ctx, i) =>
                      Divider(color: AppColors.sand.withValues(alpha: 0.9)),
                  itemBuilder: (ctx, i) {
                    final t = todayTxs[i];
                    final itemsSummary = t.items
                        .map((e) => e.service.name)
                        .join(', ');
                    final timeStr =
                        '${t.date.hour}:${t.date.minute.toString().padLeft(2, '0')}';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        itemsSummary.isNotEmpty ? itemsSummary : 'Custom Sale',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('ID: ${t.id}\nTime: $timeStr'),
                      trailing: Text(
                        '$currency${t.total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
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
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String trend;
  final bool positive;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.trend,
    required this.positive,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.oliveDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.stoneOlive.withValues(alpha: 0.95),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 18,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.moss,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: AppColors.sand,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          positive ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 14,
                          color: positive
                              ? AppColors.trendUp
                              : AppColors.trendDown,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$trend from yesterday',
                            style: TextStyle(
                              color: positive
                                  ? AppColors.trendUp
                                  : AppColors.trendDown,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ], // End of outer Row children
          ), // outer Row
        ), // Container
      ), // InkWell
    ); // Material
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? actionWidget;

  const _DashboardCard({
    required this.title,
    required this.child,
    this.actionWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.oliveDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.stoneOlive.withValues(alpha: 0.95),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
            spreadRadius: -3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.sand,
                ),
              ),
              actionWidget ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _QueueItem extends StatelessWidget {
  final String name;
  final String service;
  final String time;
  final String status;

  const _QueueItem({
    required this.name,
    required this.service,
    required this.time,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final bool inProgress = status == 'In Progress';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: inProgress
            ? AppColors.sage.withValues(alpha: 0.12)
            : AppColors.stoneOlive.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: inProgress
              ? AppColors.sage.withValues(alpha: 0.45)
              : AppColors.stoneOlive.withValues(alpha: 0.9),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.sage,
                child: Text(
                  name[0],
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    service,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.moss,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: inProgress
                      ? AppColors.oliveDark
                      : AppColors.stoneOlive,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.ivory,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final String id;
  final String service;
  final String staff;
  final String amount;
  final String time;

  const _TransactionRow({
    required this.id,
    required this.service,
    required this.staff,
    required this.amount,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.sage.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              size: 16,
              color: AppColors.sand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.sand,
                  ),
                ),
                Text(
                  '$id • By $staff',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.moss,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.sand,
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.moss,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopItem extends StatelessWidget {
  final String title;
  final String count;

  const _TopItem({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.sand,
            ),
          ),
          Text(
            count,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.sand,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockAlert extends StatelessWidget {
  final String item;
  final int remaining;

  const _StockAlert({required this.item, required this.remaining});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(item, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$remaining Left',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
