import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  static const categories = [
    'Food',
    'PG/Rent',
    'Transport',
    'Shopping',
    'Entertainment/Movies',
    'Bills & Recharge',
    'Personal Care',
    'Health',
    'Education',
    'Social & Outings',
    'Travel',
    'Others',
  ];

  static const transportModes = ['Bus', 'Metro', 'Auto', 'Cab', 'Bike'];
  static const shoppingTypes = [
    'General Shopping',
    'Clothes & Footwear',
    'Electronics',
    'Accessories',
    'Household Items',
  ];

  const Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    this.paymentMethod = 'Other',
    this.transportMode,
    this.subcategory,
  });

  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final String paymentMethod;
  final String? transportMode;
  final String? subcategory;

  String get displayCategory =>
      category == 'Bills' ? 'Bills & Recharge' : category;

  IconData get icon => switch (category) {
    'Food' => Icons.restaurant_rounded,
    'PG/Rent' => Icons.home_rounded,
    'Transport' => switch (transportMode) {
      'Bus' => Icons.directions_bus_rounded,
      'Metro' => Icons.subway_rounded,
      'Auto' => Icons.electric_rickshaw_rounded,
      'Cab' => Icons.local_taxi_rounded,
      'Bike' => Icons.two_wheeler_rounded,
      _ => Icons.directions_transit_rounded,
    },
    'Shopping' => switch (subcategory) {
      'Clothes & Footwear' => Icons.checkroom_rounded,
      'Electronics' => Icons.devices_rounded,
      'Accessories' => Icons.watch_rounded,
      'Household Items' => Icons.chair_alt_rounded,
      _ => Icons.shopping_bag_rounded,
    },
    'Entertainment/Movies' => Icons.movie_rounded,
    'Bills' || 'Bills & Recharge' => Icons.receipt_long_rounded,
    'Personal Care' => Icons.spa_rounded,
    'Health' => Icons.local_hospital_rounded,
    'Education' => Icons.school_rounded,
    'Social & Outings' => Icons.groups_rounded,
    'Travel' => Icons.flight_takeoff_rounded,
    _ => Icons.more_horiz_rounded,
  };

  factory Expense.fromFirestore(String id, Map<String, dynamic> data) {
    final title = data['title'];
    final category = data['category'];
    final amount = data['amount'];
    final date = data['date'];
    final transportMode = data['transportMode'];
    final subcategory = data['subcategory'];
    if (title is! String ||
        category is! String ||
        amount is! num ||
        (date is! Timestamp && date is! DateTime) ||
        (transportMode != null && transportMode is! String) ||
        (subcategory != null && subcategory is! String)) {
      throw const FormatException('Expense document has invalid fields.');
    }

    return Expense(
      id: id,
      title: title,
      category: category,
      amount: amount.toDouble(),
      date: date is Timestamp ? date.toDate() : date as DateTime,
      paymentMethod: data['paymentMethod'] as String? ?? 'Other',
      transportMode: transportMode as String?,
      subcategory: subcategory as String?,
    );
  }

  Map<String, Object?> toFirestore() => {
    'title': title,
    'category': category,
    'amount': amount,
    'date': date,
    'paymentMethod': paymentMethod,
    if (transportMode != null) 'transportMode': transportMode,
    if (subcategory != null) 'subcategory': subcategory,
  };
}

class MoneyReceived {
  const MoneyReceived({
    required this.id,
    required this.source,
    required this.amount,
    required this.date,
    required this.paymentMethod,
  });

  final String id;
  final String source;
  final double amount;
  final DateTime date;
  final String paymentMethod;

  factory MoneyReceived.fromFirestore(String id, Map<String, dynamic> data) {
    final source = data['source'];
    final amount = data['amount'];
    final date = data['date'];
    final paymentMethod = data['paymentMethod'];
    if (source is! String ||
        amount is! num ||
        (date is! Timestamp && date is! DateTime) ||
        paymentMethod is! String) {
      throw const FormatException(
        'Money received document has invalid fields.',
      );
    }

    return MoneyReceived(
      id: id,
      source: source,
      amount: amount.toDouble(),
      date: date is Timestamp ? date.toDate() : date as DateTime,
      paymentMethod: paymentMethod,
    );
  }

  Map<String, Object> toFirestore() => {
    'source': source,
    'amount': amount,
    'date': date,
    'paymentMethod': paymentMethod,
  };
}

class MonthlyBudget {
  const MonthlyBudget({required this.amount, required this.updatedAt});

  final double amount;
  final DateTime updatedAt;

  factory MonthlyBudget.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return MonthlyBudget.empty;
    final amount = data['amount'];
    final updatedAt = data['updatedAt'];
    if (amount is! num || (updatedAt is! Timestamp && updatedAt is! DateTime)) {
      throw const FormatException(
        'Monthly budget document has invalid fields.',
      );
    }
    return MonthlyBudget(
      amount: amount.toDouble(),
      updatedAt: updatedAt is Timestamp
          ? updatedAt.toDate()
          : updatedAt as DateTime,
    );
  }

  static final empty = MonthlyBudget(amount: 0, updatedAt: nullDate);
  static final nullDate = DateTime.fromMillisecondsSinceEpoch(0);

  Map<String, Object> toFirestore() => {
    'amount': amount,
    'updatedAt': updatedAt,
  };
}

class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.savedAmount,
    required this.createdAt,
  });

  final String id;
  final String title;
  final double targetAmount;
  final double savedAmount;
  final DateTime createdAt;

  factory SavingsGoal.fromFirestore(String id, Map<String, dynamic> data) {
    final title = data['title'];
    final targetAmount = data['targetAmount'];
    final savedAmount = data['savedAmount'];
    final createdAt = data['createdAt'];
    if (title is! String ||
        targetAmount is! num ||
        savedAmount is! num ||
        (createdAt is! Timestamp && createdAt is! DateTime)) {
      throw const FormatException('Savings goal document has invalid fields.');
    }
    return SavingsGoal(
      id: id,
      title: title,
      targetAmount: targetAmount.toDouble(),
      savedAmount: savedAmount.toDouble(),
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : createdAt as DateTime,
    );
  }

  Map<String, Object> toFirestore() => {
    'title': title,
    'targetAmount': targetAmount,
    'savedAmount': savedAmount,
    'createdAt': createdAt,
  };
}

class FinanceOverview {
  const FinanceOverview({
    required this.expenses,
    required this.moneyReceived,
    required this.monthlyBudget,
    required this.savingsGoals,
  });

  final List<Expense> expenses;
  final List<MoneyReceived> moneyReceived;
  final MonthlyBudget monthlyBudget;
  final List<SavingsGoal> savingsGoals;
}
