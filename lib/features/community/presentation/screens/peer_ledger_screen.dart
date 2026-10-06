import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../groups/presentation/screens/group_detail_screen.dart';
import '../../domain/services/peer_ledger_service.dart';
import '../../data/repositories/direct_expense_repository.dart';
import '../widgets/add_direct_expense_sheet.dart';
import 'peer_chat_screen.dart';
import '../../../../core/widgets/image_preview_dialog.dart';

class PeerLedgerScreen extends ConsumerWidget {
  final UserModel peerUser;

  const PeerLedgerScreen({super.key, required this.peerUser});

  ImageProvider? _getAvatar(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    if (photoUrl.startsWith('data:image')) {
      final base64Data = photoUrl.split(',').last;
      return MemoryImage(base64Decode(base64Data));
    }
    return NetworkImage(photoUrl);
  }

  void _showSettleAllDialog(
    BuildContext context,
    WidgetRef ref,
    String myUid,
    String myName,
    double totalConsolidated,
  ) {
    final isPaying = totalConsolidated < 0;
    final settleAmount = totalConsolidated.abs();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isPaying ? 'Settle All Dues' : 'Receive Settlement',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          isPaying
              ? 'Kya aap ${peerUser.displayName} ko Rs. ${settleAmount.toStringAsFixed(0)} ada karke tamam direct aur shared hisaab settle karna chahte hain?'
              : 'Kya ${peerUser.displayName} ne aapko total Rs. ${settleAmount.toStringAsFixed(0)} direct ada kar diye hain?',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(directExpenseRepositoryProvider).directSettleUp(
                      payerId: isPaying ? myUid : peerUser.uid,
                      receiverId: isPaying ? peerUser.uid : myUid,
                      amount: settleAmount,
                      payerName: isPaying ? myName : peerUser.displayName,
                      receiverName: isPaying ? peerUser.displayName : myName,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Total dues of Rs. ${settleAmount.toStringAsFixed(0)} settled!'),
                      backgroundColor: Colors.teal.shade800,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('Confirm Settle All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider).value;
    final myUid = currentUser?.uid ?? '';
    final myName = currentUser?.displayName ?? 'User';

    final groupLedgerAsync = ref.watch(
      peerLedgerProvider((myUid: myUid, peerUid: peerUser.uid)),
    );
    final directExpensesAsync = ref.watch(
      directExpensesStreamProvider((myUid: myUid, peerUid: peerUser.uid)),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          peerUser.displayName,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF1E293B),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.teal),
            tooltip: 'Open Chat',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PeerChatScreen(peerUser: peerUser),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text(
              'Add 1-to-1 Expense',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => AddDirectExpenseSheet(
                  myUid: myUid,
                  myName: myName,
                  peerUser: peerUser,
                ),
              );
            },
          ),
        ),
      ),
      body: groupLedgerAsync.when(
        data: (groupSummary) {
          return directExpensesAsync.when(
            data: (directExpenses) {
              // Exact Reconciled Direct Net Calculation
              double directNet = 0.0;
              for (final exp in directExpenses) {
                if (exp.isSettlement) {
                  if (exp.payerId == myUid) {
                    directNet += exp.owedAmount; // maine settle pay kiya
                  } else {
                    directNet -= exp.owedAmount; // peer ne mujhe settle pay kiya
                  }
                } else {
                  if (exp.payerId == myUid) {
                    directNet += exp.owedAmount; // peer owes me
                  } else {
                    directNet -= exp.owedAmount; // I owe peer
                  }
                }
              }

              final totalConsolidated = groupSummary.totalNetAmount + directNet;
              final avatar = _getAvatar(peerUser.photoUrl);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Hero Consolidated Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: totalConsolidated >= 0
                            ? [const Color(0xFF0F766E), Colors.teal.shade800]
                            : [const Color(0xFFBE123C), Colors.red.shade900],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: (totalConsolidated >= 0 ? Colors.teal : Colors.red)
                              .withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (peerUser.photoUrl != null &&
                                peerUser.photoUrl!.isNotEmpty) {
                              ImagePreviewDialog.show(
                                context,
                                photoUrl: peerUser.photoUrl,
                                title: peerUser.displayName,
                              );
                            }
                          },
                          child: CircleAvatar(
                            radius: 32,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            backgroundImage: avatar,
                            child: avatar == null
                                ? Text(
                                    peerUser.displayName.isNotEmpty
                                        ? peerUser.displayName[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          peerUser.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          peerUser.email,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Text(
                                totalConsolidated > 0
                                    ? 'Overall, ${peerUser.displayName} owes you'
                                    : totalConsolidated < 0
                                        ? 'Overall, you owe ${peerUser.displayName}'
                                        : 'You and ${peerUser.displayName} are all settled up!',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rs. ${NumberFormat('#,##0.00').format(totalConsolidated.abs())}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (totalConsolidated.abs() > 0.01) ...[
                                const SizedBox(height: 10),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: totalConsolidated > 0
                                        ? Colors.teal.shade800
                                        : Colors.red.shade800,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.handshake_rounded, size: 16),
                                  label: const Text(
                                    'Settle All Dues',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onPressed: () => _showSettleAllDialog(
                                    context,
                                    ref,
                                    myUid,
                                    myName,
                                    totalConsolidated,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section 1: Direct 1-to-1 Ledger
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Direct 1-to-1 Ledger',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        directNet > 0
                            ? '+Rs. ${directNet.abs().toStringAsFixed(0)}'
                            : directNet < 0
                                ? '-Rs. ${directNet.abs().toStringAsFixed(0)}'
                                : 'Settled',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: directNet > 0
                              ? const Color(0xFF059669)
                              : (directNet < 0
                                  ? const Color(0xFFE11D48)
                                  : Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (directExpenses.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          'No direct 1-to-1 expenses yet.\nTap "Add 1-to-1 Expense" to record non-group debts.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                  else
                    ...directExpenses.map((exp) {
                      final iAmPayer = exp.payerId == myUid;
                      final isSettlement = exp.isSettlement;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: isSettlement
                                ? Colors.amber.shade50
                                : Colors.teal.shade50,
                            child: Icon(
                              isSettlement
                                  ? Icons.handshake_rounded
                                  : Icons.receipt_rounded,
                              size: 16,
                              color: isSettlement
                                  ? Colors.amber.shade800
                                  : Colors.teal.shade800,
                            ),
                          ),
                          title: Text(
                            exp.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            'Paid by ${iAmPayer ? 'You' : peerUser.displayName} • ${DateFormat('dd MMM').format(exp.createdAt)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Rs. ${exp.owedAmount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: iAmPayer
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFE11D48),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Sirf payer aur NON-SETTLEMENT par delete icon show hoga
                              if (iAmPayer && !isSettlement)
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.grey.shade400,
                                    size: 16,
                                  ),
                                  onPressed: () async {
                                    try {
                                      await ref
                                          .read(directExpenseRepositoryProvider)
                                          .deleteDirectExpense(
                                            uid1: myUid,
                                            uid2: peerUser.uid,
                                            currentUserId: myUid,
                                            expense: exp,
                                          );
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(e.toString().replaceAll('Exception: ', '')),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 24),

                  // Section 2: Shared Groups Breakdown (Direct Group Redirection)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Shared Groups Breakdown',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'Tap group to open',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (groupSummary.breakdowns.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          'No mutual groups found with ${peerUser.displayName}.',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                  else
                    ...groupSummary.breakdowns.map((b) {
                      final groupNet = b.netAmount;

                      return InkWell(
                        onTap: () {
                          // Seedha group screen par navigate karein
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GroupDetailScreen(
                                groupId: b.group.groupId,
                                initialName: b.group.name,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: Colors.teal.shade50,
                                        child: Icon(
                                          Icons.group_rounded,
                                          size: 16,
                                          color: Colors.teal.shade800,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        b.group.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'Rs. ${groupNet.abs().toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: groupNet > 0
                                              ? const Color(0xFF059669)
                                              : (groupNet < 0
                                                  ? const Color(0xFFE11D48)
                                                  : Colors.grey),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 12,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                groupNet > 0
                                    ? '${peerUser.displayName} owes you in this group'
                                    : groupNet < 0
                                        ? 'You owe ${peerUser.displayName} in this group'
                                        : 'Settled in this group',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: groupNet > 0
                                      ? const Color(0xFF059669)
                                      : (groupNet < 0
                                          ? const Color(0xFFE11D48)
                                          : Colors.grey),
                                ),
                              ),
                              if (b.sharedExpenses.isNotEmpty) ...[
                                const Divider(height: 18),
                                Text(
                                  '${b.sharedExpenses.length} shared expense entries in this group',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 60),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Direct Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Group Error: $e')),
      ),
    );
  }
}