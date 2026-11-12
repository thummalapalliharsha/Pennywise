import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

import 'expense.dart';

abstract interface class ExpenseRepository {
  Stream<FinanceOverview> watchFinance(String userId, DateTime month);

  Future<String> addExpense(String userId, Expense expense);

  Future<void> updateExpense(String userId, Expense expense);

  Future<void> deleteExpense(String userId, String expenseId);

  Future<String> addMoneyReceived(String userId, MoneyReceived moneyReceived);

  Future<void> updateMoneyReceived(String userId, MoneyReceived moneyReceived);

  Future<void> deleteMoneyReceived(String userId, String moneyReceivedId);

  Future<void> setMonthlyBudget(String userId, DateTime month, double amount);

  Future<String> addSavingsGoal(String userId, SavingsGoal goal);

  Future<void> updateSavingsGoal(String userId, SavingsGoal goal);

  Future<void> deleteSavingsGoal(String userId, String goalId);
}

class FirestoreExpenseRepository implements ExpenseRepository {
  FirestoreExpenseRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _user(String userId) {
    if (userId.isEmpty || userId.contains('/')) {
      throw ArgumentError.value(userId, 'userId', 'Must be a non-empty UID.');
    }
    return _firestore.collection('users').doc(userId);
  }

  CollectionReference<Map<String, dynamic>> _expenses(String userId) =>
      _user(userId).collection('expenses');

  CollectionReference<Map<String, dynamic>> _income(String userId) =>
      _user(userId).collection('moneyReceived');

  CollectionReference<Map<String, dynamic>> _savingsGoals(String userId) =>
      _user(userId).collection('savingsGoals');

  String _monthId(DateTime month) =>
      '${month.year.toString().padLeft(4, '0')}-'
      '${month.month.toString().padLeft(2, '0')}';

  DocumentReference<Map<String, dynamic>> _budget(
    String userId,
    DateTime month,
  ) => _user(userId).collection('monthlyBudgets').doc(_monthId(month));

  @override
  Stream<FinanceOverview> watchFinance(String userId, DateTime month) {
    final expenses = _expenses(userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) =>
                    Expense.fromFirestore(document.id, document.data()),
              )
              .toList(),
        );
    final income = _income(userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) =>
                    MoneyReceived.fromFirestore(document.id, document.data()),
              )
              .toList(),
        );
    final budget = _budget(userId, month).snapshots().map(
      (snapshot) => MonthlyBudget.fromFirestore(snapshot.data()),
    );
    final goals = _savingsGoals(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) =>
                    SavingsGoal.fromFirestore(document.id, document.data()),
              )
              .toList(),
        );
    return Rx.combineLatest4(
      expenses,
      income,
      budget,
      goals,
      (expenses, income, budget, goals) => FinanceOverview(
        expenses: expenses,
        moneyReceived: income,
        monthlyBudget: budget,
        savingsGoals: goals,
      ),
    );
  }

  @override
  Future<String> addExpense(String userId, Expense expense) async {
    final document = await _expenses(userId).add(expense.toFirestore());
    return document.id;
  }

  @override
  Future<void> updateExpense(String userId, Expense expense) {
    final data = Map<String, Object?>.from(expense.toFirestore());
    for (final field in ['transportMode', 'subcategory']) {
      if (!data.containsKey(field)) data[field] = FieldValue.delete();
    }
    return _expenses(userId).doc(expense.id).update(data);
  }

  @override
  Future<void> deleteExpense(String userId, String expenseId) {
    return _expenses(userId).doc(expenseId).delete();
  }

  @override
  Future<String> addMoneyReceived(
    String userId,
    MoneyReceived moneyReceived,
  ) async {
    final document = await _income(userId).add(moneyReceived.toFirestore());
    return document.id;
  }

  @override
  Future<void> updateMoneyReceived(String userId, MoneyReceived moneyReceived) {
    return _income(userId)
        .doc(moneyReceived.id)
        .update(moneyReceived.toFirestore());
  }

  @override
  Future<void> deleteMoneyReceived(String userId, String moneyReceivedId) {
    return _income(userId).doc(moneyReceivedId).delete();
  }

  @override
  Future<void> setMonthlyBudget(String userId, DateTime month, double amount) {
    return _budget(
      userId,
      month,
    ).set({'amount': amount, 'updatedAt': DateTime.now()});
  }

  @override
  Future<String> addSavingsGoal(String userId, SavingsGoal goal) async {
    final document = await _savingsGoals(userId).add(goal.toFirestore());
    return document.id;
  }

  @override
  Future<void> updateSavingsGoal(String userId, SavingsGoal goal) {
    return _savingsGoals(userId).doc(goal.id).update(goal.toFirestore());
  }

  @override
  Future<void> deleteSavingsGoal(String userId, String goalId) {
    return _savingsGoals(userId).doc(goalId).delete();
  }
}
