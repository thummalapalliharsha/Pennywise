import 'expense.dart';

class MonthlyExpenseComparison {
  const MonthlyExpenseComparison({
    required this.month,
    required this.previousMonth,
    required this.currentTotal,
    required this.previousTotal,
    required this.currentCategories,
    required this.previousCategories,
  });

  final DateTime month;
  final DateTime previousMonth;
  final double currentTotal;
  final double previousTotal;
  final Map<String, double> currentCategories;
  final Map<String, double> previousCategories;

  double get difference => currentTotal - previousTotal;

  double? get percentageChange =>
      previousTotal == 0 ? null : difference.abs() / previousTotal * 100;
}

MonthlyExpenseComparison compareExpenseMonths(
  Iterable<Expense> expenses,
  DateTime month,
) {
  final currentMonth = DateTime(month.year, month.month);
  final previousMonth = DateTime(month.year, month.month - 1);
  final currentCategories = <String, double>{};
  final previousCategories = <String, double>{};
  for (final expense in expenses) {
    final target =
        expense.date.year == currentMonth.year &&
            expense.date.month == currentMonth.month
        ? currentCategories
        : expense.date.year == previousMonth.year &&
              expense.date.month == previousMonth.month
        ? previousCategories
        : null;
    if (target != null) {
      target.update(
        expense.displayCategory,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
  }
  return MonthlyExpenseComparison(
    month: currentMonth,
    previousMonth: previousMonth,
    currentTotal: currentCategories.values.fold(0, (a, b) => a + b),
    previousTotal: previousCategories.values.fold(0, (a, b) => a + b),
    currentCategories: currentCategories,
    previousCategories: previousCategories,
  );
}

String buildMonthlyCsv({
  required DateTime month,
  required List<Expense> expenses,
  required List<MoneyReceived> moneyReceived,
  required double closingBalance,
}) {
  String cell(Object? value) {
    final text = '$value';
    return '"${text.replaceAll('"', '""')}"';
  }

  String rupees(double amount) => '₹${amount.toStringAsFixed(2)}';

  final rows = <List<Object?>>[
    ['Pennywise monthly report', '${month.year}-${month.month}'],
    [
      'Money In',
      rupees(moneyReceived.fold<double>(0, (sum, item) => sum + item.amount)),
    ],
    [
      'Money Out',
      rupees(expenses.fold<double>(0, (sum, item) => sum + item.amount)),
    ],
    ['Closing Available Balance', rupees(closingBalance)],
    [],
    [
      'Date',
      'Type',
      'Category',
      'Subcategory',
      'Description',
      'Payment Method',
      'Amount',
    ],
    ...moneyReceived.map(
      (item) => [
        _csvDate(item.date),
        'Money In',
        'Money In',
        '',
        item.source,
        item.paymentMethod,
        rupees(item.amount),
      ],
    ),
    ...expenses.map(
      (item) => [
        _csvDate(item.date),
        'Money Out',
        item.displayCategory,
        item.subcategory ?? item.transportMode ?? '',
        item.title,
        item.paymentMethod,
        rupees(item.amount),
      ],
    ),
  ];
  return '\uFEFF${rows.map((row) => row.map(cell).join(',')).join('\r\n')}';
}

String _csvDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
