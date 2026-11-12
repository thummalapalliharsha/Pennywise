import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_app/app_theme.dart';
import 'package:my_first_app/auth_flow.dart';
import 'package:my_first_app/expense.dart';
import 'package:my_first_app/expense_repository.dart';
import 'package:my_first_app/finance_features.dart';
import 'package:my_first_app/finance_screens.dart';
import 'package:my_first_app/main.dart';

void main() {
  test('Ocean Blue is the sole built-in theme', () {
    expect(PennywiseTheme.values, [PennywiseTheme.oceanBlue]);
    final theme = buildAppTheme();
    final palette = theme.extension<PennywisePalette>();
    expect(palette, isNotNull);
    expect(palette!.surface, isNot(palette.canvas));
    expect(palette.income, isNot(palette.expense));
  });

  testWidgets('shows setup steps when Firebase is not configured', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MyApp(firebaseInitializationError: 'Firebase app is missing'),
    );

    expect(find.text('Firebase is not configured'), findsOneWidget);
    expect(find.textContaining('flutterfire configure'), findsOneWidget);
    expect(find.text('Firebase app is missing'), findsOneWidget);
  });

  testWidgets('login screen switches to phone verification mode', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Personal Expense Tracker'), findsOneWidget);
    expect(find.text('Sign in to your account'), findsOneWidget);

    await tester.ensureVisible(find.text('Sign in with phone instead'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with phone instead'));
    await tester.pumpAndSettle();

    expect(find.text('Continue with phone'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Send SMS code'), findsOneWidget);
  });

  testWidgets('tracks received money, expenses, budget, and savings goals', (
    tester,
  ) async {
    final repository = FirestoreExpenseRepository(
      firestore: FakeFirebaseFirestore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseDashboard(repository: repository, userId: 'test-user'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PENNYWISE'), findsOneWidget);
    expect(find.text('Available Balance'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('This month'), findsWidgets);
    expect(find.byTooltip('Hide Available Balance'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide Available Balance'));
    await tester.pumpAndSettle();
    expect(find.text('₹••••••'), findsOneWidget);
    expect(find.text('₹0.00'), findsWidgets);
    await tester.tap(find.byTooltip('Show Available Balance'));
    await tester.pumpAndSettle();
    expect(find.text('₹0.00'), findsWidgets);

    await tester.tap(find.text('Add Money In').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'From'),
      'From parents',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '3200');
    await tester.tap(find.text('Save Money In'));
    await tester.pumpAndSettle();
    expect(find.text('+₹3200.00'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide Available Balance'));
    await tester.pumpAndSettle();
    expect(find.text('₹••••••'), findsOneWidget);
    expect(find.text('₹3200.00'), findsWidgets);
    await tester.tap(find.byTooltip('Show Available Balance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Money In').first);
    await tester.pumpAndSettle();
    expect(find.text('Money In'), findsWidgets);
    expect(find.text('From parents'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log spending'));
    await tester.pumpAndSettle();
    expect(find.text('Repeat this expense'), findsNothing);
    expect(find.text('PG/Rent'), findsWidgets);
    expect(find.text('Bills & Recharge'), findsWidgets);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Transport').last);
    await tester.pumpAndSettle();
    expect(find.text('Bus'), findsOneWidget);
    expect(find.text('Metro'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('Cab'), findsOneWidget);
    expect(find.text('Bike'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Cab'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'What did you spend on?'),
      'Cab home',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '320');
    await tester.ensureVisible(find.text('Save expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(find.text('-₹320.00'), findsOneWidget);
    expect(find.text('Highest category: Transport · ₹320.00'), findsOneWidget);
    await tester.tap(find.text('Money Out').first);
    await tester.pumpAndSettle();
    expect(find.text('Money Out'), findsWidgets);
    expect(find.text('Cab home'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Budget'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set budget'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Monthly limit'),
      '400',
    );
    await tester.tap(find.text('Save budget'));
    await tester.pumpAndSettle();
    expect(find.text('Budget Left'), findsOneWidget);
    expect(find.text('₹80.00'), findsWidgets);
    expect(find.textContaining('You have used'), findsNothing);

    await tester.ensureVisible(find.text('My Savings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add goal'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'What are you saving for?'),
      'New laptop',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Goal amount'),
      '50000',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Already saved'),
      '5000',
    );
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();
    expect(find.text('New laptop'), findsOneWidget);
    expect(find.text('10%'), findsOneWidget);
    expect(find.text('₹45000.00 left to reach your goal'), findsOneWidget);
    await tester.tap(find.byTooltip('Savings goal actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update goal'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Already saved'),
      '50000',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);

    await tester.ensureVisible(find.text('Recent Activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Expense actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'What did you spend on?'),
      'Dinner',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '450');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('-₹450.00'), findsOneWidget);
    expect(find.textContaining('Monthly budget exhausted'), findsNothing);

    await tester.tap(find.byTooltip('Expense actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Dinner'), findsNothing);
  });

  testWidgets('shows five latest dashboard transactions and full history', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.now();
    final expenses = firestore
        .collection('users')
        .doc('test-user')
        .collection('expenses');
    for (var index = 0; index < 6; index++) {
      await expenses.doc('expense-$index').set({
        'title': 'Expense $index',
        'category': 'Food',
        'amount': 10 + index,
        'date': now.subtract(Duration(days: 5 - index)),
      });
    }

    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseDashboard(
          repository: FirestoreExpenseRepository(firestore: firestore),
          userId: 'test-user',
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var index = 1; index < 6; index++) {
      expect(find.text('Expense $index'), findsOneWidget);
    }
    expect(find.text('Expense 0'), findsNothing);

    await tester.ensureVisible(find.text('View all'));
    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();
    expect(find.text('Money Activity'), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Yesterday'), findsWidgets);
    expect(find.text('Earlier'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'Expense 0');
    await tester.pumpAndSettle();
    expect(find.text('Expense 0'), findsWidgets);
    expect(find.text('Expense 5'), findsNothing);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();
    expect(find.text('Expense 5'), findsOneWidget);

    await tester.tap(find.byTooltip('Transaction actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'What did you spend on?'),
      'Edited purchase',
    );
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Edited purchase'), findsOneWidget);

    await tester.ensureVisible(find.text('Edited purchase'));
    await tester.tap(find.byTooltip('Expense actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Edited purchase'), findsNothing);
  });

  test(
    'Firestore repository saves records under the requested user UID',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreExpenseRepository(firestore: firestore);
      await firestore
          .collection('users')
          .doc('alice')
          .collection('expenses')
          .doc('legacy')
          .set({
            'title': 'Older expense',
            'category': 'Food',
            'amount': 75,
            'date': DateTime.utc(2026, 11, 10),
            'recurringScheduleId': 'old-schedule',
            'isRecurringGenerated': true,
          });
      final expense = Expense(
        id: '',
        title: 'Coffee',
        category: 'Food',
        amount: 125,
        date: DateTime.utc(2026, 11, 11),
        paymentMethod: 'UPI',
      );

      final expenseId = await repository.addExpense('alice', expense);
      await repository.updateExpense(
        'alice',
        Expense(
          id: expenseId,
          title: 'Coffee and snack',
          category: 'Food',
          amount: 180,
          date: expense.date,
          paymentMethod: 'Card',
        ),
      );
      final incomeId = await repository.addMoneyReceived(
        'alice',
        MoneyReceived(
          id: '',
          source: 'From parents',
          amount: 3000,
          date: expense.date,
          paymentMethod: 'UPI',
        ),
      );
      await repository.updateMoneyReceived(
        'alice',
        MoneyReceived(
          id: incomeId,
          source: 'From parents',
          amount: 3500,
          date: expense.date,
          paymentMethod: 'Cash',
        ),
      );
      await repository.setMonthlyBudget('alice', DateTime(2026, 11), 8000);
      final goalId = await repository.addSavingsGoal(
        'alice',
        SavingsGoal(
          id: '',
          title: 'Laptop',
          targetAmount: 50000,
          savedAmount: 5000,
          createdAt: expense.date,
        ),
      );
      await repository.updateSavingsGoal(
        'alice',
        SavingsGoal(
          id: goalId,
          title: 'Laptop',
          targetAmount: 60000,
          savedAmount: 5500,
          createdAt: expense.date,
        ),
      );

      final alice = await repository
          .watchFinance('alice', DateTime(2026, 11))
          .first;
      final bob = await repository
          .watchFinance('bob', DateTime(2026, 11))
          .first;
      expect(alice.expenses, hasLength(2));
      final updatedExpense = alice.expenses.firstWhere(
        (item) => item.id == expenseId,
      );
      expect(updatedExpense.title, 'Coffee and snack');
      expect(updatedExpense.paymentMethod, 'Card');
      final legacyExpense = alice.expenses.firstWhere(
        (item) => item.id == 'legacy',
      );
      expect(legacyExpense.paymentMethod, 'Other');
      expect(legacyExpense.displayCategory, 'Food');
      await repository.updateExpense(
        'alice',
        Expense(
          id: legacyExpense.id,
          title: 'Older expense edited',
          category: legacyExpense.category,
          amount: legacyExpense.amount,
          date: legacyExpense.date,
        ),
      );
      final preservedLegacy = await firestore
          .collection('users')
          .doc('alice')
          .collection('expenses')
          .doc('legacy')
          .get();
      expect(preservedLegacy.data()!['recurringScheduleId'], 'old-schedule');
      expect(preservedLegacy.data()!['isRecurringGenerated'], isTrue);
      expect(
        Expense(
          id: 'legacy-bills',
          title: 'Phone top up',
          category: 'Bills',
          amount: 50,
          date: expense.date,
        ).displayCategory,
        'Bills & Recharge',
      );
      expect(alice.moneyReceived.single.amount, 3500);
      expect(alice.moneyReceived.single.paymentMethod, 'Cash');
      expect(alice.monthlyBudget.amount, 8000);
      expect(alice.savingsGoals.single.title, 'Laptop');
      expect(alice.savingsGoals.single.savedAmount, 5500);
      expect(bob.expenses, isEmpty);
      expect(bob.moneyReceived, isEmpty);
      expect(bob.monthlyBudget.amount, 0);
      expect(bob.savingsGoals, isEmpty);

      await repository.deleteExpense('alice', expenseId);
      expect(
        (await repository.watchFinance('alice', DateTime(2026, 11)).first)
            .expenses,
        hasLength(1),
      );
      await repository.deleteMoneyReceived('alice', incomeId);
      await repository.deleteSavingsGoal('alice', goalId);
      final afterDelete = await repository
          .watchFinance('alice', DateTime(2026, 11))
          .first;
      expect(afterDelete.moneyReceived, isEmpty);
      expect(afterDelete.savingsGoals, isEmpty);
    },
  );

  test('expense subcategories remain optional for legacy documents', () {
    final oldExpense = Expense.fromFirestore('old', {
      'title': 'Old purchase',
      'category': 'Shopping',
      'amount': 25,
      'date': DateTime(2026, 11, 1),
    });

    expect(oldExpense.subcategory, isNull);

    final shopping = Expense(
      id: 'new',
      title: 'Shoes',
      category: 'Shopping',
      subcategory: 'Clothes & Footwear',
      amount: 1500,
      date: DateTime(2026, 11, 2),
    );
    expect(shopping.toFirestore()['subcategory'], 'Clothes & Footwear');
    expect(shopping.icon, Icons.checkroom_rounded);
    expect(Expense.transportModes, contains('Bike'));
  });

  testWidgets('Shopping subcategory can be added, edited, and viewed', (
    tester,
  ) async {
    final repository = FirestoreExpenseRepository(
      firestore: FakeFirebaseFirestore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseDashboard(repository: repository, userId: 'shopper'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log spending'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Shopping').last);
    await tester.pumpAndSettle();
    expect(find.text('General Shopping'), findsOneWidget);
    expect(find.text('Clothes & Footwear'), findsOneWidget);
    expect(find.text('Electronics'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Clothes & Footwear'));
    await tester.enterText(
      find.widgetWithText(TextField, 'What did you spend on?'),
      'Shoes',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '1500');
    await tester.ensureVisible(find.text('Save expense'));
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Clothes & Footwear'), findsOneWidget);

    await tester.ensureVisible(find.text('Shoes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Expense actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Electronics'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Electronics'));
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Electronics'), findsOneWidget);

    await repository.addExpense(
      'shopper',
      Expense(
        id: '',
        title: 'Bike ride',
        category: 'Transport',
        transportMode: 'Bike',
        amount: 200,
        date: DateTime.now(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View all'));
    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Transport · Bike'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Transport · Bike').last);
    await tester.pumpAndSettle();
    expect(find.text('Bike ride'), findsOneWidget);
    expect(find.text('Shoes'), findsNothing);
  });

  test('monthly comparison and CSV report use selected Firestore entries', () {
    final expenses = [
      Expense(
        id: 'current',
        title: 'Shoes, new',
        category: 'Shopping',
        subcategory: 'Clothes & Footwear',
        amount: 1200,
        date: DateTime(2026, 11, 3),
      ),
      Expense(
        id: 'previous',
        title: 'Bus',
        category: 'Transport',
        transportMode: 'Bus',
        amount: 300,
        date: DateTime(2026, 10, 3),
      ),
    ];
    final comparison = compareExpenseMonths(expenses, DateTime(2026, 11));
    expect(comparison.currentTotal, 1200);
    expect(comparison.previousTotal, 300);
    expect(comparison.difference, 900);
    expect(comparison.percentageChange, 300);

    final csv = buildMonthlyCsv(
      month: DateTime(2026, 11),
      expenses: [expenses.first],
      moneyReceived: [
        MoneyReceived(
          id: 'income',
          source: 'From parents',
          amount: 5000,
          date: DateTime(2026, 11, 1),
          paymentMethod: 'UPI',
        ),
      ],
      closingBalance: 3800,
    );
    expect(csv, contains('"Clothes & Footwear"'));
    expect(csv, contains('"Money In"'));
    expect(csv, contains('"₹5000.00"'));
    expect(csv, contains('"Shoes, new"'));
    expect(csv, contains('"₹3800.00"'));

    final excelBytes = buildMonthlyExcelReport(
      month: DateTime(2026, 11),
      expenses: [expenses.first],
      moneyReceived: const [],
      closingBalance: 3800,
    );
    final workbook = Excel.decodeBytes(excelBytes);
    expect(workbook.tables, contains('Monthly report'));
    expect(
      workbook.tables['Monthly report']!.rows
          .expand((row) => row)
          .whereType<Data>()
          .any((cell) => cell.value.toString().contains('Clothes & Footwear')),
      isTrue,
    );
  });
}
