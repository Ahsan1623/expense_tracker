import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../data/models/expense_model.dart';

class ExpensePieChart extends StatelessWidget {
  final List<ExpenseModel> expenses;

  const ExpensePieChart({super.key, required this.expenses});

  Color _getCategoryColor(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return const Color(0xFFF59E0B);
      case ExpenseCategory.transport:
        return const Color(0xFF3B82F6);
      case ExpenseCategory.shopping:
        return const Color(0xFFEC4899);
      case ExpenseCategory.bills:
        return const Color(0xFF8B5CF6);
      case ExpenseCategory.entertainment:
        return const Color(0xFF10B981);
      case ExpenseCategory.health:
        return const Color(0xFFEF4444);
      case ExpenseCategory.other:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) return const SizedBox.shrink();

    // Group expenses by category
    final Map<ExpenseCategory, double> categoryTotals = {};
    for (final e in expenses) {
      categoryTotals[e.category] = (categoryTotals[e.category] ?? 0.0) + e.amount;
    }

    final totalSpent = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spending Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                height: 140,
                width: 140,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 36,
                    sections: categoryTotals.entries.map((entry) {
                      final percentage = (entry.value / totalSpent) * 100;
                      return PieChartSectionData(
                        color: _getCategoryColor(entry.key),
                        value: entry.value,
                        title: '${percentage.toStringAsFixed(0)}%',
                        radius: 28,
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: categoryTotals.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3.0),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _getCategoryColor(entry.key),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.key.name.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          Text(
                            'Rs. ${entry.value.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
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
        ],
      ),
    );
  }
}