import 'dart:async';

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
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(authService: _FakeAuthService())),
    );

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

  testWidgets(
    'login screen delegates email, Google, and phone auth to service',
    (tester) async {
      final service = _FakeAuthService();
      await tester.pumpWidget(
        MaterialApp(home: LoginScreen(authService: service)),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'person@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'safe-pass',
      );
      await tester.tap(find.text('Sign in').first);
      await tester.pumpAndSettle();
      expect(service.lastEmailSignIn, ('person@example.com', 'safe-pass'));

      await tester.ensureVisible(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(service.lastPasswordReset, 'person@example.com');
      expect(find.text('Password reset email sent.'), findsOneWidget);

      await tester.ensureVisible(find.text('New here? Create an account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New here? Create an account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account').last);
      await tester.pumpAndSettle();
      expect(service.lastAccountCreation, ('person@example.com', 'safe-pass'));

      await tester.ensureVisible(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(service.googleSignInCount, 1);

      await tester.ensureVisible(find.text('Sign in with phone instead'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in with phone instead'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone number'),
        '+15551234567',
      );
      await tester.tap(find.text('Send SMS code'));
      await tester.pumpAndSettle();
      expect(service.lastPhoneNumber, '+15551234567');
      expect(find.text('Verify code'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'SMS verification code'),
        '123456',
      );
      await tester.tap(find.text('Verify code'));
      await tester.pumpAndSettle();
      expect(service.lastPhoneVerification, ('verification-id', '123456'));
    },
  );

  testWidgets('AuthGate uses the injected authentication state stream', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authService: _FakeAuthService(isSignedIn: true),
          signedInChild: const Text('Signed-in content'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Signed-in content'), findsOneWidget);
  });

  testWidgets('login screen displays service authentication failures', (
    tester,
  ) async {
    final service = _FakeAuthService()
      ..signInError = const AuthServiceException('operation-not-allowed', null);
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(authService: service)),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'person@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'safe-pass',
    );

    await tester.tap(find.text('Sign in').first);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This sign-in method is not enabled in Firebase Authentication.',
      ),
      findsOneWidget,
    );
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

  testWidgets('dashboard keeps its Firestore stream across local rebuilds', (
    tester,
  ) async {
    final repository = _ObservedExpenseRepository(FakeFirebaseFirestore());
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseDashboard(repository: repository, userId: 'test-user'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.watchCount, 1);

    await tester.tap(find.byTooltip('Hide Available Balance'));
    await tester.pumpAndSettle();

    expect(repository.watchCount, 1);
  });

  testWidgets('dashboard retry creates a fresh Firestore subscription', (
    tester,
  ) async {
    final repository = _ObservedExpenseRepository(FakeFirebaseFirestore())
      ..failFirstWatch = true;
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseDashboard(repository: repository, userId: 'test-user'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load your finances.'), findsOneWidget);
    expect(repository.watchCount, 1);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(repository.watchCount, 2);
    expect(find.text('Available Balance'), findsOneWidget);
  });

  testWidgets('invalid finance amounts and titles are rejected before writes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreExpenseRepository(firestore: firestore);
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseDashboard(repository: repository, userId: 'test-user'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log spending'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'What did you spend on?'),
      'Test expense',
    );

    for (final amount in ['NaN', 'Infinity', '1000000001']) {
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), amount);
      await tester.ensureVisible(find.text('Save expense'));
      await tester.tap(find.text('Save expense'));
      await tester.pumpAndSettle();
      expect(find.textContaining('valid amount'), findsOneWidget);
    }

    await tester.enterText(
      find.widgetWithText(TextField, 'What did you spend on?'),
      List.filled(121, 'x').join(),
    );
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '100');
    await tester.ensureVisible(find.text('Save expense'));
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(find.textContaining('up to 120 characters'), findsOneWidget);

    final expenses = await firestore
        .collection('users')
        .doc('test-user')
        .collection('expenses')
        .get();
    expect(expenses.docs, isEmpty);
  });

  testWidgets('save action stays disabled until expense write completes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final firestore = FakeFirebaseFirestore();
    final repository = _ObservedExpenseRepository(firestore)
      ..expenseWriteGate = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseDashboard(repository: repository, userId: 'test-user'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log spending'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'What did you spend on?'),
      'One expense',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '25');
    await tester.ensureVisible(find.text('Save expense'));
    await tester.tap(find.text('Save expense'));
    await tester.pump();

    expect(repository.expenseAddCount, 1);
    expect(
      tester.widgetList<FilledButton>(find.byType(FilledButton)).last.onPressed,
      isNull,
    );

    repository.expenseWriteGate!.complete();
    await tester.pumpAndSettle();
    final expenses = await firestore
        .collection('users')
        .doc('test-user')
        .collection('expenses')
        .get();
    expect(expenses.docs, hasLength(1));
  });

  testWidgets('transaction retries reuse IDs after an ambiguous timeout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final firestore = FakeFirebaseFirestore();
    final repository = _CommitThenTimeoutRepository(firestore);
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseDashboard(repository: repository, userId: 'test-user'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log spending'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'What did you spend on?'),
      'Retry expense',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '35');
    await tester.ensureVisible(find.text('Save expense'));
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not save expense'), findsOneWidget);
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(repository.expenseIds, hasLength(2));
    expect(repository.expenseIds[0], repository.expenseIds[1]);
    expect(
      (await firestore
              .collection('users')
              .doc('test-user')
              .collection('expenses')
              .get())
          .docs,
      hasLength(1),
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Money In'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'From'), 'Parents');
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '500');
    await tester.ensureVisible(find.text('Save Money In'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Money In'));
    await tester.pumpAndSettle();
    expect(repository.moneyReceivedIds, hasLength(1));
    expect(find.text('Save Money In'), findsOneWidget);
    expect(find.textContaining('Could not save transfer'), findsOneWidget);
    await tester.tap(find.text('Save Money In'));
    await tester.pumpAndSettle();
    expect(repository.moneyReceivedIds, hasLength(2));
    expect(repository.moneyReceivedIds[0], repository.moneyReceivedIds[1]);
    expect(
      (await firestore
              .collection('users')
              .doc('test-user')
              .collection('moneyReceived')
              .get())
          .docs,
      hasLength(1),
    );
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
    final investment = Expense(
      id: 'investment',
      title: 'Index fund',
      category: 'Investments',
      subcategory: 'ETFs',
      amount: 800,
      date: DateTime(2026, 11, 12),
    );
    expect(Expense.categories, contains('Investments'));
    expect(Expense.investmentTypes, [
      'SIP',
      'Stocks',
      'Mutual Funds',
      'Gold',
      'ETFs',
      'Bonds',
      'Other Investments',
    ]);
    expect(investment.icon, Icons.trending_up_rounded);
    expect(investment.toFirestore()['subcategory'], 'ETFs');
    expect(
      Expense.fromFirestore('investment', investment.toFirestore()).subcategory,
      'ETFs',
    );
    expect(
      buildAppTheme().extension<PennywisePalette>()!.categoryColor(
        'Investments',
      ),
      isNot(buildAppTheme().extension<PennywisePalette>()!.muted),
    );
    expect(Expense.transportModes, contains('Bike'));
  });

  testWidgets('Investments can be added, edited, filtered and counted', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FirestoreExpenseRepository(
      firestore: FakeFirebaseFirestore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseDashboard(repository: repository, userId: 'investor'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log spending'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Investments').last);
    await tester.pumpAndSettle();

    for (final type in Expense.investmentTypes) {
      expect(find.text(type), findsOneWidget);
    }
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'ETFs'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'ETFs'));
    await tester.enterText(
      find.widgetWithText(TextField, 'What did you spend on?'),
      'Index fund',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '800');
    await tester.scrollUntilVisible(
      find.text('Save expense'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    expect(
      find.text('Highest category: Investments · ₹800.00'),
      findsOneWidget,
    );
    expect(find.text('₹800.00'), findsWidgets);
    expect(find.textContaining('Investments · ETFs'), findsOneWidget);

    await tester.ensureVisible(find.text('Index fund'));
    await tester.tap(find.byTooltip('Expense actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Bonds'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bonds'));
    await tester.scrollUntilVisible(
      find.text('Save changes'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Investments · Bonds'), findsOneWidget);

    await tester.ensureVisible(find.text('View all'));
    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Investments · Bonds'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Investments · Bonds').last);
    await tester.pumpAndSettle();
    expect(find.text('Index fund'), findsOneWidget);
  });

  testWidgets('switching Shopping and Investments resets subcategory', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FirestoreExpenseRepository(
      firestore: FakeFirebaseFirestore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseDashboard(repository: repository, userId: 'investor'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log spending'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Shopping').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Clothes & Footwear'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Investments').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'SIP'))
          .selected,
      isTrue,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'What did you spend on?'),
      'SIP contribution',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '1000');
    await tester.ensureVisible(find.text('Save expense'));
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Investments · SIP'), findsOneWidget);

    await tester.tap(find.text('Log spending'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Investments').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Shopping').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'General Shopping'),
          )
          .selected,
      isTrue,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'What did you spend on?'),
      'General purchase',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '50');
    await tester.ensureVisible(find.text('Save expense'));
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Shopping · General Shopping'), findsOneWidget);
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
      Expense(
        id: 'investment',
        title: 'Index fund',
        category: 'Investments',
        subcategory: 'ETFs',
        amount: 800,
        date: DateTime(2026, 11, 12),
      ),
    ];
    final comparison = compareExpenseMonths(expenses, DateTime(2026, 11));
    expect(comparison.currentTotal, 2000);
    expect(comparison.previousTotal, 300);
    expect(comparison.currentCategories['Investments'], 800);
    expect(comparison.difference, 1700);
    expect(comparison.percentageChange, closeTo(566.67, 0.01));

    final csv = buildMonthlyCsv(
      month: DateTime(2026, 11),
      expenses: [expenses.first, expenses.last],
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
    expect(csv, contains('"Investments"'));
    expect(csv, contains('"ETFs"'));
    expect(csv, contains('"₹800.00"'));
    expect(csv, contains('"Money In"'));
    expect(csv, contains('"₹5000.00"'));
    expect(csv, contains('"Shoes, new"'));
    expect(csv, contains('"₹3800.00"'));

    final excelBytes = buildMonthlyExcelReport(
      month: DateTime(2026, 11),
      expenses: [expenses.first, expenses.last],
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
    expect(
      workbook.tables['Monthly report']!.rows
          .expand((row) => row)
          .whereType<Data>()
          .any((cell) => cell.value.toString().contains('Investments')),
      isTrue,
    );
  });

  test(
    'monthly comparison handles January rollover and empty prior months',
    () {
      final januaryExpense = Expense(
        id: 'january',
        title: 'January purchase',
        category: 'Food',
        amount: 120,
        date: DateTime(2027, 1, 3),
      );
      final decemberExpense = Expense(
        id: 'december',
        title: 'December purchase',
        category: 'Food',
        amount: 80,
        date: DateTime(2026, 12, 31),
      );

      final comparison = compareExpenseMonths([
        januaryExpense,
        decemberExpense,
      ], DateTime(2027, 1));
      expect(comparison.currentTotal, 120);
      expect(comparison.previousMonth, DateTime(2026, 12));
      expect(comparison.previousTotal, 80);
      expect(comparison.percentageChange, 50);

      final noPriorMonth = compareExpenseMonths([
        januaryExpense,
      ], DateTime(2027, 1));
      expect(noPriorMonth.previousTotal, 0);
      expect(noPriorMonth.percentageChange, isNull);
    },
  );
}

class _ObservedExpenseRepository extends FirestoreExpenseRepository {
  _ObservedExpenseRepository(FakeFirebaseFirestore firestore)
    : super(firestore: firestore);

  int watchCount = 0;
  int expenseAddCount = 0;
  Completer<void>? expenseWriteGate;
  bool failFirstWatch = false;

  @override
  Stream<FinanceOverview> watchFinance(String userId, DateTime month) {
    watchCount++;
    if (failFirstWatch && watchCount == 1) {
      return Stream<FinanceOverview>.error(StateError('offline'));
    }
    return super.watchFinance(userId, month);
  }

  @override
  Future<String> addExpense(String userId, Expense expense) async {
    expenseAddCount++;
    final gate = expenseWriteGate;
    if (gate != null) await gate.future;
    return super.addExpense(userId, expense);
  }
}

class _CommitThenTimeoutRepository extends FirestoreExpenseRepository {
  _CommitThenTimeoutRepository(FakeFirebaseFirestore firestore)
    : super(firestore: firestore);

  bool _failExpenseOnce = true;
  bool _failMoneyReceivedOnce = true;
  final List<String> expenseIds = [];
  final List<String> moneyReceivedIds = [];

  @override
  Future<String> addExpense(String userId, Expense expense) async {
    expenseIds.add(expense.id);
    final id = await super.addExpense(userId, expense);
    if (_failExpenseOnce) {
      _failExpenseOnce = false;
      throw StateError('simulated response timeout after commit');
    }
    return id;
  }

  @override
  Future<String> addMoneyReceived(
    String userId,
    MoneyReceived moneyReceived,
  ) async {
    moneyReceivedIds.add(moneyReceived.id);
    final id = await super.addMoneyReceived(userId, moneyReceived);
    if (_failMoneyReceivedOnce) {
      _failMoneyReceivedOnce = false;
      throw StateError('simulated response timeout after commit');
    }
    return id;
  }
}

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.isSignedIn = false});

  final bool isSignedIn;

  @override
  Stream<bool> get signedInChanges => Stream<bool>.value(isSignedIn);

  (String, String)? lastAccountCreation;
  (String, String)? lastEmailSignIn;
  (String, String)? lastPhoneVerification;
  String? lastPhoneNumber;
  String? lastPasswordReset;
  int googleSignInCount = 0;
  AuthServiceException? signInError;

  @override
  Future<void> createAccount(String email, String password) async {
    lastAccountCreation = (email, password);
  }

  @override
  Future<void> signInWithEmail(String email, String password) async {
    lastEmailSignIn = (email, password);
    final error = signInError;
    if (error != null) throw error;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    lastPasswordReset = email;
  }

  @override
  Future<void> signInWithGoogle() async {
    googleSignInCount++;
  }

  @override
  Future<void> sendPhoneCode({
    required String phoneNumber,
    required int? forceResendingToken,
    required PhoneCodeSentCallback onCodeSent,
    required PhoneAuthErrorCallback onError,
    required void Function(String verificationId) onAutoRetrievalTimeout,
  }) async {
    lastPhoneNumber = phoneNumber;
    onCodeSent('verification-id', 7);
  }

  @override
  Future<void> verifyPhoneCode(String verificationId, String smsCode) async {
    lastPhoneVerification = (verificationId, smsCode);
  }
}
