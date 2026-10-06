class MinimizedTransaction {
  final String fromUserId;
  final String toUserId;
  final double amount;

  MinimizedTransaction({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });
}

class DebtMinimizer {
  /// Greedy two-pointer solver for minimum cash flow transfers
  static List<MinimizedTransaction> simplifyDebts(Map<String, double> netBalances) {
    // 1. Separate debtors (-ve balance) and creditors (+ve balance)
    final List<MapEntry<String, double>> debtors = [];
    final List<MapEntry<String, double>> creditors = [];

    netBalances.forEach((userId, balance) {
      if (balance < -0.01) {
        debtors.add(MapEntry(userId, balance.abs()));
      } else if (balance > 0.01) {
        creditors.add(MapEntry(userId, balance));
      }
    });

    // Sort descending to settle largest amounts first
    debtors.sort((a, b) => b.value.compareTo(a.value));
    creditors.sort((a, b) => b.value.compareTo(a.value));

    final List<MinimizedTransaction> transactions = [];
    int debtorIndex = 0;
    int creditorIndex = 0;

    // 2. Greedy matching loop
    while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
      final debtor = debtors[debtorIndex];
      final creditor = creditors[creditorIndex];

      final double settleAmount = debtor.value < creditor.value ? debtor.value : creditor.value;

      transactions.add(MinimizedTransaction(
        fromUserId: debtor.key,
        toUserId: creditor.key,
        amount: settleAmount,
      ));

      final double remainingDebt = debtor.value - settleAmount;
      final double remainingCredit = creditor.value - settleAmount;

      if (remainingDebt <= 0.01) {
        debtorIndex++;
      } else {
        debtors[debtorIndex] = MapEntry(debtor.key, remainingDebt);
      }

      if (remainingCredit <= 0.01) {
        creditorIndex++;
      } else {
        creditors[creditorIndex] = MapEntry(creditor.key, remainingCredit);
      }
    }

    return transactions;
  }
}