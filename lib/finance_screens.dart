import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'app_theme.dart';
import 'expense.dart';
import 'finance_features.dart';

Uint8List buildMonthlyExcelReport({
  required DateTime month,
  required List<Expense> expenses,
  required List<MoneyReceived> moneyReceived,
  required double closingBalance,
}) {
  String money(double amount) => '₹${amount.toStringAsFixed(2)}';
  String date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  final workbook = Excel.createExcel();
  workbook.delete('Sheet1');
  final sheet = workbook['Monthly report'];
  void row(Iterable<Object?> values) => sheet.appendRow(
    values.map((value) => TextCellValue(value?.toString() ?? '')).toList(),
  );
  row(['Pennywise monthly report', '${month.year}-${month.month}']);
  row([
    'Money In',
    money(moneyReceived.fold<double>(0, (sum, item) => sum + item.amount)),
  ]);
  row([
    'Money Out',
    money(expenses.fold<double>(0, (sum, item) => sum + item.amount)),
  ]);
  row(['Closing Available Balance', money(closingBalance)]);
  row([]);
  row([
    'Date',
    'Transaction Type',
    'Category',
    'Subcategory',
    'Description',
    'Payment Method',
    'Amount',
  ]);
  for (final item in moneyReceived) {
    row([
      date(item.date),
      'Money In',
      'Money In',
      '',
      item.source,
      item.paymentMethod,
      money(item.amount),
    ]);
  }
  for (final item in expenses) {
    row([
      date(item.date),
      'Money Out',
      item.displayCategory,
      item.subcategory ?? item.transportMode ?? '',
      item.title,
      item.paymentMethod,
      money(item.amount),
    ]);
  }
  final encoded = workbook.encode();
  if (encoded == null) throw StateError('Could not encode Excel report.');
  return Uint8List.fromList(encoded);
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.overview, super.key});

  final FinanceOverview overview;

  @override
  Widget build(BuildContext context) {
    final palette = PennywisePalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Money tools')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                Icons.compare_arrows_rounded,
                color: palette.primary,
              ),
              title: const Text('Monthly comparison & reports'),
              subtitle: const Text('Compare spending and export your activity'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => MonthlyReportsScreen(overview: overview),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MonthlyReportsScreen extends StatefulWidget {
  const MonthlyReportsScreen({required this.overview, super.key});

  final FinanceOverview overview;

  @override
  State<MonthlyReportsScreen> createState() => _MonthlyReportsScreenState();
}

class _MonthlyReportsScreenState extends State<MonthlyReportsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _sharing = false;

  List<Expense> get _expenses =>
      widget.overview.expenses
          .where((item) => _sameMonth(item.date, _month))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  List<MoneyReceived> get _income =>
      widget.overview.moneyReceived
          .where((item) => _sameMonth(item.date, _month))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  bool _sameMonth(DateTime date, DateTime month) =>
      date.year == month.year && date.month == month.month;

  double _sum<T>(Iterable<T> values, double Function(T) amount) =>
      values.fold(0, (total, item) => total + amount(item));

  String _money(double amount) => '₹${amount.toStringAsFixed(2)}';

  String _monthName(DateTime month) =>
      '${_monthNames[month.month - 1]} ${month.year}';

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  double get _closingBalance {
    final cutoff = DateTime(_month.year, _month.month + 1);
    final received = widget.overview.moneyReceived
        .where((item) => item.date.isBefore(cutoff))
        .fold<double>(0, (total, item) => total + item.amount);
    final spent = widget.overview.expenses
        .where((item) => item.date.isBefore(cutoff))
        .fold<double>(0, (total, item) => total + item.amount);
    final savings = widget.overview.savingsGoals.fold<double>(
      0,
      (total, goal) => total + goal.savedAmount,
    );
    return received - spent - savings;
  }

  Future<void> _export({required bool asExcel}) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final fileName =
          'pennywise-${_month.year}-${_month.month.toString().padLeft(2, '0')}'
          '${asExcel ? '.xlsx' : '.csv'}';
      final bytes = asExcel ? _excelBytes() : _csvBytes();
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: asExcel
                  ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
                  : 'text/csv',
              name: fileName,
            ),
          ],
          fileNameOverrides: [fileName],
          subject: 'Pennywise report for ${_monthName(_month)}',
        ),
      );
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share report: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Uint8List _csvBytes() => Uint8List.fromList(
    utf8.encode(
      buildMonthlyCsv(
        month: _month,
        expenses: _expenses,
        moneyReceived: _income,
        closingBalance: _closingBalance,
      ),
    ),
  );

  Uint8List _excelBytes() => buildMonthlyExcelReport(
    month: _month,
    expenses: _expenses,
    moneyReceived: _income,
    closingBalance: _closingBalance,
  );

  @override
  Widget build(BuildContext context) {
    final comparison = compareExpenseMonths(widget.overview.expenses, _month);
    final categories = {
      ...comparison.currentCategories.keys,
      ...comparison.previousCategories.keys,
    }.toList()..sort();
    final maxCategorySpend = categories.fold<double>(0, (highest, category) {
      final current = comparison.currentCategories[category] ?? 0;
      final previous = comparison.previousCategories[category] ?? 0;
      return [highest, current, previous].reduce((a, b) => a > b ? a : b);
    });
    final palette = PennywisePalette.of(context);
    final change = comparison.difference;
    final percentage = comparison.percentageChange;
    final empty = _expenses.isEmpty && _income.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly comparison')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => setState(
                      () => _month = DateTime(_month.year, _month.month - 1),
                    ),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      _monthName(_month),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: _sameMonth(DateTime.now(), _month)
                        ? null
                        : () => setState(
                            () => _month = DateTime(
                              _month.year,
                              _month.month + 1,
                            ),
                          ),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (empty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('No transactions in this month yet.'),
              ),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Money Out',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 14),
                    _totalRow(
                      context,
                      _monthName(_month),
                      comparison.currentTotal,
                      palette.primary,
                    ),
                    const SizedBox(height: 10),
                    _totalRow(
                      context,
                      _monthName(comparison.previousMonth),
                      comparison.previousTotal,
                      palette.secondary,
                    ),
                    const Divider(height: 24),
                    Text(
                      comparison.previousTotal == 0
                          ? change == 0
                                ? 'No spending in either month'
                                : 'No spending in the previous month'
                          : '${change > 0
                                    ? 'Increased'
                                    : change < 0
                                    ? 'Decreased'
                                    : 'No change'} by '
                                '${_money(change.abs())}'
                                '${percentage == null ? '' : ' (${percentage.toStringAsFixed(1)}%)'}',
                      style: TextStyle(
                        color: change > 0 ? palette.expense : palette.income,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category comparison',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (categories.isEmpty)
                      const Text('No expense categories in these months.')
                    else
                      for (final category in categories)
                        _categoryComparison(
                          category,
                          comparison.currentCategories[category] ?? 0,
                          comparison.previousCategories[category] ?? 0,
                          maxCategorySpend,
                          context,
                        ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly report',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Money In ${_money(_sum(_income, (item) => item.amount))}  ·  '
                    'Money Out ${_money(_sum(_expenses, (item) => item.amount))}',
                  ),
                  const SizedBox(height: 4),
                  Text('Closing Available Balance ${_money(_closingBalance)}'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _sharing
                            ? null
                            : () => _export(asExcel: false),
                        icon: const Icon(Icons.table_rows_rounded),
                        label: const Text('Share CSV'),
                      ),
                      FilledButton.icon(
                        onPressed: _sharing
                            ? null
                            : () => _export(asExcel: true),
                        icon: _sharing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.grid_on_rounded),
                        label: const Text('Share Excel'),
                      ),
                    ],
                  ),
                  if (empty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'This report will contain the monthly summary and column headings only.',
                      style: TextStyle(color: palette.muted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(
    BuildContext context,
    String title,
    double amount,
    Color color,
  ) => Row(
    children: [
      Expanded(child: Text(title)),
      Text(
        _money(amount),
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    ],
  );

  Widget _categoryComparison(
    String category,
    double current,
    double previous,
    double maxValue,
    BuildContext context,
  ) {
    final palette = PennywisePalette.of(context);
    final max = maxValue <= 0 ? 1 : maxValue;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(category)),
              Text('${_money(current)} / ${_money(previous)}'),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: current / max,
                  minHeight: 5,
                  backgroundColor: palette.surfaceAlt,
                  color: palette.primary,
                ),
                const SizedBox(height: 3),
                LinearProgressIndicator(
                  value: previous / max,
                  minHeight: 5,
                  backgroundColor: palette.surfaceAlt,
                  color: palette.secondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
