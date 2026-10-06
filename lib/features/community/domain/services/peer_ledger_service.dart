import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/features/groups/domain/models/peer_debt_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../groups/data/models/group_expense_model.dart';
import '../../../groups/data/models/group_model.dart';
import '../../../groups/domain/services/debt_calculator.dart';

class PeerGroupBreakdown {
  final GroupModel group;
  final double netAmount; // +ve: friend owes you, -ve: you owe friend
  final List<GroupExpenseModel> sharedExpenses;

  PeerGroupBreakdown({
    required this.group,
    required this.netAmount,
    required this.sharedExpenses,
  });
}

class PeerOverallSummary {
  final double totalNetAmount; // +ve: friend owes you overall, -ve: you owe
  final List<PeerGroupBreakdown> breakdowns;

  PeerOverallSummary({
    required this.totalNetAmount,
    required this.breakdowns,
  });
}

final peerLedgerProvider = StreamProvider.family<PeerOverallSummary, ({String myUid, String peerUid})>((ref, args) {
  final firestore = FirebaseFirestore.instance;

  // Stream all groups where both members exist
  return firestore
      .collection('groups')
      .where('members', arrayContains: args.myUid)
      .snapshots()
      .asyncMap((groupSnap) async {
    final List<PeerGroupBreakdown> breakdowns = [];
    double overallTotal = 0.0;

    for (final doc in groupSnap.docs) {
      final group = GroupModel.fromMap(doc.data(), doc.id);
      if (!group.members.contains(args.peerUid)) continue;

      // Fetch expenses for this mutual group
      final expSnap = await firestore
          .collection('groups')
          .doc(group.groupId)
          .collection('expenses')
          .orderBy('createdAt', descending: true)
          .get();

      final expenses = expSnap.docs
          .map((eDoc) => GroupExpenseModel.fromMap(eDoc.data(), eDoc.id))
          .toList();

      final peerDebts = DebtCalculator.calculatePeerDebts(
        currentUserId: args.myUid,
        allMemberIds: group.members,
        expenses: expenses,
      );

      final match = peerDebts.firstWhere(
        (d) => d.otherUserId == args.peerUid,
        orElse: () => PeerDebt(otherUserId: args.peerUid, netAmount: 0.0),
      );

      // Only relevant expenses where either paid or was in split
      final relatedExpenses = expenses.where((e) {
        final iAmPayer = e.paidByUserId == args.myUid;
        final peerIsPayer = e.paidByUserId == args.peerUid;
        final iAmSplit = e.splits.any((s) => s.userId == args.myUid);
        final peerIsSplit = e.splits.any((s) => s.userId == args.peerUid);
        return (iAmPayer && peerIsSplit) || (peerIsPayer && iAmSplit);
      }).toList();

      overallTotal += match.netAmount;
      breakdowns.add(PeerGroupBreakdown(
        group: group,
        netAmount: match.netAmount,
        sharedExpenses: relatedExpenses,
      ));
    }

    return PeerOverallSummary(
      totalNetAmount: overallTotal,
      breakdowns: breakdowns,
    );
  });
});