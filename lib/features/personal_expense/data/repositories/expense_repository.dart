import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../models/expense_model.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

// Real-time stream of current user's expenses
final userExpensesProvider = StreamProvider<List<ExpenseModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getUserExpenses(user.uid);
});

class ExpenseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<ExpenseModel>> getUserExpenses(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('personal_expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> addExpense(ExpenseModel expense) async {
    await _firestore
        .collection('users')
        .doc(expense.userId)
        .collection('personal_expenses')
        .add(expense.toMap());
  }

  Future<void> deleteExpense(String userId, String expenseId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('personal_expenses')
        .doc(expenseId)
        .delete();
  }
}