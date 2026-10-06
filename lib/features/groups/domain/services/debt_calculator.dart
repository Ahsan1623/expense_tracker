import '../models/peer_debt_model.dart';
import '../../data/models/group_expense_model.dart';

class DebtCalculator {
  /// Calculate pairwise balance strictly from the perspective of [currentUserId]
  static List<PeerDebt> calculatePeerDebts({
    required String currentUserId,
    required List<String> allMemberIds,
    required List<GroupExpenseModel> expenses,
  }) {
    // Map: otherUserId -> net amount (+ve: they owe me, -ve: I owe them)
    final Map<String, double> peerBalances = {};

    for (final memberId in allMemberIds) {
      if (memberId != currentUserId) {
        peerBalances[memberId] = 0.0;
      }
    }

    for (final exp in expenses) {
      if (exp.paidByUserId == currentUserId) {
        // Current user paid: All other included members owe their split share to current user
        for (final split in exp.splits) {
          if (split.userId != currentUserId) {
            peerBalances[split.userId] =
                (peerBalances[split.userId] ?? 0.0) + split.owedAmount;
          }
        }
      } else {
        // Someone else paid: Check if current user is part of the split
        for (final split in exp.splits) {
          if (split.userId == currentUserId) {
            // Current user owes their share to the payer
            final payerId = exp.paidByUserId;
            peerBalances[payerId] =
                (peerBalances[payerId] ?? 0.0) - split.owedAmount;
          }
        }
      }
    }

    return peerBalances.entries
        .map((e) => PeerDebt(otherUserId: e.key, netAmount: e.value))
        .toList();
  }
}