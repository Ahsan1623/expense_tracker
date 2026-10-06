import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:async/async.dart';

class UserStatsSummary {
  final double totalPersonalSpent;
  final int totalGroupsCount;
  final double totalReceivable; // Doosron se lene hain
  final double totalPayable;    // Doosron ko dene hain

  UserStatsSummary({
    required this.totalPersonalSpent,
    required this.totalGroupsCount,
    required this.totalReceivable,
    required this.totalPayable,
  });
}

// True Live Combined Stream for Instant Overview Refresh
final userStatsProvider = StreamProvider<UserStatsSummary>((ref) async* {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    yield UserStatsSummary(
      totalPersonalSpent: 0,
      totalGroupsCount: 0,
      totalReceivable: 0,
      totalPayable: 0,
    );
    return;
  }

  final firestore = FirebaseFirestore.instance;

  final personalStream = firestore
      .collection('users')
      .doc(user.uid)
      .collection('personal_expenses')
      .snapshots();

  final groupsStream = firestore
      .collection('groups')
      .where('members', arrayContains: user.uid)
      .snapshots();

  // Combine both streams so whenever ANY group or personal expense updates, it recalculates instantly
  final combinedStream = StreamGroup.merge([personalStream, groupsStream]);

  await for (final _ in combinedStream) {
    // 1. Fetch personal expenses
    final personalSnap = await firestore
        .collection('users')
        .doc(user.uid)
        .collection('personal_expenses')
        .get();

    double personalTotal = 0.0;
    for (final doc in personalSnap.docs) {
      personalTotal += (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
    }

    // 2. Fetch groups
    final groupsSnap = await firestore
        .collection('groups')
        .where('members', arrayContains: user.uid)
        .get();

    double receivable = 0.0;
    double payable = 0.0;

    for (final gDoc in groupsSnap.docs) {
      final balances =
          Map<String, dynamic>.from(gDoc.data()['netBalances'] ?? {});
      final myBal = (balances[user.uid] as num?)?.toDouble() ?? 0.0;
      if (myBal > 0) {
        receivable += myBal;
      } else if (myBal < 0) {
        payable += myBal.abs();
      }
    }

    yield UserStatsSummary(
      totalPersonalSpent: personalTotal,
      totalGroupsCount: groupsSnap.docs.length,
      totalReceivable: receivable,
      totalPayable: payable,
    );
  }
});