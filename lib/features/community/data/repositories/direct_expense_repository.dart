import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/direct_expense_model.dart';
import '../../../profile/domain/services/audit_service.dart';
import '../../../profile/data/models/audit_log_model.dart';

final directExpenseRepositoryProvider = Provider<DirectExpenseRepository>((ref) {
  return DirectExpenseRepository(ref.watch(auditServiceProvider));
});

final directExpensesStreamProvider =
    StreamProvider.family<List<DirectExpenseModel>, ({String myUid, String peerUid})>((ref, args) {
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
      settlementStatus: 'CONFIRMED',
      isArchived: false,
      createdAt: DateTime.now(),
    );

    await docRef.set(expense.toMap());

    await _auditService.logActivity(
      userId: payerId,
      title: '1-to-1 Expense: $title',
      description: '$borrowerName owes you Rs. ${owedAmount.toStringAsFixed(0)}',
      amount: owedAmount,
      type: AuditType.personalExpense,
      personName: borrowerName,
    );

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

  Future<void> directSettleUp({
    required String payerId,
    required String receiverId,
    required double amount,
    required String payerName,
    required String receiverName,
    String paymentMode = 'Cash',
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
      title: 'Settlement Request via $paymentMode',
      totalAmount: amount,
      owedAmount: amount,
      splitType: DirectSplitType.fullAmount,
      isSettlement: true,
      settlementStatus: 'PENDING',
      paymentMode: paymentMode,
      isArchived: false,
      createdAt: DateTime.now(),
    );

    await docRef.set(settleRecord.toMap());

    await _firestore
        .collection('direct_channels')
        .doc(channelId)
        .collection('messages')
        .add({
      'senderId': payerId,
      'senderName': payerName,
      'content': 'Requested settlement of Rs. ${amount.toStringAsFixed(0)} ($paymentMode)',
      'type': 'settlementEvent',
      'amount': amount,
      'timestamp': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Settle accept hone par purane sabhi open expenses ko settled/archived mark karna
  Future<void> respondToSettlement({
    required String uid1,
    required String uid2,
    required String expenseId,
    required bool accept,
    required String currentUserId,
    required String currentUserName,
  }) async {
    final channelId = getChannelId(uid1, uid2);
    final docRef = _firestore
        .collection('direct_channels')
        .doc(channelId)
        .collection('expenses')
        .doc(expenseId);

    final docSnap = await docRef.get();
    if (!docSnap.exists) throw Exception('Settlement record not found.');

    final data = docSnap.data()!;
    final payerId = data['payerId'] as String;
    final borrowerId = data['borrowerId'] as String;
    final amount = (data['owedAmount'] as num).toDouble();
    final paymentMode = data['paymentMode'] as String? ?? 'Cash';

    if (borrowerId != currentUserId) {
      throw Exception('Only the recipient can confirm or decline this settlement.');
    }

    if (accept) {
      final batch = _firestore.batch();

      // 1. Is settlement request ko confirm aur archive mark karein
      batch.update(docRef, {
        'settlementStatus': 'CONFIRMED',
        'isArchived': true,
      });

      // 2. Ledger ke tamaam pichle open direct expenses ko archived mark karein taake wo dobara open balance na ban sakein
      final openExpensesSnap = await _firestore
          .collection('direct_channels')
          .doc(channelId)
          .collection('expenses')
          .where('isSettlement', isEqualTo: false)
          .get();

      for (final expDoc in openExpensesSnap.docs) {
        batch.update(expDoc.reference, {'isArchived': true});
      }

      await batch.commit();

      await _auditService.logActivity(
        userId: payerId,
        title: 'Settled to $currentUserName',
        description: 'Paid Rs. ${amount.toStringAsFixed(0)} via $paymentMode (Confirmed)',
        amount: amount,
        type: AuditType.settlementSent,
        personName: currentUserName,
      );

      await _auditService.logActivity(
        userId: currentUserId,
        title: 'Settled from Peer',
        description: 'Received Rs. ${amount.toStringAsFixed(0)} via $paymentMode (Confirmed)',
        amount: amount,
        type: AuditType.settlementReceived,
      );

      await _firestore.collection('direct_channels').doc(channelId).collection('messages').add({
        'senderId': currentUserId,
        'senderName': currentUserName,
        'content': 'Confirmed settlement of Rs. ${amount.toStringAsFixed(0)}',
        'type': 'settlementEvent',
        'amount': amount,
        'timestamp': Timestamp.fromDate(DateTime.now()),
      });
    } else {
      await docRef.update({'settlementStatus': 'REJECTED'});

      await _firestore.collection('direct_channels').doc(channelId).collection('messages').add({
        'senderId': currentUserId,
        'senderName': currentUserName,
        'content': 'Declined settlement request of Rs. ${amount.toStringAsFixed(0)}',
        'type': 'systemEvent',
        'timestamp': Timestamp.fromDate(DateTime.now()),
      });
    }
  }

  Future<void> deleteDirectExpense({
    required String uid1,
    required String uid2,
    required String currentUserId,
    required DirectExpenseModel expense,
  }) async {
    if (expense.isSettlement) {
      throw Exception('Settlement records cannot be manually deleted.');
    }
    if (expense.payerId != currentUserId) {
      throw Exception('Only the creator of this expense can delete it.');
    }

    final channelId = getChannelId(uid1, uid2);
    await _firestore
        .collection('direct_channels')
        .doc(channelId)
        .collection('expenses')
        .doc(expense.expenseId)
        .delete();
  }

  // Clear Settled Entries (Sirf aur sirf confirmed settlement slips ko hide karega)
  Future<void> clearSettledEntries(String uid1, String uid2) async {
    final channelId = getChannelId(uid1, uid2);
    final batch = _firestore.batch();

    // Sirf settlement records ko fetch karein
    final querySnap = await _firestore
        .collection('direct_channels')
        .doc(channelId)
        .collection('expenses')
        .where('isSettlement', isEqualTo: true)
        .get();

    int count = 0;
    for (final doc in querySnap.docs) {
      final data = doc.data();
      final status = data['settlementStatus'] ?? 'CONFIRMED';
      
      // Sirf CONFIRMED settlements archive hongi
      // PENDING settlements ko chherna bhi nahi hai!
      if (status == 'CONFIRMED') {
        batch.update(doc.reference, {'isArchived': true});
        count++;
      }
    }

    // YAHAN SE NORMAL EXPENSES WALA LOOP MUKAMMAL KHATAM KAR DIYA GAYA HAI!
    // Kisi bhi direct expense (isSettlement == false) ko archive nahi kiya jayega.

    if (count > 0) {
      await batch.commit();
    }
  }
}