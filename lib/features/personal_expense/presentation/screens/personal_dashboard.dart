import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:expense_tracker/features/personal_expense/data/repositories/expense_repository.dart';
import 'package:expense_tracker/features/personal_expense/presentation/widgets/add_expense_sheet.dart';
import 'package:expense_tracker/features/notifications/presentation/widgets/notification_bell_icon.dart';

class PersonalDashboardScreen extends ConsumerWidget {
  const PersonalDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(userExpensesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Personal Ledger',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF1E293B),
          ),
        ),
        actions: const [
          NotificationBellIcon(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (context) => const AddExpenseSheet(),
          );
        },
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: expensesAsync.when(
        data: (expenses) {
          final totalSpent = expenses.fold<double>(
            0.0,
            (sum, item) => sum + item.amount,
          );

          // Group by category string (using enum .name)
          final Map<String, double> categoryMap = {};
          for (final e in expenses) {
            final catName = e.category.name;
            categoryMap[catName] = (categoryMap[catName] ?? 0.0) + e.amount;
          }

          final pieSections = categoryMap.entries.map((entry) {
            final color = _getCategoryColor(entry.key);
            final pct = totalSpent > 0 ? (entry.value / totalSpent) * 100 : 0.0;
            return PieChartSectionData(
              color: color,
              value: entry.value,
              title: '${pct.toStringAsFixed(0)}%',
              radius: 42,
              titleStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade800, const Color(0xFF0F766E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Personal Outflow',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rs. ${NumberFormat('#,##0.00').format(totalSpent)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${expenses.length} Total Recorded Entries',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (expenses.isNotEmpty && categoryMap.isNotEmpty) ...[
                const Text(
                  'Spending Analytics',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        height: 120,
                        width: 120,
                        child: PieChart(
                          PieChartData(
                            sections: pieSections,
                            centerSpaceRadius: 26,
                            sectionsSpace: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: categoryMap.entries.take(4).map((entry) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 5,
                                    backgroundColor: _getCategoryColor(entry.key),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Rs. ${entry.value.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              const Text(
                'Recent Personal Expenses',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),

              if (expenses.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        const Text(
                          'No personal expenses logged yet.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap "+ Add Expense" to record daily transactions.',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: expenses.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = expenses[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getCategoryColor(item.category.name).withValues(alpha: 0.15),
                          child: Icon(
                            _getCategoryIcon(item.category.name),
                            color: _getCategoryColor(item.category.name),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        subtitle: Text(
                          '${item.category.name} • ${DateFormat('dd MMM, hh:mm a').format(item.date)}',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Rs. ${NumberFormat('#,##0.00').format(item.amount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.grey.shade400,
                                size: 18,
                              ),
                              onPressed: () {
                                ref
                                    .read(expenseRepositoryProvider)
                                    .deleteExpense(item.userId, item.id);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 60),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading expenses: $e')),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Colors.orange.shade700;
      case 'transport':
        return Colors.blue.shade700;
      case 'shopping':
        return Colors.purple.shade700;
      case 'bills':
        return Colors.red.shade700;
      default:
        return Colors.teal.shade700;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant_rounded;
      case 'transport':
        return Icons.directions_bus_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'bills':
        return Icons.receipt_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}