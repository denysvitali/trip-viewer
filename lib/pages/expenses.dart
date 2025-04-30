import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import intl package
import 'package:wanderlog_alt/models/trip_plan.dart';

class ExpensesPage extends StatelessWidget {
  final List<Expense> expenses;
  final String title;

  const ExpensesPage({
    super.key,
    required this.expenses,
    this.title = 'Expenses',
  });

  @override
  Widget build(BuildContext context) {
    // Sort expenses by date (newest first)
    final sortedExpenses = List<Expense>.from(expenses)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: sortedExpenses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No expenses found',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: sortedExpenses.length,
              itemBuilder: (context, index) {
                final expense = sortedExpenses[index];
                // Format the date
                final formattedDate = DateFormat('MMM d, yyyy')
                    .format(DateTime.parse(expense.date));
                final subtitleText =
                    '${expense.amount.format()} - Paid by user ${expense.paidByUserId} on $formattedDate';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(_getCategoryIcon(expense.category)),
                  ),
                  title: Text(expense.description ?? 'No description'),
                  subtitle: Text(subtitleText),
                  trailing: Text(expense.category),
                );
              },
            ),
    );
  }

  // Helper function to get an icon based on category
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'flights':
        return Icons.flight;
      case 'lodging':
        return Icons.hotel;
      case 'food':
        return Icons.restaurant;
      case 'activities':
        return Icons.local_activity;
      case 'transport':
        return Icons.directions_transit;
      default:
        return Icons.receipt_long; // Default icon
    }
  }
}
