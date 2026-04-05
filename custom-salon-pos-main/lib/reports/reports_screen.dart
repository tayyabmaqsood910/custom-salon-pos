import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../constants/app_currency.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';

enum _ReportPeriod { thisMonth, last7Days, last30Days, allTime }

extension on _ReportPeriod {
  String get label => switch (this) {
        _ReportPeriod.thisMonth => 'This month',
        _ReportPeriod.last7Days => 'Last 7 days',
        _ReportPeriod.last30Days => 'Last 30 days',
        _ReportPeriod.allTime => 'All time',
      };
}

/// Business reports from **local SQLite only** — no network; works fully offline.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _ReportPeriod _period = _ReportPeriod.thisMonth;

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _inPeriod(DateTime d, _ReportPeriod p) {
    final dn = _dayOnly(d);
    final now = DateTime.now();
    final today = _dayOnly(now);
    switch (p) {
      case _ReportPeriod.thisMonth:
        return dn.year == now.year && dn.month == now.month;
      case _ReportPeriod.last7Days:
        final from = today.subtract(const Duration(days: 6));
        return !dn.isBefore(from) && !dn.isAfter(today);
      case _ReportPeriod.last30Days:
        final from = today.subtract(const Duration(days: 29));
        return !dn.isBefore(from) && !dn.isAfter(today);
      case _ReportPeriod.allTime:
        return true;
    }
  }

  List<TransactionRecord> _tx(AppProvider p) =>
      p.transactions.where((t) => _inPeriod(t.date, _period)).toList();

  List<ExpenseItem> _exp(AppProvider p) =>
      p.expenses.where((e) => _inPeriod(e.date, _period)).toList();

  List<String> _serviceNames(TransactionRecord t) {
    if (t.items.isNotEmpty) {
      return t.items.map((e) => e.service.name).toList();
    }
    final raw = t.servicesSummary.trim();
    if (raw.isEmpty) return const ['Other'];
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  void _addServiceRevenue(Map<String, double> acc, TransactionRecord t) {
    final names = _serviceNames(t);
    if (names.isEmpty) return;
    final share = t.total / names.length;
    for (final n in names) {
      acc[n] = (acc[n] ?? 0) + share;
    }
  }

  Future<void> _refresh(AppProvider p) async {
    await p.loadTransactions();
    await p.loadExpenses();
  }

  String _csv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<void> _exportReportsCsv({
    required String currency,
    required List<TransactionRecord> txs,
    required List<ExpenseItem> exps,
    required Map<String, double> paymentTotals,
    required List<MapEntry<String, double>> topServices,
    required List<MapEntry<String, double>> topExpenseCats,
    required double salesTotal,
    required double tipsTotal,
    required double discountsTotal,
    required double expenseTotal,
    required double net,
    required String exportLabel,
    required String fileSlug,
  }) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV export is supported on desktop/mobile app.'),
        ),
      );
      return;
    }

    final rows = <List<String>>[];
    rows.add(['Simple Report Export']);
    rows.add(['Period', exportLabel]);
    rows.add(['Generated At', DateTime.now().toIso8601String()]);
    rows.add([]);
    rows.add(['Summary']);
    rows.add(['Metric', 'Value']);
    rows.add(['Gross Sales', salesTotal.toStringAsFixed(2)]);
    rows.add(['Tips', tipsTotal.toStringAsFixed(2)]);
    rows.add(['Discounts', discountsTotal.toStringAsFixed(2)]);
    rows.add(['Expenses', expenseTotal.toStringAsFixed(2)]);
    rows.add(['Net', net.toStringAsFixed(2)]);
    rows.add(['Currency', currency]);
    rows.add([]);

    rows.add(['Payment Summary']);
    rows.add(['Payment Method', 'Total']);
    final payEntries = paymentTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in payEntries) {
      rows.add([e.key, e.value.toStringAsFixed(2)]);
    }
    rows.add([]);

    rows.add(['Sales Details']);
    rows.add([
      'Date',
      'Customer',
      'Staff',
      'Payment Method',
      'Subtotal',
      'Discount',
      'Tip',
      'Total',
      'Services',
    ]);
    final recent = List<TransactionRecord>.from(txs)
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final t in recent) {
      rows.add([
        _formatDate(t.date),
        t.customerName.isNotEmpty ? t.customerName : 'Walk-in',
        t.staffName.isNotEmpty ? t.staffName : '-',
        t.paymentMethod,
        t.subtotal.toStringAsFixed(2),
        t.discount.toStringAsFixed(2),
        t.tip.toStringAsFixed(2),
        t.total.toStringAsFixed(2),
        t.servicesSummary,
      ]);
    }

    final csvBody = rows
        .map((r) => r.map((c) => _csv(c)).join(','))
        .join('\r\n');
    final csvContent = '\uFEFF$csvBody';

    try {
      Directory? dir = await getDownloadsDirectory();
      if ((dir == null || !dir.existsSync()) && !kIsWeb && Platform.isWindows) {
        final profile = Platform.environment['USERPROFILE'];
        if (profile != null && profile.isNotEmpty) {
          final winDownloads = Directory(
            '$profile${Platform.pathSeparator}Downloads',
          );
          if (winDownloads.existsSync()) {
            dir = winDownloads;
          }
        }
      }
      dir ??= await getApplicationDocumentsDirectory();

      final file = File(
        '${dir.path}${Platform.pathSeparator}SPS_Reports_${fileSlug}_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(csvContent);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report exported successfully: ${file.path}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickDateRangeAndExport({
    required AppProvider provider,
    required String currency,
  }) async {
    DateTime start = DateTime(DateTime.now().year, DateTime.now().month, 1);
    DateTime end = DateTime.now();

    Future<DateTime?> pickOne(DateTime initial) {
      return showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020, 1, 1),
        lastDate: DateTime(DateTime.now().year + 2, 12, 31),
      );
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) => AlertDialog(
          title: const Text('Select export date range'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('From'),
                  subtitle: Text(_formatDate(start)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await pickOne(start);
                    if (d != null) {
                      setStateSB(() {
                        start = _dayOnly(d);
                        if (end.isBefore(start)) end = start;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('To'),
                  subtitle: Text(_formatDate(end)),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final d = await pickOne(end);
                    if (d != null) {
                      setStateSB(() {
                        end = _dayOnly(d);
                        if (end.isBefore(start)) start = end;
                      });
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
            ElevatedButton.icon(
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Export CSV'),
              onPressed: () async {
                await _refresh(provider);
                final fresh = context.read<AppProvider>();
                bool inRange(DateTime d) {
                  final dn = _dayOnly(d);
                  return !dn.isBefore(start) && !dn.isAfter(end);
                }

                final txs = fresh.transactions.where((t) => inRange(t.date)).toList();
                final exps = fresh.expenses.where((e) => inRange(e.date)).toList();

                final salesTotal = txs.fold<double>(0, (s, t) => s + t.total);
                final tipsTotal = txs.fold<double>(0, (s, t) => s + t.tip);
                final discountsTotal = txs.fold<double>(0, (s, t) => s + t.discount);
                final expenseTotal = exps.fold<double>(0, (s, e) => s + e.amount);
                final net = salesTotal - expenseTotal;

                final paymentTotals = <String, double>{};
                for (final t in txs) {
                  final key = t.paymentMethod.isEmpty ? 'Cash' : t.paymentMethod;
                  paymentTotals[key] = (paymentTotals[key] ?? 0) + t.total;
                }

                final serviceRevenue = <String, double>{};
                for (final t in txs) {
                  _addServiceRevenue(serviceRevenue, t);
                }
                final topServices = serviceRevenue.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                final expenseByCat = <String, double>{};
                for (final e in exps) {
                  final c = e.category.isEmpty ? 'Other' : e.category;
                  expenseByCat[c] = (expenseByCat[c] ?? 0) + e.amount;
                }
                final topExpenseCats = expenseByCat.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                final label = '${_formatDate(start)} to ${_formatDate(end)}';
                final fileSlug = '${_formatDate(start)}_to_${_formatDate(end)}'
                    .replaceAll('-', '_');

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                await _exportReportsCsv(
                  currency: currency,
                  txs: txs,
                  exps: exps,
                  paymentTotals: paymentTotals,
                  topServices: topServices,
                  topExpenseCats: topExpenseCats,
                  salesTotal: salesTotal,
                  tipsTotal: tipsTotal,
                  discountsTotal: discountsTotal,
                  expenseTotal: expenseTotal,
                  net: net,
                  exportLabel: label,
                  fileSlug: fileSlug,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currency =
        provider.settings['currencySymbol'] ?? kDefaultCurrencySymbol;
    final txs = _tx(provider);
    final exps = _exp(provider);

    final salesTotal = txs.fold<double>(0, (s, t) => s + t.total);
    final tipsTotal = txs.fold<double>(0, (s, t) => s + t.tip);
    final discountsTotal = txs.fold<double>(0, (s, t) => s + t.discount);
    final expenseTotal = exps.fold<double>(0, (s, e) => s + e.amount);
    final net = salesTotal - expenseTotal;

    final paymentTotals = <String, double>{};
    for (final t in txs) {
      final key = t.paymentMethod.isEmpty ? 'Cash' : t.paymentMethod;
      paymentTotals[key] = (paymentTotals[key] ?? 0) + t.total;
    }

    final serviceRevenue = <String, double>{};
    for (final t in txs) {
      _addServiceRevenue(serviceRevenue, t);
    }
    final topServices = serviceRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final expenseByCat = <String, double>{};
    for (final e in exps) {
      final c = e.category.isEmpty ? 'Other' : e.category;
      expenseByCat[c] = (expenseByCat[c] ?? 0) + e.amount;
    }
    final topExpenseCats = expenseByCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final recent = List<TransactionRecord>.from(txs)
      ..sort((a, b) => b.date.compareTo(a.date));

    return LayoutBuilder(
      builder: (context, viewport) {
        final isPhone = viewport.maxWidth < 700;
        final isTablet = viewport.maxWidth >= 700 && viewport.maxWidth < 1100;
        final pagePadding = isPhone ? 12.0 : (isTablet ? 16.0 : 24.0);

        return Padding(
          padding: EdgeInsets.all(pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPhone) ...[
                const Text(
                  'Reports & analytics',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sales, expenses, and payment mix from your local database.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                ),
                const SizedBox(height: 8),
                _OfflineChip(),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _refresh(context.read<AppProvider>()),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _refresh(context.read<AppProvider>());
                        final fresh = context.read<AppProvider>();
                        final txsNow = _tx(fresh);
                        final expsNow = _exp(fresh);

                        final salesTotalNow = txsNow.fold<double>(
                          0,
                          (s, t) => s + t.total,
                        );
                        final tipsTotalNow = txsNow.fold<double>(
                          0,
                          (s, t) => s + t.tip,
                        );
                        final discountsTotalNow = txsNow.fold<double>(
                          0,
                          (s, t) => s + t.discount,
                        );
                        final expenseTotalNow = expsNow.fold<double>(
                          0,
                          (s, e) => s + e.amount,
                        );
                        final netNow = salesTotalNow - expenseTotalNow;

                        final paymentTotalsNow = <String, double>{};
                        for (final t in txsNow) {
                          final key = t.paymentMethod.isEmpty
                              ? 'Cash'
                              : t.paymentMethod;
                          paymentTotalsNow[key] =
                              (paymentTotalsNow[key] ?? 0) + t.total;
                        }

                        final serviceRevenueNow = <String, double>{};
                        for (final t in txsNow) {
                          _addServiceRevenue(serviceRevenueNow, t);
                        }
                        final topServicesNow = serviceRevenueNow.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value));

                        final expenseByCatNow = <String, double>{};
                        for (final e in expsNow) {
                          final c = e.category.isEmpty ? 'Other' : e.category;
                          expenseByCatNow[c] = (expenseByCatNow[c] ?? 0) + e.amount;
                        }
                        final topExpenseCatsNow = expenseByCatNow.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value));

                        await _exportReportsCsv(
                          currency: currency,
                          txs: txsNow,
                          exps: expsNow,
                          paymentTotals: paymentTotalsNow,
                          topServices: topServicesNow,
                          topExpenseCats: topExpenseCatsNow,
                          salesTotal: salesTotalNow,
                          tipsTotal: tipsTotalNow,
                          discountsTotal: discountsTotalNow,
                          expenseTotal: expenseTotalNow,
                          net: netNow,
                          exportLabel: _period.label,
                          fileSlug: _period.label.toLowerCase().replaceAll(' ', '_'),
                        );
                      },
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Export'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickDateRangeAndExport(
                        provider: context.read<AppProvider>(),
                        currency: currency,
                      ),
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: const Text('Date Range'),
                    ),
                  ],
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reports & analytics',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sales, expenses, and payment mix from your local database.',
                            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                          ),
                          const SizedBox(height: 10),
                          _OfflineChip(),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Reload from local database',
                      onPressed: () => _refresh(context.read<AppProvider>()),
                      icon: const Icon(Icons.refresh),
                    ),
                    IconButton(
                      tooltip: 'Export report CSV',
                      onPressed: () async {
                        await _refresh(context.read<AppProvider>());
                        final fresh = context.read<AppProvider>();
                        final txsNow = _tx(fresh);
                        final expsNow = _exp(fresh);

                        final salesTotalNow = txsNow.fold<double>(
                          0,
                          (s, t) => s + t.total,
                        );
                        final tipsTotalNow = txsNow.fold<double>(
                          0,
                          (s, t) => s + t.tip,
                        );
                        final discountsTotalNow = txsNow.fold<double>(
                          0,
                          (s, t) => s + t.discount,
                        );
                        final expenseTotalNow = expsNow.fold<double>(
                          0,
                          (s, e) => s + e.amount,
                        );
                        final netNow = salesTotalNow - expenseTotalNow;

                        final paymentTotalsNow = <String, double>{};
                        for (final t in txsNow) {
                          final key = t.paymentMethod.isEmpty
                              ? 'Cash'
                              : t.paymentMethod;
                          paymentTotalsNow[key] =
                              (paymentTotalsNow[key] ?? 0) + t.total;
                        }

                        final serviceRevenueNow = <String, double>{};
                        for (final t in txsNow) {
                          _addServiceRevenue(serviceRevenueNow, t);
                        }
                        final topServicesNow = serviceRevenueNow.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value));

                        final expenseByCatNow = <String, double>{};
                        for (final e in expsNow) {
                          final c = e.category.isEmpty ? 'Other' : e.category;
                          expenseByCatNow[c] = (expenseByCatNow[c] ?? 0) + e.amount;
                        }
                        final topExpenseCatsNow = expenseByCatNow.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value));

                        await _exportReportsCsv(
                          currency: currency,
                          txs: txsNow,
                          exps: expsNow,
                          paymentTotals: paymentTotalsNow,
                          topServices: topServicesNow,
                          topExpenseCats: topExpenseCatsNow,
                          salesTotal: salesTotalNow,
                          tipsTotal: tipsTotalNow,
                          discountsTotal: discountsTotalNow,
                          expenseTotal: expenseTotalNow,
                          net: netNow,
                          exportLabel: _period.label,
                          fileSlug: _period.label.toLowerCase().replaceAll(' ', '_'),
                        );
                      },
                      icon: const Icon(Icons.download),
                    ),
                    IconButton(
                      tooltip: 'Export with custom date range',
                      onPressed: () => _pickDateRangeAndExport(
                        provider: context.read<AppProvider>(),
                        currency: currency,
                      ),
                      icon: const Icon(Icons.calendar_month),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _ReportPeriod.values.map((p) {
                    final selected = _period == p;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(p.label),
                        selected: selected,
                        onSelected: (_) => setState(() => _period = p),
                        selectedColor: AppColors.sage.withValues(alpha: 0.35),
                        checkmarkColor: AppColors.sage,
                        side: BorderSide(
                          color: selected ? AppColors.sage : Colors.white24,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth > 1000;
                      final cardWidth = wide
                          ? (c.maxWidth - 36) / 4
                          : (isPhone ? c.maxWidth : (c.maxWidth - 12) / 2);
                      return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _StatCard(
                            title: 'Gross sales',
                            value: '$currency${salesTotal.toStringAsFixed(2)}',
                            subtitle: '${txs.length} transactions',
                            color: AppColors.trendUp,
                            icon: Icons.point_of_sale,
                            width: cardWidth,
                          ),
                          _StatCard(
                            title: 'Tips',
                            value: '$currency${tipsTotal.toStringAsFixed(2)}',
                            subtitle: 'Recorded on bills',
                            color: AppColors.chartAccent,
                            icon: Icons.emoji_events_outlined,
                            width: cardWidth,
                          ),
                          _StatCard(
                            title: 'Discounts',
                            value: '$currency${discountsTotal.toStringAsFixed(2)}',
                            subtitle: 'Promotions & adjustments',
                            color: Colors.orangeAccent,
                            icon: Icons.percent,
                            width: cardWidth,
                          ),
                          _StatCard(
                            title: 'Expenses',
                            value: '$currency${expenseTotal.toStringAsFixed(2)}',
                            subtitle: '${exps.length} entries',
                            color: AppColors.trendDown,
                            icon: Icons.receipt_long,
                            width: cardWidth,
                          ),
                          _StatCard(
                            title: 'Net (sales − expenses)',
                            value:
                                '${net >= 0 ? '' : '-'}$currency${net.abs().toStringAsFixed(2)}',
                            subtitle: net >= 0 ? 'Positive' : 'Negative',
                            color: net >= 0 ? AppColors.sage : AppColors.trendDown,
                            icon: Icons.account_balance,
                            width: wide ? (c.maxWidth - 12) / 2 : c.maxWidth,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _ChartCard(
                                title: _salesChartTitle(_period),
                                child: SizedBox(
                                  height: 240,
                                  child: _SalesBarChart(
                                    period: _period,
                                    transactions: txs,
                                    currency: currency,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _ChartCard(
                                title: 'Sales by payment method',
                                child: SizedBox(
                                  height: 240,
                                  child: _PaymentPieChart(
                                    totals: paymentTotals,
                                    currency: currency,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _ChartCard(
                          title: _salesChartTitle(_period),
                          child: SizedBox(
                            height: 220,
                            child: _SalesBarChart(
                              period: _period,
                              transactions: txs,
                              currency: currency,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _ChartCard(
                          title: 'Sales by payment method',
                          child: SizedBox(
                            height: 240,
                            child: _PaymentPieChart(
                              totals: paymentTotals,
                              currency: currency,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _ChartCard(
                        title: 'Top services (by attributed sale total)',
                        child: _RankedList(
                          entries: topServices.take(8).map((e) {
                            return _RankRow(
                              label: e.key,
                              value: '$currency${e.value.toStringAsFixed(2)}',
                            );
                          }).toList(),
                          emptyLabel:
                              'No service detail in this range. Complete sales in Billing to build history.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ChartCard(
                        title: 'Expense categories',
                        child: _RankedList(
                          entries: topExpenseCats.take(8).map((e) {
                            return _RankRow(
                              label: e.key,
                              value: '$currency${e.value.toStringAsFixed(2)}',
                            );
                          }).toList(),
                          emptyLabel: 'No expenses in this period.',
                        ),
                      ),
                      const SizedBox(height: 20),
                      _ChartCard(
                        title: 'Recent sales (up to 25)',
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingTextStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            columns: const [
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Customer')),
                              DataColumn(label: Text('Total')),
                              DataColumn(label: Text('Payment')),
                            ],
                            rows: recent.take(25).map((t) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(_formatDate(t.date))),
                                  DataCell(
                                    Text(
                                      t.customerName.isNotEmpty
                                          ? t.customerName
                                          : (t.customerId.isEmpty
                                              ? 'Walk-in'
                                              : t.customerId),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '$currency${t.total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.sage,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(t.paymentMethod)),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _salesChartTitle(_ReportPeriod p) => switch (p) {
        _ReportPeriod.thisMonth => 'Daily sales (this month)',
        _ReportPeriod.last7Days => 'Daily sales (last 7 days)',
        _ReportPeriod.last30Days => 'Daily sales (last 30 days)',
        _ReportPeriod.allTime => 'Monthly sales (last 12 months)',
      };
}

class _OfflineChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storage_rounded, size: 18, color: Colors.grey[400]),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Offline-first: all figures are read from SQLite on this device. No internet required.',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;
  final double width;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _RankRow {
  final String label;
  final String value;
  _RankRow({required this.label, required this.value});
}

class _RankedList extends StatelessWidget {
  final List<_RankRow> entries;
  final String emptyLabel;

  const _RankedList({
    required this.entries,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            emptyLabel,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
      );
    }
    return Column(
      children: entries.map((e) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  e.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                e.value,
                style: const TextStyle(
                  color: AppColors.sage,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SalesBarChart extends StatelessWidget {
  final _ReportPeriod period;
  final List<TransactionRecord> transactions;
  final String currency;

  const _SalesBarChart({
    required this.period,
    required this.transactions,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    List<double> values;
    List<String> labels;

    if (period == _ReportPeriod.allTime) {
      values = List.filled(12, 0);
      for (final t in transactions) {
        final monthsAgo =
            (now.year - t.date.year) * 12 + now.month - t.date.month;
        if (monthsAgo >= 0 && monthsAgo < 12) {
          values[11 - monthsAgo] += t.total;
        }
      }
      const monthNames = [
        'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D',
      ];
      labels = List.generate(12, (i) {
        final d = DateTime(now.year, now.month - (11 - i), 1);
        return monthNames[d.month - 1];
      });
    } else if (period == _ReportPeriod.thisMonth) {
      final lastDay = DateTime(now.year, now.month + 1, 0).day;
      values = List.filled(lastDay, 0);
      for (final t in transactions) {
        if (t.date.year == now.year && t.date.month == now.month) {
          values[t.date.day - 1] += t.total;
        }
      }
      labels = List.generate(lastDay, (i) => '${i + 1}');
    } else {
      final days = period == _ReportPeriod.last7Days ? 7 : 30;
      final today = DateTime(now.year, now.month, now.day);
      values = List.filled(days, 0);
      labels = List.generate(days, (i) {
        final d = today.subtract(Duration(days: days - 1 - i));
        return '${d.month}/${d.day}';
      });
      for (final t in transactions) {
        final td = DateTime(t.date.year, t.date.month, t.date.day);
        final idx = td.difference(today.subtract(Duration(days: days - 1))).inDays;
        if (idx >= 0 && idx < days) {
          values[idx] += t.total;
        }
      }
    }

    final maxY = values.fold<double>(0, (m, v) => v > m ? v : m);
    final chartMaxY = maxY <= 0 ? 100.0 : maxY * 1.15;

    if (values.isEmpty || values.every((v) => v == 0)) {
      return Center(
        child: Text(
          'No sales in this range.',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: chartMaxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF2A2A2A),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final i = group.x.toInt();
              if (i < 0 || i >= values.length) return null;
              return BarTooltipItem(
                '$currency${values[i].toStringAsFixed(2)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= labels.length) {
                  return const SizedBox.shrink();
                }
                if (labels.length > 14 && i % 2 == 1) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    labels[i],
                    style: const TextStyle(color: Colors.grey, fontSize: 9),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                if (value >= chartMaxY * 0.99) return const SizedBox.shrink();
                return Text(
                  value >= 1000
                      ? '${(value / 1000).toStringAsFixed(1)}k'
                      : value.toInt().toString(),
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
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
          horizontalInterval: chartMaxY > 0 ? chartMaxY / 4 : 25,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white10,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(values.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: values[i],
                color: AppColors.sage.withValues(
                  alpha: i == values.length - 1 ? 1.0 : 0.65,
                ),
                width: period == _ReportPeriod.thisMonth ? 6 : 10,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _PaymentPieChart extends StatelessWidget {
  final Map<String, double> totals;
  final String currency;

  const _PaymentPieChart({
    required this.totals,
    required this.currency,
  });

  static const _palette = [
    Color(0xFFFF8A00),
    Color(0xFF4FC3F7),
    Color(0xFF81C784),
    Color(0xFFFFB74D),
    Color(0xFFBA68C8),
    Color(0xFFE57373),
  ];

  @override
  Widget build(BuildContext context) {
    if (totals.isEmpty) {
      return Center(
        child: Text(
          'No payment data in this range.',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sum = entries.fold<double>(0, (s, e) => s + e.value);
    if (sum <= 0) {
      return Center(
        child: Text(
          'No payment data in this range.',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final frac = e.value / sum;
      sections.add(
        PieChartSectionData(
          color: _palette[i % _palette.length],
          value: e.value,
          title: '${(frac * 100).toStringAsFixed(0)}%',
          radius: 72,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: sections,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: entries.asMap().entries.map((me) {
              final i = me.key;
              final e = me.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _palette[i % _palette.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.key,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      '$currency${e.value.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
