import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../groups/data/models/group_expense_model.dart';
import '../../../groups/data/models/group_model.dart';
import '../../../groups/domain/services/debt_minimizer.dart';

class PeerGroupBreakdown {
  final GroupModel group;
  final double netAmount; // Optimal simplified amount (+ve: friend owes you, -ve: you owe)
  final List<GroupExpenseModel> sharedExpenses;

  PeerGroupBreakdown({
    required this.group,
    required this.netAmount,
    required this.sharedExpenses,
  });
}

class PeerOverallSummary {
  final double totalNetAmount; // Consolidated optimal net across mutual groups
  final List<PeerGroupBreakdown> breakdowns;

  PeerOverallSummary({
    required this.totalNetAmount,
    required this.breakdowns,
  });
}

final peerLedgerProvider = StreamProvider.family<PeerOverallSummary, ({String myUid, String peerUid})>((ref, args) {
  final firestore = FirebaseFirestore.instance;

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

      final expSnap = await firestore
          .collection('groups')
          .doc(group.groupId)
          .collection('expenses')
          .orderBy('createdAt', descending: true)
          .get();

      final expenses = expSnap.docs
          .map((eDoc) => GroupExpenseModel.fromMap(eDoc.data(), eDoc.id))
          .toList();

      final allIds = group.allMemberIds;

      // 1. Calculate net cashflow balance for every member in this group
      final Map<String, double> netBalances = {for (final id in allIds) id: 0.0};

      for (final exp in expenses) {
        final double totalExpense = exp.totalAmount;
        if (totalExpense <= 0) continue;

        // Payers credit (+ve)
        final List<PayerItem> payers = exp.payers.isNotEmpty
            ? exp.payers
            : [PayerItem(userId: exp.paidByUserId, amount: totalExpense)];

        for (final p in payers) {
          netBalances[p.userId] = (netBalances[p.userId] ?? 0.0) + p.amount;
        }

        // Split shares debit (-ve)
        for (final s in exp.splits) {
          netBalances[s.userId] = (netBalances[s.userId] ?? 0.0) - s.owedAmount;
        }
      }

      // 2. Run greedy minimum cashflow optimizer
      final simplifiedTransfers = DebtMinimizer.simplifyDebts(netBalances);

      // 3. Optimal transfers between me and this specific peer
      double optimalGroupNet = 0.0;
      for (final t in simplifiedTransfers) {
        if (t.fromUserId == args.peerUid && t.toUserId == args.myUid) {
          optimalGroupNet += t.amount;
        } else if (t.fromUserId == args.myUid && t.toUserId == args.peerUid) {
          optimalGroupNet -= t.amount;
        }
      }

      // Filter mutual expenses for breakdown display
      final relatedExpenses = expenses.where((e) {
        final payers = e.payers.isNotEmpty ? e.payers.map((p) => p.userId).toSet() : {e.paidByUserId};
        final splitters = e.splits.map((s) => s.userId).toSet();
        final involvesMe = payers.contains(args.myUid) || splitters.contains(args.myUid);
        final involvesPeer = payers.contains(args.peerUid) || splitters.contains(args.peerUid);
        return involvesMe && involvesPeer;
      }).toList();

      overallTotal += optimalGroupNet;
      breakdowns.add(PeerGroupBreakdown(
        group: group,
        netAmount: optimalGroupNet,
        sharedExpenses: relatedExpenses,
      ));
    }

    return PeerOverallSummary(
      totalNetAmount: overallTotal,
      breakdowns: breakdowns,
    );
  });
});