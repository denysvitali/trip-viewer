import 'package:flutter/material.dart';
import 'package:trip_viewer/models/trip_plan.dart';
import 'package:trip_viewer/pages/expenses.dart';

class BudgetPage extends StatelessWidget {
  final Budget budget;

  const BudgetPage({super.key, required this.budget});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Group expenses by currency
    final expensesByCurrency = <String, List<Expense>>{};
    for (final expense in budget.expenses) {
      final currency = expense.amount.currencyCode ?? 'USD';
      expensesByCurrency.putIfAbsent(currency, () => []).add(expense);
    }

    // Group expenses by category
    final expensesByCategory = <String, List<Expense>>{};
    for (final expense in budget.expenses) {
      final category = expense.category ?? 'Uncategorized';
      expensesByCategory.putIfAbsent(category, () => []).add(expense);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ExpensesPage(expenses: budget.expenses),
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
          // Spending summary by currency
          _buildSpendingSummary(theme, expensesByCurrency),
          const SizedBox(height: 16),

          // Spending by category
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'By Category',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final category in expensesByCategory.keys)
                    _buildCategoryRow(
                      context,
                      theme,
                      category,
                      expensesByCategory[category]!,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingSummary(
      ThemeData theme, Map<String, List<Expense>> expensesByCurrency) {
    if (expensesByCurrency.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(120)),
                const SizedBox(height: 12),
                Text('No expenses recorded',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Spent',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            for (final entry in expensesByCurrency.entries) ...[
              _buildCurrencyTotal(theme, entry.key, entry.value),
              if (entry.key != expensesByCurrency.keys.last)
                const SizedBox(height: 8),
            ],
            if (budget.amount.amount > 0) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Budget', style: theme.textTheme.bodyMedium),
                  Text(
                    budget.amount.format(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyTotal(
      ThemeData theme, String currency, List<Expense> expenses) {
    final total =
        expenses.fold<double>(0, (sum, e) => sum + e.amount.amount);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withAlpha(120),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                currency,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${expenses.length} expense${expenses.length != 1 ? 's' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Text(
          '$currency ${total.toStringAsFixed(2)}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRow(
    BuildContext context,
    ThemeData theme,
    String category,
    List<Expense> expenses,
  ) {
    // Group by currency within category
    final byCurrency = <String, double>{};
    for (final e in expenses) {
      final curr = e.amount.currencyCode ?? 'USD';
      byCurrency[curr] = (byCurrency[curr] ?? 0) + e.amount.amount;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExpensesPage(
              expenses: expenses,
              title: category,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withAlpha(120),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getCategoryIcon(category),
                size: 20,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${expenses.length} item${expenses.length != 1 ? 's' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final entry in byCurrency.entries)
                  Text(
                    '${entry.key} ${entry.value.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

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
        return Icons.receipt_long;
    }
  }
}
