import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/settlement_model.dart';
import '../models/payment_reminder_model.dart';
import '../../../groups/data/models/group_expense_model.dart';
import 'package:expense_tracker/features/notifications/domain/services/notifications_service.dart';

final settlementRepositoryProvider = Provider<SettlementRepository>((ref) {
  return SettlementRepository();
});

final groupSettlementsProvider =
    StreamProvider.family<List<SettlementModel>, String>((ref, groupId) {
      final repo = ref.watch(settlementRepositoryProvider);
      return repo.getGroupSettlements(groupId);
    });

final groupRemindersProvider =
    StreamProvider.family<List<PaymentReminderModel>, String>((ref, groupId) {
      final repo = ref.watch(settlementRepositoryProvider);
      return repo.getGroupReminders(groupId);
    });

class SettlementRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<SettlementModel>> getGroupSettlements(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => SettlementModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<PaymentReminderModel>> getGroupReminders(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('payment_reminders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => PaymentReminderModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // 1. Payer initiates settlement -> Receiver ko Alert Jayega
  Future<void> requestSettlement({
    required String groupId,
    required String fromUserId,
    required String toUserId,
    required double amount,
    String note = 'Payment Sent',
  }) async {
    final docRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .doc();

    final model = SettlementModel(
      settlementId: docRef.id,
      groupId: groupId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      amount: amount,
      note: note,
      status: SettlementStatus.pending,
      createdAt: DateTime.now(),
    );

    await docRef.set(model.toMap());

    // Receiver ko request notification trigger
    await NotificationDispatchService.triggerAlert(
      firestore: _firestore,
      recipientUid: toUserId,
      senderId: fromUserId,
      senderName: 'Group Member',
      title: 'Settlement Requested 🤝',
      message: 'Payment of Rs. ${amount.toStringAsFixed(0)} sent for verification ($note).',
      targetType: 'group',
      targetId: groupId,
    );
  }

  // 2. Receiver confirms payment -> Atomic balance reset + Instant Notification
  Future<void> confirmSettlement({required SettlementModel settlement}) async {
    final groupRef = _firestore.collection('groups').doc(settlement.groupId);
    final settlementRef = groupRef
        .collection('settlements')
        .doc(settlement.settlementId);
    final expenseRef = groupRef.collection('expenses').doc();

    await _firestore.runTransaction((transaction) async {
      final groupSnap = await transaction.get(groupRef);
      if (!groupSnap.exists) {
        throw Exception("Group document nahi mila");
      }

      final data = groupSnap.data()!;
      final balances = Map<String, dynamic>.from(data['netBalances'] ?? {});

      final fromBal =
          (balances[settlement.fromUserId] as num?)?.toDouble() ?? 0.0;
      final toBal = (balances[settlement.toUserId] as num?)?.toDouble() ?? 0.0;

      balances[settlement.fromUserId] = fromBal + settlement.amount;
      balances[settlement.toUserId] = toBal - settlement.amount;

      final settlementExpense = GroupExpenseModel(
        expenseId: expenseRef.id,
        groupId: settlement.groupId,
        title: 'Settled: ${settlement.note}',
        totalAmount: settlement.amount,
        paidByUserId: settlement.fromUserId,
        splits: [
          SplitItem(userId: settlement.toUserId, owedAmount: settlement.amount),
        ],
        createdById: settlement.fromUserId,
        createdAt: DateTime.now(),
      );

      transaction.update(settlementRef, {'status': 'approved'});
      transaction.set(expenseRef, settlementExpense.toMap());
      transaction.update(groupRef, {
        'netBalances': balances,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    });

    // Guaranteed Notification Trigger (Payer ko confirmation jaye)
    await NotificationDispatchService.triggerAlert(
      firestore: _firestore,
      recipientUid: settlement.fromUserId,
      senderId: settlement.toUserId,
      senderName: 'Group Member',
      title: 'Settlement Confirmed ✅',
      message:
          'Payment of Rs. ${settlement.amount.toStringAsFixed(0)} has been verified and settled.',
      targetType: 'group',
      targetId: settlement.groupId,
    );

    // Audit logs
    try {
      final userDocFrom = await _firestore
          .collection('users')
          .doc(settlement.toUserId)
          .get();
      final toUserName = userDocFrom.data()?['displayName'] ?? 'Member';

      final userDocTo = await _firestore
          .collection('users')
          .doc(settlement.fromUserId)
          .get();
      final fromUserName = userDocTo.data()?['displayName'] ?? 'Member';

      final groupSnap = await groupRef.get();
      final groupName = groupSnap.data()?['name'] ?? 'Group';

      await _firestore
          .collection('users')
          .doc(settlement.fromUserId)
          .collection('audit_history')
          .add({
            'title': 'Payment Settled',
            'description':
                'Paid Rs. ${settlement.amount.toStringAsFixed(0)} to $toUserName',
            'amount': settlement.amount,
            'type': 'settlementSent',
            'groupName': groupName,
            'personName': toUserName,
            'timestamp': Timestamp.fromDate(DateTime.now()),
          });

      await _firestore
          .collection('users')
          .doc(settlement.toUserId)
          .collection('audit_history')
          .add({
            'title': 'Payment Received',
            'description':
                'Received Rs. ${settlement.amount.toStringAsFixed(0)} from $fromUserName',
            'amount': settlement.amount,
            'type': 'settlementReceived',
            'groupName': groupName,
            'personName': fromUserName,
            'timestamp': Timestamp.fromDate(DateTime.now()),
          });
    } catch (_) {}
  }

  // 3. Reject Settlement -> Sender ko Alert
  Future<void> rejectSettlement({
    required String groupId,
    required String settlementId,
  }) async {
    final docRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .doc(settlementId);

    final snap = await docRef.get();
    if (snap.exists) {
      final data = snap.data()!;
      final fromUserId = data['fromUserId'] ?? '';
      final toUserId = data['toUserId'] ?? '';
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

      await docRef.update({'status': 'rejected'});

      if (fromUserId.isNotEmpty) {
        await NotificationDispatchService.triggerAlert(
          firestore: _firestore,
          recipientUid: fromUserId,
          senderId: toUserId,
          senderName: 'Group Member',
          title: 'Settlement Rejected ❌',
          message: 'Payment request of Rs. ${amount.toStringAsFixed(0)} was not confirmed.',
          targetType: 'group',
          targetId: groupId,
        );
      }
    }
  }

  // 4. Dismiss Payment Reminder
  Future<void> dismissReminder({
    required String groupId,
    required String reminderId,
  }) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('payment_reminders')
        .doc(reminderId)
        .delete();
  }

  // 5. Payment Reminder
  Future<void> sendPaymentReminder({
    required String groupId,
    required String fromUserId,
    required String toUserId,
    required double amount,
  }) async {
    final remindersRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('payment_reminders');

    final query = await remindersRef
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .get();

    if (query.docs.isNotEmpty) {
      final allDates = query.docs.map((d) {
        return (d.data()['createdAt'] as Timestamp).toDate();
      }).toList();

      allDates.sort((a, b) => b.compareTo(a));
      final lastTime = allDates.first;

      final difference = DateTime.now().difference(lastTime);

      if (difference.inMinutes < 60) {
        final remaining = 60 - difference.inMinutes;
        throw Exception(
          'Payment request pehle hi bheji ja chuki hai. Agli request $remaining minute baad bhej sakte hain.',
        );
      }
    }

    final docRef = remindersRef.doc();
    final reminder = PaymentReminderModel(
      reminderId: docRef.id,
      groupId: groupId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      amount: amount,
      createdAt: DateTime.now(),
    );

    await NotificationDispatchService.triggerAlert(
      firestore: _firestore,
      recipientUid: toUserId,
      senderId: fromUserId,
      senderName: 'Friend',
      title: 'Payment Reminder 🔔',
      message:
          'Please settle the pending dues of Rs. ${amount.toStringAsFixed(0)}',
      targetType: 'group',
      targetId: groupId,
    );

    await docRef.set(reminder.toMap());
  }
}