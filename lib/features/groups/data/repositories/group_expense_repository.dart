import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group_expense_model.dart';
import '../models/group_model.dart';
import 'package:expense_tracker/features/notifications/domain/services/notifications_service.dart';

final groupExpenseRepositoryProvider = Provider<GroupExpenseRepository>((ref) {
  return GroupExpenseRepository();
});

final groupExpensesStreamProvider =
    StreamProvider.family<List<GroupExpenseModel>, String>((ref, groupId) {
      final repo = ref.watch(groupExpenseRepositoryProvider);
      return repo.getGroupExpenses(groupId);
    });

final singleGroupStreamProvider = StreamProvider.family<GroupModel?, String>((
  ref,
  groupId,
) {
  final repo = ref.watch(groupExpenseRepositoryProvider);
  return repo.getSingleGroup(groupId);
});

class GroupExpenseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<GroupExpenseModel>> getGroupExpenses(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => GroupExpenseModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<GroupModel?> getSingleGroup(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .snapshots()
        .map(
          (doc) => doc.exists ? GroupModel.fromMap(doc.data()!, doc.id) : null,
        );
  }

  // 1. Add Expense with Custom/Selective Split & Push Alert Dispatch
  Future<void> addGroupExpense({
    required String groupId,
    required String title,
    required double totalAmount,
    required String paidByUserId,
    required List<String> splitAmongMemberIds, // Selective members
  }) async {
    if (splitAmongMemberIds.isEmpty) {
      throw Exception('Kam az kam ek member ko split me select karein.');
    }

    final groupDocRef = _firestore.collection('groups').doc(groupId);
    final expenseDocRef = groupDocRef.collection('expenses').doc();

    final double splitAmount = totalAmount / splitAmongMemberIds.length;
    final List<SplitItem> splits = splitAmongMemberIds
        .map((mId) => SplitItem(userId: mId, owedAmount: splitAmount))
        .toList();

    final expense = GroupExpenseModel(
      expenseId: expenseDocRef.id,
      groupId: groupId,
      title: title,
      totalAmount: totalAmount,
      paidByUserId: paidByUserId,
      splits: splits,
      createdById: paidByUserId,
      createdAt: DateTime.now(),
    );

    String groupName = 'Group';
    List<String> allGroupMembers = [];

    // Atomic transaction for financial balance integrity
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(groupDocRef);
      if (!snapshot.exists) throw Exception("Group nahi mila");

      final currentData = snapshot.data()!;
      groupName = currentData['name'] ?? 'Group';
      allGroupMembers = List<String>.from(currentData['members'] ?? []);

      final currentBalances = Map<String, dynamic>.from(
        currentData['netBalances'] ?? {},
      );

      // Payer ko total amount credit karein
      final payerBal =
          (currentBalances[paidByUserId] as num?)?.toDouble() ?? 0.0;
      currentBalances[paidByUserId] = payerBal + totalAmount;

      // Jin jin members pe dalna hai unko unka share debit karein
      for (final memberId in splitAmongMemberIds) {
        final bal = (currentBalances[memberId] as num?)?.toDouble() ?? 0.0;
        currentBalances[memberId] = bal - splitAmount;
      }

      transaction.set(expenseDocRef, expense.toMap());
      transaction.update(groupDocRef, {
        'netBalances': currentBalances,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    });

    // Payer ke ilawa group ke baki members ko notification dispatch karein
    for (final memberId in allGroupMembers) {
      if (memberId != paidByUserId) {
        await NotificationDispatchService.triggerAlert(
          firestore: _firestore,
          recipientUid: memberId,
          senderId: paidByUserId,
          senderName: 'Group Member',
          title: 'New Expense in $groupName',
          message: '$title: Total Rs. ${totalAmount.toStringAsFixed(0)}',
          targetType: 'group',
          targetId: groupId,
          extraData: groupName,
        );
      }
    }
  }

  // 2. Delete Expense (Only by Payer & ONLY if NO approved settlements exist)
  Future<void> deleteGroupExpense({
    required String groupId,
    required GroupExpenseModel expense,
    required String currentUserId,
  }) async {
    // 1. Security check: Only original payer can delete
    if (expense.paidByUserId != currentUserId) {
      throw Exception(
        'Sirf wahi member is expense ko delete kar sakta hai jisne pay kia tha.',
      );
    }

    final groupDocRef = _firestore.collection('groups').doc(groupId);
    final expenseDocRef = groupDocRef
        .collection('expenses')
        .doc(expense.expenseId);

    // 2. Settlement Lock Check: Kya group me koi confirmed settlement ho chuki hai?
    final approvedSettlementsSnap = await groupDocRef
        .collection('settlements')
        .where('status', isEqualTo: 'approved')
        .limit(1)
        .get();

    if (approvedSettlementsSnap.docs.isNotEmpty) {
      throw Exception(
        'Yeh expense delete nahi kiya ja sakta kyunki group me settlements confirm ho chuki hain. Financial records ko safe rakhne ke liye naya adjustment expense add karein.',
      );
    }

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(groupDocRef);
      if (!snapshot.exists) throw Exception("Group nahi mila");

      final currentData = snapshot.data()!;
      final currentBalances = Map<String, dynamic>.from(
        currentData['netBalances'] ?? {},
      );

      // Payer se credit wapis reverse karein
      final payerBal =
          (currentBalances[expense.paidByUserId] as num?)?.toDouble() ?? 0.0;
      currentBalances[expense.paidByUserId] = payerBal - expense.totalAmount;

      // Splits ko balance me reverse karein
      for (final split in expense.splits) {
        final bal = (currentBalances[split.userId] as num?)?.toDouble() ?? 0.0;
        currentBalances[split.userId] = bal + split.owedAmount;
      }

      transaction.delete(expenseDocRef);
      transaction.update(groupDocRef, {
        'netBalances': currentBalances,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    });
  }

  // 3. Delete Group (Admin can delete anytime, members only when balances are 0.0)
  Future<void> deleteGroup({
    required String groupId,
    required String currentUserId,
  }) async {
    final groupDocRef = _firestore.collection('groups').doc(groupId);
    final groupSnap = await groupDocRef.get();

    if (!groupSnap.exists) throw Exception("Group nahi mila");

    final groupData = groupSnap.data()!;
    final createdById = groupData['createdById'] ?? '';
    final isAdmin = createdById == currentUserId;

    if (!isAdmin) {
      final balances = Map<String, dynamic>.from(
        groupData['netBalances'] ?? {},
      );
      final hasPendingDebt = balances.values.any((val) {
        final num amount = val as num? ?? 0.0;
        return amount.abs() > 0.01;
      });

      if (hasPendingDebt) {
        throw Exception(
          'Sirf group admin kisi bhi waqt delete kar sakta hai. Baki members sirf tab delete kar sakte hain jab tamam hisaab 0 (settled) ho.',
        );
      }
    }

    final expensesSnapshot = await groupDocRef.collection('expenses').get();
    final settlementsSnapshot = await groupDocRef
        .collection('settlements')
        .get();
    final remindersSnapshot = await groupDocRef
        .collection('payment_reminders')
        .get();

    final batch = _firestore.batch();
    for (final doc in expensesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in settlementsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in remindersSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(groupDocRef);
    await batch.commit();
  }
}
