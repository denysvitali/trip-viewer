import 'package:flutter/material.dart';
import 'package:wanderlog_alt/models/trip_plan.dart';
import 'package:wanderlog_alt/pages/expenses.dart';
import 'package:intl/intl.dart';

class BudgetPage extends StatelessWidget {
  final Budget budget;

  const BudgetPage({super.key, required this.budget});

  @override
  Widget build(BuildContext context) {
    // Group expenses by category
    final expensesByCategory = <String, List<Expense>>{};
    for (final expense in budget.expenses) {
      final category = expense.category ?? 'Uncategorized';
      if (!expensesByCategory.containsKey(category)) {
        expensesByCategory[category] = [];
      }
      expensesByCategory[category]!.add(expense);
    }

    // Calculate total spent amount
    double totalSpent = budget.expenses
        .fold(0, (total, expense) => total + expense.amount.amount);

    // Calculate remaining budget
    double remainingBudget = budget.amount.amount - totalSpent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExpensesPage(expenses: budget.expenses),
                ),
              );
            },
            tooltip: 'View all expenses',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Budget summary card
          Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Budget Summary',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildBudgetRow(
                    context,
                    'Total Budget',
                    budget.amount.format(),
                  ),
                  _buildBudgetRow(
                    context,
                    'Spent',
                    '${budget.amount.currencyCode} ${totalSpent.toStringAsFixed(2)}',
                    valueColor: Colors.red,
                  ),
                  _buildBudgetRow(
                    context,
                    'Remaining',
                    '${budget.amount.currencyCode} ${remainingBudget.toStringAsFixed(2)}',
                    valueColor:
                        remainingBudget >= 0 ? Colors.green : Colors.red,
                  ),
                ],
              ),
            ),
          ),

          // Spending by category
          Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spending by Category',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  for (final category in expensesByCategory.keys)
                    _buildCategoryRow(
                      context,
                      category,
                      expensesByCategory[category]!,
                      budget.amount.currencyCode ?? '',
                    ),
                ],
              ),
            ),
          ),

          // Payments section if available
          if (budget.payments.isNotEmpty)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payments',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text('Payment tracking functionality coming soon'),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add expense entry dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add expense feature coming soon')),
          );
        },
        tooltip: 'Add Expense',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBudgetRow(BuildContext context, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(
    BuildContext context,
    String category,
    List<Expense> expenses,
    String currencyCode,
  ) {
    double total =
        expenses.fold(0, (total, expense) => total + expense.amount.amount);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExpensesPage(
              expenses: expenses,
              title: 'Expenses: $category',
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(_getCategoryIcon(category)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${expenses.length} item${expenses.length != 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              '$currencyCode ${total.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
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
