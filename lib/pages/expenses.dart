import 'package:flutter/material.dart';
import 'package:wanderlog_alt/models/trip_plan.dart';

class ExpensesPage extends StatelessWidget {
  final List<Expense> expenses;

  const ExpensesPage({super.key, required this.expenses});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
      ),
      body: ListView.builder(
        itemCount: expenses.length,
        itemBuilder: (context, index) {
          final expense = expenses[index];
          return ListTile(
            title: Text(expense.description ?? 'No description'),
            subtitle: Text('${expense.amount.value} ${expense.amount.currencyCode}'),
            trailing: Text(expense.category),
          );
        },
      ),
    );
  }
}
