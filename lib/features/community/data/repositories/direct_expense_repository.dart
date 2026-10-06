import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/direct_expense_model.dart';
import '../../../profile/domain/services/audit_service.dart';
import '../../../profile/data/models/audit_log_model.dart';

final directExpenseRepositoryProvider = Provider<DirectExpenseRepository>((
  ref,
) {
  return DirectExpenseRepository(ref.watch(auditServiceProvider));
});

final directExpensesStreamProvider =
    StreamProvider.family<
      List<DirectExpenseModel>,
      ({String myUid, String peerUid})
    >((ref, args) {
      final repo = ref.watch(directExpenseRepositoryProvider);
      return repo.getDirectExpenses(args.myUid, args.peerUid);
    });

class DirectExpenseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuditService _auditService;

  DirectExpenseRepository(this._auditService);

  String getChannelId(String uid1, String uid2) {
    final list = [uid1, uid2]..sort();
    return '${list[0]}_${list[1]}';
  }

  Stream<List<DirectExpenseModel>> getDirectExpenses(String uid1, String uid2) {
    final channelId = getChannelId(uid1, uid2);
    return _firestore
        .collection('direct_channels')
        .doc(channelId)
        .collection('expenses')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => DirectExpenseModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // 1. Add Direct Expense
  Future<void> addDirectExpense({
    required String payerId,
    required String borrowerId,
    required String title,
    required double totalAmount,
    required DirectSplitType splitType,
    required String payerName,
    required String borrowerName,
  }) async {
    final channelId = getChannelId(payerId, borrowerId);
    final docRef = _firestore
        .collection('direct_channels')
        .doc(channelId)
        .collection('expenses')
        .doc();

    final owedAmount = splitType == DirectSplitType.equal50_50
        ? totalAmount / 2.0
        : totalAmount;

    final expense = DirectExpenseModel(
      expenseId: docRef.id,
      payerId: payerId,
      borrowerId: borrowerId,
      title: title,
      totalAmount: totalAmount,
      owedAmount: owedAmount,
      splitType: splitType,
      isSettlement: false,
      createdAt: DateTime.now(),
    );

    await docRef.set(expense.toMap());

    // Audit logs
    await _auditService.logActivity(
      userId: payerId,
      title: '1-to-1 Expense: $title',
      description:
          '$borrowerName owes you Rs. ${owedAmount.toStringAsFixed(0)}',
      amount: owedAmount,
      type: AuditType.personalExpense,
      personName: borrowerName,
    );

    // Chat Message Log
    await _firestore
        .collection('direct_channels')
        .doc(channelId)
        .collection('messages')
        .add({
          'senderId': payerId,
          'senderName': payerName,
          'content': 'Added expense: "$title"',
          'type': 'expenseEvent',
          'amount': owedAmount,
          'timestamp': Timestamp.fromDate(DateTime.now()),
        });
  }

  // 2. Direct Settle
  Future<void> directSettleUp({
    required String payerId,
    required String receiverId,
    required double amount,
    required String payerName,
    required String receiverName,
  }) async {
    final channelId = getChannelId(payerId, receiverId);
    final docRef = _firestore
        .collection('direct_channels')
        .doc(channelId)
        .collection('expenses')
        .doc();

    final settleRecord = DirectExpenseModel(
      expenseId: docRef.id,
      payerId: payerId,
      borrowerId: receiverId,
      title: 'Settlement: Direct Payment',
      totalAmount: amount,
      owedAmount: amount,
      splitType: DirectSplitType.fullAmount,
      isSettlement: true,
      createdAt: DateTime.now(),
    );

    await docRef.set(settleRecord.toMap());

    await _auditService.logActivity(
      userId: payerId,
      title: 'Settled to $receiverName',
      description: 'Paid Rs. ${amount.toStringAsFixed(0)} directly',
      amount: amount,
      type: AuditType.settlementSent,
      personName: receiverName,
    );

    await _auditService.logActivity(
      userId: receiverId,
      title: 'Settled from $payerName',
      description: 'Received Rs. ${amount.toStringAsFixed(0)} directly',
      amount: amount,
      type: AuditType.settlementReceived,
      personName: payerName,
    );

    await _firestore
        .collection('direct_channels')
        .doc(channelId)
        .collection('messages')
        .add({
          'senderId': payerId,
          'senderName': payerName,
          'content': 'Recorded settlement payment',
          'type': 'settlementEvent',
          'amount': amount,
          'timestamp': Timestamp.fromDate(DateTime.now()),
        });
  }

  // 3. Delete Expense (Only non-settlement & only by payer)
  Future<void> deleteDirectExpense({
    required String uid1,
    required String uid2,
    required String currentUserId,
    required DirectExpenseModel expense,
  }) async {
    if (expense.isSettlement) {
      throw Exception('Settlement records delete nahi kiye ja saktay.');
    }
    if (expense.payerId != currentUserId) {
      throw Exception(
        'Sirf expense create karne wala hi ise delete kar sakta hai.',
      );
    }

    final channelId = getChannelId(uid1, uid2);

    // Settlement lock check:
    final settlementsSnap = await _firestore
        .collection('direct_channels')
        .doc(channelId)
        .collection('expenses')
        .where('isSettlement', isEqualTo: true)
        .limit(1)
        .get();

    if (settlementsSnap.docs.isNotEmpty) {
      throw Exception(
        'Is ledger mein settlements record ho chuki hain. Expense delete karne se hisaab kharab ho jayega.',
      );
    }

    await _firestore
        .collection('direct_channels')
        .doc(channelId)
        .collection('expenses')
        .doc(expense.expenseId)
        .delete();
  }
}
