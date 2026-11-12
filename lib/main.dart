import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'auth_flow.dart';
import 'expense.dart';
import 'expense_repository.dart';
import 'firebase_options.dart';
import 'finance_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? firebaseInitializationError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (error) {
    firebaseInitializationError =
        '${error.code}: ${error.message ?? error.toString()}';
  }
  runApp(MyApp(firebaseInitializationError: firebaseInitializationError));
}

Widget _categorySpendingCard(
  BuildContext context,
  Map<String, double> categorySpend,
  double monthSpent, {
  required VoidCallback onAdd,
  required String Function(double) formatMoney,
}) {
  final palette = PennywisePalette.of(context);
  final entries = categorySpend.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (entries.isEmpty) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          Icon(Icons.donut_small_rounded, color: palette.primary),
          const SizedBox(height: 8),
          const Text('Add an expense to see your category breakdown.'),
          TextButton(onPressed: onAdd, child: const Text('Add expense')),
        ],
      ),
    );
  }

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: palette.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: palette.line),
    ),
    child: Column(
      children: entries.map((entry) {
        final category = Expense(
          id: '',
          title: '',
          category: entry.key,
          amount: entry.value,
          date: DateTime.now(),
        );
        final share = monthSpent <= 0
            ? 0.0
            : (entry.value / monthSpent).clamp(0.0, 1.0).toDouble();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette
                      .categoryColor(entry.key)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  category.icon,
                  color: palette.categoryColor(entry.key),
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          formatMoney(entry.value),
                          style: TextStyle(
                            color: palette.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: share),
                        duration: const Duration(milliseconds: 350),
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 5,
                          backgroundColor: palette.surfaceAlt,
                          valueColor: AlwaysStoppedAnimation(
                            palette.categoryColor(entry.key),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 34,
                child: Text(
                  '${(share * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: palette.muted, fontSize: 10),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({this.firebaseInitializationError, super.key});

  final String? firebaseInitializationError;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Pennywise',
      theme: buildAppTheme(),
      home: widget.firebaseInitializationError == null
          ? AuthGate(
              signedInChild: ExpenseDashboard(
                onOpenSettings: (overview) {
                  _navigatorKey.currentState?.push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => SettingsScreen(overview: overview),
                    ),
                  );
                },
              ),
            )
          : FirebaseSetupScreen(details: widget.firebaseInitializationError!),
    );
  }
}

enum TransactionHistoryKind { all, moneyIn, moneyOut }

class ExpenseDashboard extends StatefulWidget {
  const ExpenseDashboard({
    this.repository,
    this.userId,
    this.onOpenSettings,
    super.key,
  });

  final ExpenseRepository? repository;
  final String? userId;
  final ValueChanged<FinanceOverview>? onOpenSettings;

  @override
  State<ExpenseDashboard> createState() => _ExpenseDashboardState();
}

class _ExpenseDashboardState extends State<ExpenseDashboard> {
  static const _paymentMethods = ['UPI', 'Cash', 'Card'];
  static const _transportModes = Expense.transportModes;
  static const _expenseCategories = Expense.categories;

  late final ExpenseRepository _repository =
      widget.repository ?? FirestoreExpenseRepository();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _goalTitleController = TextEditingController();
  final _goalTargetController = TextEditingController();
  final _goalSavedController = TextEditingController();
  bool _amountsVisible = true;
  Stream<FinanceOverview>? _financeStream;
  String? _financeStreamUserId;
  DateTime? _financeStreamMonth;

  String? get _userId =>
      widget.userId ?? FirebaseAuth.instance.currentUser?.uid;

  Stream<FinanceOverview> _watchFinance(String userId, DateTime month) {
    final normalizedMonth = DateTime(month.year, month.month);
    if (_financeStream == null ||
        _financeStreamUserId != userId ||
        _financeStreamMonth != normalizedMonth) {
      _financeStream = _repository.watchFinance(userId, normalizedMonth);
      _financeStreamUserId = userId;
      _financeStreamMonth = normalizedMonth;
    }
    return _financeStream!;
  }

  bool _isValidTitle(String title) =>
      title.isNotEmpty && title.runes.length <= 120;

  bool _isValidAmount(double? amount) =>
      amount != null && amount.isFinite && amount > 0 && amount <= 1000000000;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _goalTitleController.dispose();
    _goalTargetController.dispose();
    _goalSavedController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _showMessage(error.message ?? 'Unable to sign out (${error.code}).');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showExpenseSheet({Expense? existing}) async {
    _titleController.text = existing?.title ?? '';
    _amountController.text = existing?.amount.toString() ?? '';
    var category = existing?.displayCategory ?? 'Food';
    var subcategory = existing?.subcategory;
    var transportMode = _transportModes.contains(existing?.transportMode)
        ? existing!.transportMode!
        : 'Bus';
    var paymentMethod = _paymentMethods.contains(existing?.paymentMethod)
        ? existing!.paymentMethod
        : 'UPI';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => _editorSheet(
          title: existing == null ? 'Add an expense' : 'Edit expense',
          fields: [
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What did you spend on?',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
            ),
            const SizedBox(height: 12),
            _amountField(),
            const SizedBox(height: 12),
            _categoryPicker(
              selected: category,
              onSelected: (value) => setSheetState(() {
                category = value;
                if (value != 'Transport') transportMode = 'Bus';
                if (value != 'Shopping') subcategory = null;
              }),
            ),
            if (category == 'Transport') ...[
              const SizedBox(height: 12),
              _transportPicker(
                selected: transportMode,
                onSelected: (value) =>
                    setSheetState(() => transportMode = value),
              ),
            ],
            if (category == 'Shopping') ...[
              const SizedBox(height: 12),
              _shoppingPicker(
                selected: Expense.shoppingTypes.contains(subcategory)
                    ? subcategory!
                    : Expense.shoppingTypes.first,
                onSelected: (value) => setSheetState(() => subcategory = value),
              ),
            ],
            const SizedBox(height: 12),
            _paymentDropdown(
              value: paymentMethod,
              onChanged: (value) {
                if (value != null) setSheetState(() => paymentMethod = value);
              },
            ),
          ],
          actionLabel: existing == null ? 'Save expense' : 'Save changes',
          onSave: () async {
            final title = _titleController.text.trim();
            final amount = double.tryParse(_amountController.text);
            if (!_isValidTitle(title) ||
                amount == null ||
                !_isValidAmount(amount)) {
              _showMessage(
                'Enter a description of up to 120 characters and a valid '
                'amount up to ₹1,000,000,000.',
              );
              return;
            }
            final userId = _userId;
            if (userId == null) {
              _showMessage('Sign in before saving an expense.');
              return;
            }
            try {
              final expense = Expense(
                id: existing?.id ?? '',
                title: title,
                category: category,
                amount: amount,
                date: existing?.date ?? DateTime.now(),
                paymentMethod: paymentMethod,
                transportMode: category == 'Transport' ? transportMode : null,
                subcategory: category == 'Shopping' ? subcategory : null,
              );
              if (existing == null) {
                await _repository.addExpense(userId, expense);
              } else {
                await _repository.updateExpense(userId, expense);
              }
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            } on FirebaseException catch (error) {
              _showMessage(
                error.message ?? 'Could not save expense (${error.code}).',
              );
            } catch (error) {
              _showMessage('Could not save expense: $error');
            }
          },
        ),
      ),
    );
  }

  Future<void> _showMoneyReceivedSheet({MoneyReceived? existing}) async {
    _titleController.text = existing?.source ?? 'From parents';
    _amountController.text = existing?.amount.toString() ?? '';
    var paymentMethod = _paymentMethods.contains(existing?.paymentMethod)
        ? existing!.paymentMethod
        : 'UPI';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => _editorSheet(
          title: existing == null ? 'Money In' : 'Edit Money In',
          fields: [
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'From',
                prefixIcon: Icon(Icons.volunteer_activism_rounded),
              ),
            ),
            const SizedBox(height: 12),
            _amountField(),
            const SizedBox(height: 12),
            _paymentDropdown(
              value: paymentMethod,
              onChanged: (value) {
                if (value != null) setSheetState(() => paymentMethod = value);
              },
            ),
          ],
          actionLabel: existing == null ? 'Save Money In' : 'Save changes',
          onSave: () async {
            final source = _titleController.text.trim();
            final amount = double.tryParse(_amountController.text);
            if (!_isValidTitle(source) ||
                amount == null ||
                !_isValidAmount(amount)) {
              _showMessage(
                'Enter a source of up to 120 characters and a valid amount '
                'up to ₹1,000,000,000.',
              );
              return;
            }
            final userId = _userId;
            if (userId == null) {
              _showMessage('Sign in before saving Money In.');
              return;
            }
            try {
              final entry = MoneyReceived(
                id: existing?.id ?? '',
                source: source,
                amount: amount,
                date: existing?.date ?? DateTime.now(),
                paymentMethod: paymentMethod,
              );
              if (existing == null) {
                await _repository.addMoneyReceived(userId, entry);
              } else {
                await _repository.updateMoneyReceived(userId, entry);
              }
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            } on FirebaseException catch (error) {
              _showMessage(
                error.message ?? 'Could not save transfer (${error.code}).',
              );
            } catch (error) {
              _showMessage('Could not save transfer: $error');
            }
          },
        ),
      ),
    );
  }

  Future<void> _showBudgetSheet({double currentAmount = 0}) async {
    _amountController.text = currentAmount > 0 ? currentAmount.toString() : '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _editorSheet(
        title: 'Set monthly budget',
        subtitle: 'Choose a spending limit for this month.',
        fields: [_amountField(label: 'Monthly limit')],
        actionLabel: 'Save budget',
        onSave: () async {
          final amount = double.tryParse(_amountController.text);
          if (amount == null || !_isValidAmount(amount)) {
            _showMessage('Enter a valid budget up to ₹1,000,000,000.');
            return;
          }
          final userId = _userId;
          if (userId == null) {
            _showMessage('Sign in before saving a budget.');
            return;
          }
          try {
            final now = DateTime.now();
            await _repository.setMonthlyBudget(
              userId,
              DateTime(now.year, now.month),
              amount,
            );
            if (sheetContext.mounted) Navigator.pop(sheetContext);
          } on FirebaseException catch (error) {
            _showMessage(
              error.message ?? 'Could not save budget (${error.code}).',
            );
          } catch (error) {
            _showMessage('Could not save budget: $error');
          }
        },
      ),
    );
  }

  Future<void> _showGoalSheet({SavingsGoal? existing}) async {
    _goalTitleController.text = existing?.title ?? '';
    _goalTargetController.text = existing?.targetAmount.toString() ?? '';
    _goalSavedController.text = existing?.savedAmount.toString() ?? '0';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _editorSheet(
        title: existing == null
            ? 'Create a savings goal'
            : 'Update savings goal',
        fields: [
          TextField(
            controller: _goalTitleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What are you saving for?',
              prefixIcon: Icon(Icons.flag_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _goalTargetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Goal amount',
              prefixIcon: Icon(Icons.currency_rupee_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _goalSavedController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Already saved',
              prefixIcon: Icon(Icons.savings_rounded),
            ),
          ),
        ],
        actionLabel: existing == null ? 'Save goal' : 'Save changes',
        onSave: () async {
          final title = _goalTitleController.text.trim();
          final target = double.tryParse(_goalTargetController.text);
          final saved = double.tryParse(_goalSavedController.text);
          if (!_isValidTitle(title) ||
              target == null ||
              !_isValidAmount(target) ||
              saved == null ||
              saved < 0 ||
              saved > target) {
            _showMessage(
              'Enter a goal title up to 120 characters, a valid target up to '
              '₹1,000,000,000, and a valid saved amount.',
            );
            return;
          }
          final userId = _userId;
          if (userId == null) {
            _showMessage('Sign in before saving a goal.');
            return;
          }
          try {
            final goal = SavingsGoal(
              id: existing?.id ?? '',
              title: title,
              targetAmount: target,
              savedAmount: saved,
              createdAt: existing?.createdAt ?? DateTime.now(),
            );
            if (existing == null) {
              await _repository.addSavingsGoal(userId, goal);
            } else {
              await _repository.updateSavingsGoal(userId, goal);
            }
            if (sheetContext.mounted) Navigator.pop(sheetContext);
          } on FirebaseException catch (error) {
            _showMessage(
              error.message ?? 'Could not save goal (${error.code}).',
            );
          } catch (error) {
            _showMessage('Could not save goal: $error');
              !saved.isFinite ||
          }
        },
      ),
    );
  }

  Widget _editorSheet({
    required String title,
    String? subtitle,
    required List<Widget> fields,
    required String actionLabel,
    required Future<void> Function() onSave,
  }) => _EditorSheet(
    title: title,
    subtitle: subtitle,
    fields: fields,
    actionLabel: actionLabel,
    onSave: onSave,
  );

  Widget _amountField({String label = 'Amount'}) => TextField(
    controller: _amountController,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(Icons.currency_rupee_rounded),
    ),
  );

  Widget _paymentDropdown({
    required String value,
    required ValueChanged<String?> onChanged,
  }) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: const InputDecoration(
      labelText: 'Payment method',
      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
    ),
    items: _paymentMethods
        .map((method) => DropdownMenuItem(value: method, child: Text(method)))
        .toList(),
    onChanged: onChanged,
  );

  Widget _categoryPicker({
    required String selected,
    required ValueChanged<String> onSelected,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          'Category',
          style: TextStyle(
            color: PennywisePalette.of(context).muted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Wrap(
        spacing: 7,
        runSpacing: 7,
        children: _expenseCategories.map((category) {
          final expense = Expense(
            id: '',
            title: '',
            category: category,
            amount: 0,
            date: DateTime.now(),
          );
          final isSelected = selected == category;
          return ChoiceChip(
            avatar: Icon(
              expense.icon,
              size: 17,
              color: isSelected
                  ? Colors.white
                  : PennywisePalette.of(context).categoryColor(category),
            ),
            label: Text(category),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => onSelected(category),
            labelStyle: TextStyle(
              color: isSelected
                  ? Colors.white
                  : PennywisePalette.of(context).text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            selectedColor: PennywisePalette.of(context).primary,
            backgroundColor: PennywisePalette.of(context).canvas,
            side: BorderSide(
              color: isSelected
                  ? PennywisePalette.of(context).primary
                  : PennywisePalette.of(context).line,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        }).toList(),
      ),
    ],
  );

  Widget _transportPicker({
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    const icons = {
      'Bus': Icons.directions_bus_rounded,
      'Metro': Icons.subway_rounded,
      'Auto': Icons.electric_rickshaw_rounded,
      'Cab': Icons.local_taxi_rounded,
      'Bike': Icons.two_wheeler_rounded,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Transport type',
            style: TextStyle(
              color: PennywisePalette.of(context).muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          children: _transportModes.map((mode) {
            final isSelected = selected == mode;
            return ChoiceChip(
              avatar: Icon(
                icons[mode],
                size: 17,
                color: isSelected
                    ? Colors.white
                    : PennywisePalette.of(context).secondary,
              ),
              label: Text(mode),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => onSelected(mode),
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : PennywisePalette.of(context).text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              selectedColor: PennywisePalette.of(context).secondary,
              backgroundColor: PennywisePalette.of(context).canvas,
              side: BorderSide(
                color: isSelected
                    ? PennywisePalette.of(context).secondary
                    : PennywisePalette.of(context).line,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _shoppingPicker({
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    const icons = {
      'General Shopping': Icons.shopping_bag_rounded,
      'Clothes & Footwear': Icons.checkroom_rounded,
      'Electronics': Icons.devices_rounded,
      'Accessories': Icons.watch_rounded,
      'Household Items': Icons.chair_alt_rounded,
    };
    final palette = PennywisePalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Shopping type',
            style: TextStyle(
              color: palette.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: Expense.shoppingTypes.map((type) {
            final isSelected = selected == type;
            return ChoiceChip(
              avatar: Icon(
                icons[type],
                size: 17,
                color: isSelected ? Colors.white : palette.primary,
              ),
              label: Text(type),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => onSelected(type),
              selectedColor: palette.primary,
              backgroundColor: palette.canvas,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : palette.text,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(
                color: isSelected ? palette.primary : palette.line,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<bool> _deleteExpense(Expense expense) async {
    final userId = _userId;
    if (userId == null) {
      _showMessage('Sign in before deleting an expense.');
      return false;
    }
    try {
      await _repository.deleteExpense(userId, expense.id);
      return true;
    } on FirebaseException catch (error) {
      if (mounted) {
        _showMessage(
          error.message ?? 'Could not delete expense (${error.code}).',
        );
      }
      return false;
    } catch (error) {
      if (mounted) _showMessage('Could not delete expense: $error');
      return false;
    }
  }

  Future<bool> _deleteMoneyReceived(MoneyReceived entry) async {
    final userId = _userId;
    if (userId == null) {
      _showMessage('Sign in before deleting a transfer.');
      return false;
    }
    try {
      await _repository.deleteMoneyReceived(userId, entry.id);
      return true;
    } on FirebaseException catch (error) {
      if (mounted) {
        _showMessage(
          error.message ?? 'Could not delete transfer (${error.code}).',
        );
      }
      return false;
    } catch (error) {
      if (mounted) _showMessage('Could not delete transfer: $error');
      return false;
    }
  }

  Future<void> _deleteGoal(SavingsGoal goal) async {
    final userId = _userId;
    if (userId == null) {
      _showMessage('Sign in before deleting a goal.');
      return;
    }
    try {
      await _repository.deleteSavingsGoal(userId, goal.id);
    } on FirebaseException catch (error) {
      if (mounted) {
        _showMessage(error.message ?? 'Could not delete goal (${error.code}).');
      }
    } catch (error) {
      if (mounted) _showMessage('Could not delete goal: $error');
    }
  }

  Future<void> _confirmDelete(
    String title,
    String description,
    Future<void> Function() onDelete,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) await onDelete();
  }

  String _monthId(DateTime date) => '${_monthName(date.month)} ${date.year}';

  String _monthName(int month) => const [
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
  ][month - 1];

  String _money(double amount) => '₹${amount.toStringAsFixed(2)}';

  String _balanceMoney(double amount) =>
      _amountsVisible ? _money(amount) : '₹••••••';

  DateTime _dateOf(Object transaction) => switch (transaction) {
    Expense expense => expense.date,
    MoneyReceived received => received.date,
    _ => DateTime.fromMillisecondsSinceEpoch(0),
  };

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final calendarDate = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    if (calendarDate == today) return 'Today';
    if (calendarDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  bool _isSameMonth(DateTime date, DateTime month) =>
      date.year == month.year && date.month == month.month;

  List<Object> _recentTransactions(FinanceOverview overview) {
    final transactions = <Object>[
      ...overview.expenses,
      ...overview.moneyReceived,
    ]..sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));
    return transactions.take(5).toList();
  }

  Future<void> _openHistoryFromDashboard(
    TransactionHistoryKind kind,
    FinanceOverview overview,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (historyContext) => TransactionHistoryScreen(
          kind: kind,
          initialOverview: overview,
          formatMoney: _money,
          onEditExpense: (expense) async {
            Navigator.of(historyContext).pop();
            await _showExpenseSheet(existing: expense);
          },
          onEditMoneyReceived: (entry) async {
            Navigator.of(historyContext).pop();
            await _showMoneyReceivedSheet(existing: entry);
          },
          onDeleteExpense: _deleteExpense,
          onDeleteMoneyReceived: _deleteMoneyReceived,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _userId;
    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view your finances.')),
      );
    }

    final now = DateTime.now();
    return StreamBuilder<FinanceOverview>(
      stream: _watchFinance(userId, DateTime(now.year, now.month)),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      color: PennywisePalette.of(context).expense,
                    ),
                    const SizedBox(height: 12),
                    const Text('Could not load your finances.'),
                    const SizedBox(height: 4),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: PennywisePalette.of(context).muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _financeStream = null),
                      icon: Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _dashboard(context, snapshot.data!);
      },
    );
  }

  Widget _dashboard(BuildContext context, FinanceOverview overview) {
    final now = DateTime.now();
    final totalReceived = overview.moneyReceived.fold<double>(
      0,
      (total, entry) => total + entry.amount,
    );
    final totalSpent = overview.expenses.fold<double>(
      0,
      (total, expense) => total + expense.amount,
    );
    final allocatedToGoals = overview.savingsGoals.fold<double>(
      0,
      (total, goal) => total + goal.savedAmount,
    );
    final balance = totalReceived - totalSpent - allocatedToGoals;
    final monthReceived = overview.moneyReceived
        .where((entry) => _isThisMonth(entry.date))
        .fold<double>(0, (total, entry) => total + entry.amount);
    final monthExpenses = overview.expenses
        .where((expense) => _isThisMonth(expense.date))
        .toList();
    final monthSpent = monthExpenses.fold<double>(
      0,
      (total, expense) => total + expense.amount,
    );
    final previousMonth = DateTime(now.year, now.month - 1);
    final previousMonthDays = DateTime(
      previousMonth.year,
      previousMonth.month + 1,
      0,
    ).day;
    final previousMonthCutoff = DateTime(
      previousMonth.year,
      previousMonth.month,
      (now.day < previousMonthDays ? now.day : previousMonthDays) + 1,
    );
    final previousMonthSpent = overview.expenses
        .where(
          (expense) =>
              _isSameMonth(expense.date, previousMonth) &&
              expense.date.isBefore(previousMonthCutoff),
        )
        .fold<double>(0, (total, expense) => total + expense.amount);
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(
      Duration(days: todayStart.weekday - 1),
    );
    final todaySpent = overview.expenses
        .where(
          (expense) =>
              !expense.date.isBefore(todayStart) &&
              expense.date.isBefore(todayStart.add(const Duration(days: 1))),
        )
        .fold<double>(0, (total, expense) => total + expense.amount);
    final weekSpent = overview.expenses
        .where(
          (expense) =>
              !expense.date.isBefore(weekStart) &&
              expense.date.isBefore(todayStart.add(const Duration(days: 1))),
        )
        .fold<double>(0, (total, expense) => total + expense.amount);
    final categorySpend = <String, double>{};
    for (final expense in monthExpenses) {
      categorySpend.update(
        expense.displayCategory,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    final highestCategory = categorySpend.entries.isEmpty
        ? null
        : categorySpend.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final budget = overview.monthlyBudget.amount;
    final budgetProgress = budget <= 0
        ? 0.0
        : (monthSpent / budget).clamp(0.0, 1.0).toDouble();
    final transactions = _recentTransactions(overview);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 116),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, overview),
              const SizedBox(height: 24),
              _balanceCard(
                balance,
                totalReceived,
                totalSpent,
                onReceivedTap: () => _openHistoryFromDashboard(
                  TransactionHistoryKind.moneyIn,
                  overview,
                ),
                onSpentTap: () => _openHistoryFromDashboard(
                  TransactionHistoryKind.moneyOut,
                  overview,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _actionCard(
                      title: 'Add Money In',
                      subtitle: 'From parents',
                      icon: Icons.south_west_rounded,
                      color: PennywisePalette.of(context).income,
                      onTap: _showMoneyReceivedSheet,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _actionCard(
                      title: 'Add expense',
                      subtitle: 'Log spending',
                      icon: Icons.north_east_rounded,
                      color: PennywisePalette.of(context).expense,
                      onTap: _showExpenseSheet,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _sectionTitle(
                context,
                'Where Your Money Goes',
                _monthId(DateTime.now()),
              ),
              const SizedBox(height: 12),
              _insightsCard(
                monthReceived: monthReceived,
                monthSpent: monthSpent,
                previousMonthSpent: previousMonthSpent,
                highestCategory: highestCategory,
                averageDailySpent: monthSpent / now.day,
              ),
              const SizedBox(height: 12),
              _spendingSummaryCard(
                todaySpent: todaySpent,
                weekSpent: weekSpent,
                monthSpent: monthSpent,
              ),
              const SizedBox(height: 18),
              _sectionTitle(context, 'Category breakdown', 'This month'),
              const SizedBox(height: 12),
              _categorySpendingCard(
                context,
                categorySpend,
                monthSpent,
                onAdd: _showExpenseSheet,
                formatMoney: _money,
              ),
              const SizedBox(height: 22),
              _sectionTitle(
                context,
                'Budget',
                budget > 0 ? 'Edit' : 'Set budget',
                action: () => _showBudgetSheet(currentAmount: budget),
              ),
              const SizedBox(height: 12),
              _budgetCard(budget, monthSpent, budgetProgress),
              const SizedBox(height: 22),
              _sectionTitle(
                context,
                'My Savings',
                'Add goal',
                action: () => _showGoalSheet(),
              ),
              const SizedBox(height: 12),
              if (overview.savingsGoals.isEmpty)
                _emptyCard(
                  icon: Icons.savings_rounded,
                  title: 'Give your savings a purpose',
                  subtitle: 'Create a goal and track how close you get.',
                  actionLabel: 'Create a goal',
                  onAction: () => _showGoalSheet(),
                )
              else
                ...overview.savingsGoals.map(_goalCard),
              const SizedBox(height: 22),
              _sectionTitle(
                context,
                'Recent Activity',
                'View all',
                action: () => _openHistoryFromDashboard(
                  TransactionHistoryKind.all,
                  overview,
                ),
              ),
              const SizedBox(height: 12),
              if (transactions.isEmpty)
                _emptyCard(
                  icon: Icons.receipt_long_rounded,
                  title: 'Nothing to show yet',
                  subtitle: 'Add Money In or record your first expense.',
                  actionLabel: 'Add Money In',
                  onAction: _showMoneyReceivedSheet,
                )
              else
                ...transactions.map(
                  (entry) => switch (entry) {
                    Expense expense => _expenseTile(expense),
                    MoneyReceived received => _moneyReceivedTile(received),
                    _ => const SizedBox.shrink(),
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, FinanceOverview overview) {
    final palette = PennywisePalette.of(context);
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: palette.primarySoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.account_balance_wallet_rounded,
            color: palette.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PENNYWISE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.muted,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Your money, your way',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        if (widget.onOpenSettings != null)
          IconButton.filledTonal(
            tooltip: 'Settings',
            onPressed: () => widget.onOpenSettings?.call(overview),
            style: IconButton.styleFrom(
              foregroundColor: palette.primary,
              backgroundColor: palette.primarySoft,
            ),
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        IconButton.filledTonal(
          tooltip: 'Sign out',
          onPressed: _signOut,
          style: IconButton.styleFrom(
            foregroundColor: palette.text,
            backgroundColor: palette.surface,
          ),
          icon: Icon(Icons.logout_rounded),
        ),
      ],
    );
  }

  Widget _balanceCard(
    double balance,
    double received,
    double spent, {
    required VoidCallback onReceivedTap,
    required VoidCallback onSpentTap,
  }) {
    final palette = PennywisePalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: palette.gradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Available Balance',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              IconButton(
                tooltip: _amountsVisible
                    ? 'Hide Available Balance'
                    : 'Show Available Balance',
                onPressed: () =>
                    setState(() => _amountsVisible = !_amountsVisible),
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  _amountsVisible
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              _balanceMoney(balance),
              key: ValueKey(_amountsVisible),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _balanceDetail(
                  Icons.south_west_rounded,
                  'Money In',
                  _money(received),
                  accent: palette.income,
                  onTap: onReceivedTap,
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: _balanceDetail(
                  Icons.north_east_rounded,
                  'Money Out',
                  _money(spent),
                  accent: palette.expense,
                  onTap: onSpentTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceDetail(
    IconData icon,
    String label,
    String amount, {
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      amount,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: PennywisePalette.of(context).surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: PennywisePalette.of(context).text,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: PennywisePalette.of(context).muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(
    BuildContext context,
    String title,
    String trailing, {
    VoidCallback? action,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null)
          TextButton(
            onPressed: action,
            child: Text(
              trailing,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          )
        else
          Text(
            trailing,
            style: TextStyle(
              color: PennywisePalette.of(context).muted,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget _insightsCard({
    required double monthReceived,
    required double monthSpent,
    required double previousMonthSpent,
    required MapEntry<String, double>? highestCategory,
    required double averageDailySpent,
  }) {
    final comparison = previousMonthSpent == 0
        ? monthSpent == 0
              ? 'No spending this month or last month to date'
              : 'No spending last month to date'
        : monthSpent == previousMonthSpent
        ? 'Same as last month to date'
        : '${((monthSpent - previousMonthSpent).abs() / previousMonthSpent * 100).round()}% '
              '${monthSpent < previousMonthSpent ? 'lower' : 'higher'} than last month to date';
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: PennywisePalette.of(context).surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PennywisePalette.of(context).line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _insightAmount(
                  'Money In',
                  monthReceived,
                  PennywisePalette.of(context).income,
                  Icons.south_west_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 42,
                color: PennywisePalette.of(context).line,
              ),
              Expanded(
                child: _insightAmount(
                  'Money Out',
                  monthSpent,
                  PennywisePalette.of(context).expense,
                  Icons.north_east_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: PennywisePalette.of(context).line),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: PennywisePalette.of(context).primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  highestCategory == null
                      ? 'Add an expense to see your top category.'
                      : 'Highest category: ${highestCategory.key} · ${_money(highestCategory.value)}',
                  style: TextStyle(
                    color: PennywisePalette.of(context).text,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              if (monthReceived > 0)
                Text(
                  monthSpent <= monthReceived
                      ? 'On track'
                      : 'Spent more than Money In',
                  style: TextStyle(
                    color: monthSpent <= monthReceived
                        ? PennywisePalette.of(context).income
                        : PennywisePalette.of(context).expense,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 33),
            child: Text(
              comparison,
              style: TextStyle(
                color: monthSpent <= previousMonthSpent
                    ? PennywisePalette.of(context).income
                    : PennywisePalette.of(context).expense,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 33),
            child: Text(
              'Average per day: ${_money(averageDailySpent)}',
              style: TextStyle(
                color: PennywisePalette.of(context).muted,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _spendingSummaryCard({
    required double todaySpent,
    required double weekSpent,
    required double monthSpent,
  }) {
    final palette = PennywisePalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          _summaryAmount('Today', todaySpent, palette.primary),
          _summaryDivider(),
          _summaryAmount('This week', weekSpent, palette.secondary),
          _summaryDivider(),
          _summaryAmount('This month', monthSpent, palette.expense),
        ],
      ),
    );
  }

  Widget _summaryAmount(String label, double amount, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: PennywisePalette.of(context).muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _money(amount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() =>
      Container(width: 1, height: 34, color: PennywisePalette.of(context).line);

  Widget _insightAmount(
    String title,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: PennywisePalette.of(context).muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _money(amount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PennywisePalette.of(context).text,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetCard(double budget, double spent, double progress) {
    final remaining = budget - spent;
    final palette = PennywisePalette.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PennywisePalette.of(context).surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PennywisePalette.of(context).line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: PennywisePalette.of(context).warning
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.pie_chart_rounded,
                  color: PennywisePalette.of(context).warning,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget > 0 ? 'Budget' : 'No budget set',
                      style: TextStyle(
                        color: PennywisePalette.of(context).text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      budget > 0
                          ? 'Track your spending this month'
                          : 'Set a monthly limit to keep spending in check.',
                      style: TextStyle(
                        color: PennywisePalette.of(context).muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (budget > 0)
                Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    color: palette.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _budgetMetric(
                'Total budget',
                budget > 0 ? _money(budget) : 'Not set',
              ),
              _budgetMetric('Money Out', _money(spent)),
              _budgetMetric(
                'Budget Left',
                budget > 0 ? _money(remaining.clamp(0, double.infinity)) : '—',
              ),
            ],
          ),
          if (budget > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 450),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: palette.canvas,
                  valueColor: AlwaysStoppedAnimation(palette.primary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _budgetMetric(String label, String amount) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: PennywisePalette.of(context).muted,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: PennywisePalette.of(context).warning,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _goalCard(SavingsGoal goal) {
    final progress = (goal.savedAmount / goal.targetAmount)
        .clamp(0.0, 1.0)
        .toDouble();
    final remaining = (goal.targetAmount - goal.savedAmount).clamp(
      0.0,
      double.infinity,
    );
    final savingsColor = PennywisePalette.of(context).secondary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PennywisePalette.of(context).surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PennywisePalette.of(context).line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: savingsColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.savings_rounded, color: savingsColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: TextStyle(
                        color: PennywisePalette.of(context).text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_money(goal.savedAmount)} of ${_money(goal.targetAmount)}',
                      style: TextStyle(
                        color: PennywisePalette.of(context).muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (remaining == 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: savingsColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Completed',
                    style: TextStyle(
                      color: savingsColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                tooltip: 'Savings goal actions',
                onSelected: (action) {
                  if (action == 'edit') _showGoalSheet(existing: goal);
                  if (action == 'delete') {
                    _confirmDelete(
                      'Delete savings goal?',
                      'Remove "${goal.title}"?',
                      () => _deleteGoal(goal),
                    );
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Update goal')),
                  PopupMenuItem(value: 'delete', child: Text('Delete goal')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  remaining == 0
                      ? 'Goal reached!'
                      : '${_money(remaining)} left to reach your goal',
                  style: TextStyle(
                    color: remaining == 0
                        ? savingsColor
                        : PennywisePalette.of(context).muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: savingsColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 450),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 7,
                backgroundColor: PennywisePalette.of(context).canvas,
                valueColor: AlwaysStoppedAnimation(savingsColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _expenseTile(Expense expense) => _activityTile(
    title: expense.title,
    subtitle: [
      expense.displayCategory,
      if (expense.subcategory != null) expense.subcategory!,
      if (expense.transportMode != null) expense.transportMode!,
      expense.paymentMethod,
      _formatDate(expense.date),
    ].join(' · '),
    amount: '-${_money(expense.amount)}',
    icon: expense.icon,
    color: PennywisePalette.of(context).categoryColor(expense.displayCategory),
    actions: [
      PopupMenuButton<String>(
        tooltip: 'Expense actions',
        onSelected: (action) {
          if (action == 'edit') _showExpenseSheet(existing: expense);
          if (action == 'delete') {
            _confirmDelete(
              'Delete expense?',
              'Remove "${expense.title}" from your expenses?',
              () async {
                await _deleteExpense(expense);
              },
            );
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    ],
  );

  Widget _moneyReceivedTile(MoneyReceived entry) => _activityTile(
    title: entry.source,
    subtitle: 'Money In · ${entry.paymentMethod} · ${_formatDate(entry.date)}',
    amount: '+${_money(entry.amount)}',
    icon: Icons.south_west_rounded,
    color: PennywisePalette.of(context).income,
    actions: [
      PopupMenuButton<String>(
        tooltip: 'Money In actions',
        onSelected: (action) {
          if (action == 'edit') _showMoneyReceivedSheet(existing: entry);
          if (action == 'delete') {
            _confirmDelete(
              'Delete Money In entry?',
              'Remove this transfer from your records?',
              () async {
                await _deleteMoneyReceived(entry);
              },
            );
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    ],
  );

  Widget _activityTile({
    required String title,
    required String subtitle,
    required String amount,
    required IconData icon,
    required Color color,
    required List<Widget> actions,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: PennywisePalette.of(context).surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: PennywisePalette.of(context).line.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PennywisePalette.of(context).text,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PennywisePalette.of(context).muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            amount,
            style: TextStyle(
              color: amount.startsWith('+')
                  ? PennywisePalette.of(context).income
                  : PennywisePalette.of(context).text,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          ...actions,
        ],
      ),
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PennywisePalette.of(context).surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: PennywisePalette.of(context).line),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: PennywisePalette.of(context).primary),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: PennywisePalette.of(context).muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({
    required this.kind,
    required this.initialOverview,
    required this.formatMoney,
    required this.onEditExpense,
    required this.onEditMoneyReceived,
    required this.onDeleteExpense,
    required this.onDeleteMoneyReceived,
    super.key,
  });

  final TransactionHistoryKind kind;
  final FinanceOverview initialOverview;
  final String Function(double) formatMoney;
  final Future<void> Function(Expense) onEditExpense;
  final Future<void> Function(MoneyReceived) onEditMoneyReceived;
  final Future<bool> Function(Expense) onDeleteExpense;
  final Future<bool> Function(MoneyReceived) onDeleteMoneyReceived;

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  late TransactionHistoryKind _selectedKind = widget.kind;
  final _searchController = TextEditingController();
  String _selectedCategory = 'All categories';
  DateTimeRange? _dateRange;
  final Set<String> _deletedExpenseIds = {};
  final Set<String> _deletedIncomeIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _title => switch (_selectedKind) {
    TransactionHistoryKind.all => 'Money Activity',
    TransactionHistoryKind.moneyIn => 'Money In',
    TransactionHistoryKind.moneyOut => 'Money Out',
  };

  Future<void> _selectDates() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: _dateRange,
      helpText: 'Filter by date',
    );
    if (range != null && mounted) setState(() => _dateRange = range);
  }

  List<Object> _transactions(FinanceOverview overview) {
    final items = <Object>[
      if (_selectedKind != TransactionHistoryKind.moneyIn)
        ...overview.expenses.where(
          (expense) => !_deletedExpenseIds.contains(expense.id),
        ),
      if (_selectedKind != TransactionHistoryKind.moneyOut)
        ...overview.moneyReceived.where(
          (entry) => !_deletedIncomeIds.contains(entry.id),
        ),
    ];
    final query = _searchController.text.trim().toLowerCase();
    return items.where((item) {
      final date = switch (item) {
        Expense expense => expense.date,
        MoneyReceived income => income.date,
        _ => DateTime.fromMillisecondsSinceEpoch(0),
      };
      final category = switch (item) {
        Expense expense => expense.displayCategory,
        MoneyReceived _ => 'Money In',
        _ => '',
      };
      final details = switch (item) {
        Expense expense =>
          '${expense.title} ${expense.displayCategory} ${expense.paymentMethod} '
              '${expense.subcategory ?? ''} ${expense.transportMode ?? ''}',
        MoneyReceived income =>
          '${income.source} Money In ${income.paymentMethod}',
        _ => '',
      };
      final matchesSearch =
          query.isEmpty || details.toLowerCase().contains(query);
class _EditorSheet extends StatefulWidget {
  const _EditorSheet({
    required this.title,
    required this.fields,
    required this.actionLabel,
    required this.onSave,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> fields;
  final String actionLabel;
  final Future<void> Function() onSave;

  @override
  State<_EditorSheet> createState() => _EditorSheetState();
}

class _EditorSheetState extends State<_EditorSheet> {
  bool _isSaving = false;

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await widget.onSave();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      decoration: BoxDecoration(
        color: PennywisePalette.of(context).surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: PennywisePalette.of(context).line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.subtitle!,
                style: TextStyle(color: PennywisePalette.of(context).muted),
              ),
            ],
            const SizedBox(height: 18),
            ...widget.fields,
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.actionLabel),
            ),
          ],
        ),
      ),
    ),
  );
}

      final separator = _selectedCategory.indexOf(' · ');
      final matchesCategory =
          _selectedCategory == 'All categories' ||
          (separator < 0
              ? category == _selectedCategory
              : item is Expense &&
                    category == _selectedCategory.substring(0, separator) &&
                    (item.subcategory ?? item.transportMode) ==
                        _selectedCategory.substring(separator + 3));
      final range = _dateRange;
      final matchesDate =
          range == null ||
          (!date.isBefore(
                DateTime(range.start.year, range.start.month, range.start.day),
              ) &&
              date.isBefore(
                DateTime(range.end.year, range.end.month, range.end.day + 1),
              ));
      return matchesSearch && matchesCategory && matchesDate;
    }).toList()..sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));
  }

  DateTime _dateOf(Object transaction) => switch (transaction) {
    Expense expense => expense.date,
    MoneyReceived income => income.date,
    _ => DateTime.fromMillisecondsSinceEpoch(0),
  };

  String _groupName(DateTime date) {
    final now = DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return 'Earlier';
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _shortDate(DateTime date) => '${date.day}/${date.month}';

  Future<void> _edit(Object transaction) async {
    switch (transaction) {
      case Expense expense:
        await widget.onEditExpense(expense);
      case MoneyReceived income:
        await widget.onEditMoneyReceived(income);
    }
  }

  Future<void> _delete(Object transaction) async {
    final description = switch (transaction) {
      Expense expense => 'Delete "${expense.title}"?',
      MoneyReceived income =>
        'Delete this Money In entry from "${income.source}"?',
      _ => 'Delete this transaction?',
    };
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;
    var deleted = false;
    switch (transaction) {
      case Expense expense:
        deleted = await widget.onDeleteExpense(expense);
      case MoneyReceived income:
        deleted = await widget.onDeleteMoneyReceived(income);
    }
    if (deleted && mounted) {
      setState(() {
        switch (transaction) {
          case Expense expense:
            _deletedExpenseIds.add(expense.id);
          case MoneyReceived income:
            _deletedIncomeIds.add(income.id);
        }
      });
    }
  }

  Widget _filters(BuildContext context) {
    final palette = PennywisePalette.of(context);
    final categories = <String>[
      'All categories',
      if (_selectedKind != TransactionHistoryKind.moneyIn)
        ...Expense.categories,
      if (_selectedKind != TransactionHistoryKind.moneyIn) ...[
        ...Expense.transportModes.map((mode) => 'Transport · $mode'),
        ...Expense.shoppingTypes.map((type) => 'Shopping · $type'),
      ],
      if (_selectedKind == TransactionHistoryKind.all) 'Money In',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search activity',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _selectDates,
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: Text(
                  _dateRange == null
                      ? 'Dates'
                      : '${_shortDate(_dateRange!.start)} – ${_shortDate(_dateRange!.end)}',
                ),
              ),
              if (_dateRange != null)
                IconButton(
                  tooltip: 'Clear date filter',
                  onPressed: () => setState(() => _dateRange = null),
                  icon: const Icon(Icons.close_rounded),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
              ),
            ],
          ),
          if (widget.kind == TransactionHistoryKind.all) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final (kind, label) in [
                  (TransactionHistoryKind.all, 'All'),
                  (TransactionHistoryKind.moneyIn, 'Money In'),
                  (TransactionHistoryKind.moneyOut, 'Money Out'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _selectedKind == kind,
                    onSelected: (_) => setState(() {
                      _selectedKind = kind;
                      if (kind == TransactionHistoryKind.moneyIn) {
                        _selectedCategory = 'All categories';
                      }
                    }),
                    selectedColor: palette.primary,
                    labelStyle: TextStyle(
                      color: _selectedKind == kind
                          ? Colors.white
                          : palette.text,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _transactionCard(BuildContext context, Object transaction) {
    final palette = PennywisePalette.of(context);
    final (
      title,
      category,
      amount,
      icon,
      color,
      date,
      method,
    ) = switch (transaction) {
      Expense expense => (
        expense.title,
        '${expense.displayCategory}'
            '${expense.subcategory == null && expense.transportMode == null ? '' : ' · ${expense.subcategory ?? expense.transportMode}'}',
        '-${widget.formatMoney(expense.amount)}',
        expense.icon,
        palette.categoryColor(expense.displayCategory),
        expense.date,
        expense.paymentMethod,
      ),
      MoneyReceived income => (
        income.source,
        'Money In',
        '+${widget.formatMoney(income.amount)}',
        Icons.south_west_rounded,
        palette.income,
        income.date,
        income.paymentMethod,
      ),
      _ => (
        '',
        '',
        '',
        Icons.receipt_long_rounded,
        palette.muted,
        DateTime.fromMillisecondsSinceEpoch(0),
        '',
      ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$category · $method · ${_dateLabel(date)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Transaction actions',
            onSelected: (action) {
              if (action == 'edit') _edit(transaction);
              if (action == 'delete') _delete(transaction);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _historyBody(BuildContext context, FinanceOverview overview) {
    final transactions = _transactions(overview);
    if (transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.manage_search_rounded,
                size: 42,
                color: PennywisePalette.of(context).muted,
              ),
              const SizedBox(height: 10),
              Text(
                'No activity found',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Try another search or clear the filters.',
                textAlign: TextAlign.center,
                style: TextStyle(color: PennywisePalette.of(context).muted),
              ),
            ],
          ),
        ),
      );
    }

    final groups = <String, List<Object>>{};
    for (final transaction in transactions) {
      groups
          .putIfAbsent(_groupName(_dateOf(transaction)), () => [])
          .add(transaction);
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: ListView(
        key: ValueKey((
          _selectedKind,
          _selectedCategory,
          _searchController.text,
          _dateRange,
        )),
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          for (final group in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 9),
              child: Text(
                group.key,
                style: TextStyle(
                  color: PennywisePalette.of(context).muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final transaction in group.value)
              _transactionCard(context, transaction),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = PennywisePalette.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: palette.canvas,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          _filters(context),
          Expanded(child: _historyBody(context, widget.initialOverview)),
        ],
      ),
    );
  }
}
