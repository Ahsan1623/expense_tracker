import '../models/peer_debt_model.dart';
import '../../data/models/group_expense_model.dart';

class DebtCalculator {
  /// Calculate pairwise balance strictly from the perspective of [currentUserId]
  /// Supports single-payer as well as multiple-payers seamlessly
  static List<PeerDebt> calculatePeerDebts({
    required String currentUserId,
    required List<String> allMemberIds,
    required List<GroupExpenseModel> expenses,
  }) {
    final Map<String, double> peerBalances = {};

    for (final memberId in allMemberIds) {
      if (memberId != currentUserId) {
        peerBalances[memberId] = 0.0;
      }
    }

    for (final exp in expenses) {
      final double totalExpense = exp.totalAmount;
      if (totalExpense <= 0) continue;

      // Expense ke payers uthayein (multi-payer support)
      final List<PayerItem> payers = exp.payers.isNotEmpty
          ? exp.payers
          : [PayerItem(userId: exp.paidByUserId, amount: totalExpense)];

      // Expense ke splits map banayein (userId -> owedAmount)
      final Map<String, double> memberOwedMap = {
        for (var s in exp.splits) s.userId: s.owedAmount,
      };

      // Har payer ke contribution ka share calculate karein
      for (final payer in payers) {
        final payerId = payer.userId;
        final payerAmount = payer.amount;
        if (payerAmount <= 0) continue;

        // Ratio of total bill this payer covered
        final double payerContributionRatio = payerAmount / totalExpense;

        for (final entry in memberOwedMap.entries) {
          final oweMemberId = entry.key;
          final totalOwedByMember = entry.value;

          // Member owes this specific payer in proportion to their payment
          final double owedToThisPayer = totalOwedByMember * payerContributionRatio;

          // Case 1: Current user ne pay kiya, doosra banda owe karta hai (+ve)
          if (payerId == currentUserId && oweMemberId != currentUserId) {
            peerBalances[oweMemberId] =
                (peerBalances[oweMemberId] ?? 0.0) + owedToThisPayer;
          }

          // Case 2: Kisi doosre bande ne pay kiya, current user owe karta hai (-ve)
          if (payerId != currentUserId && oweMemberId == currentUserId) {
            peerBalances[payerId] =
                (peerBalances[payerId] ?? 0.0) - owedToThisPayer;
          }
        }
      }
    }

    return peerBalances.entries
        .map((e) => PeerDebt(otherUserId: e.key, netAmount: e.value))
        .toList();
  }
}