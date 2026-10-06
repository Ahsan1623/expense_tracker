class PeerDebt {
  final String otherUserId;
  final double netAmount; // +ve: they owe you, -ve: you owe them

  PeerDebt({
    required this.otherUserId,
    required this.netAmount,
  });
}