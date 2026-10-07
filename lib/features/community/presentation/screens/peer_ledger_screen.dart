import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../groups/presentation/screens/group_detail_screen.dart';
import '../../domain/services/peer_ledger_service.dart';
import '../../data/repositories/direct_expense_repository.dart';
import '../../data/models/direct_expense_model.dart';
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

  void _showSettlePaymentDialog(
    BuildContext context,
    WidgetRef ref,
    String myUid,
    String myName,
    double settleAmount,
  ) {
    String selectedMethod = 'Cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Settle Dues',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                'A settlement request will be sent to ${peerUser.displayName}. Dues will only clear once accepted.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Amount You Owe:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Rs. ${settleAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Payment Method:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: ['Cash', 'Easypaisa', 'JazzCash', 'Bank Transfer']
                    .map((mode) {
                      final isSel = selectedMethod == mode;
                      return ChoiceChip(
                        label: Text(mode),
                        selected: isSel,
                        selectedColor: Colors.teal.shade100,
                        onSelected: (val) {
                          if (val) setModalState(() => selectedMethod = mode);
                        },
                      );
                    })
                    .toList(),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await ref
                        .read(directExpenseRepositoryProvider)
                        .directSettleUp(
                          payerId: myUid,
                          receiverId: peerUser.uid,
                          amount: settleAmount,
                          payerName: myName,
                          receiverName: peerUser.displayName,
                          paymentMode: selectedMethod,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Settlement request sent to ${peerUser.displayName}.',
                          ),
                          backgroundColor: Colors.teal.shade800,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceAll('Exception: ', ''),
                          ),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  'Send Settlement Request',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendPaymentReminder(BuildContext context, double amount) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PeerChatScreen(peerUser: peerUser),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Chat opened. You can remind ${peerUser.displayName} to settle Rs. ${amount.toStringAsFixed(0)}.',
        ),
        backgroundColor: Colors.teal.shade800,
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
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.teal,
            ),
            tooltip: 'Chat',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PeerChatScreen(peerUser: peerUser),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF475569)),
            onSelected: (val) async {
              if (val == 'clear_settled') {
                try {
                  await ref
                      .read(directExpenseRepositoryProvider)
                      .clearSettledEntries(myUid, peerUser.uid);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Cleared confirmed settlements from view.',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.toString().replaceAll('Exception: ', ''),
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'clear_settled',
                child: Row(
                  children: [
                    Icon(
                      Icons.cleaning_services_outlined,
                      size: 18,
                      color: Colors.teal,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Clear Settled Entries',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
              double directNet = 0.0;
              final List<DirectExpenseModel> visibleExpenses = [];

              for (final exp in directExpenses) {
                if (exp.isSettlement) {
                  // Agar settlement confirmed ho kar archive ho chuki hai to view se hide ho
                  if (exp.isArchived) continue;

                  visibleExpenses.add(exp);
                } else {
                  // Normal expense hamesha screen aur balance dono mein rahega!
                  if (exp.payerId == myUid) {
                    directNet += exp.owedAmount;
                  } else {
                    directNet -= exp.owedAmount;
                  }
                  visibleExpenses.add(exp);
                }
              }

              final totalConsolidated = groupSummary.totalNetAmount + directNet;
              final avatar = _getAvatar(peerUser.photoUrl);
              final activeMutualGroups = groupSummary.breakdowns
                  .where((b) => b.netAmount.abs() > 0.01)
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Hero Card
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
                          color:
                              (totalConsolidated >= 0
                                      ? Colors.teal
                                      : Colors.red)
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
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
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
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Text(
                                totalConsolidated > 0.01
                                    ? '${peerUser.displayName} owes you'
                                    : totalConsolidated < -0.01
                                    ? 'You owe ${peerUser.displayName}'
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
                              const SizedBox(height: 10),
                              if (totalConsolidated < -0.01)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.red.shade800,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.payment_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Settle All Dues',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onPressed: () => _showSettlePaymentDialog(
                                    context,
                                    ref,
                                    myUid,
                                    myName,
                                    totalConsolidated.abs(),
                                  ),
                                )
                              else if (totalConsolidated > 0.01)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.teal.shade800,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.notifications_active_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Request Payment / Remind',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onPressed: () => _sendPaymentReminder(
                                    context,
                                    totalConsolidated.abs(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

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
                        directNet > 0.01
                            ? '+Rs. ${directNet.abs().toStringAsFixed(0)}'
                            : directNet < -0.01
                            ? '-Rs. ${directNet.abs().toStringAsFixed(0)}'
                            : 'Settled',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: directNet > 0.01
                              ? const Color(0xFF059669)
                              : (directNet < -0.01
                                    ? const Color(0xFFE11D48)
                                    : Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (visibleExpenses.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          'No direct 1-to-1 expenses recorded.',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                  else
                    ...visibleExpenses.map((exp) {
                      final iAmPayer = exp.payerId == myUid;
                      final isSettlement = exp.isSettlement;
                      final isPending =
                          isSettlement && exp.settlementStatus == 'PENDING';
                      final iAmReceiver = exp.borrowerId == myUid;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isPending
                              ? const Color(0xFFFFFBEB)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: isPending
                              ? Border.all(
                                  color: Colors.amber.shade300,
                                  width: 1.2,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isSettlement
                                      ? (isPending
                                            ? Colors.amber.shade100
                                            : Colors.teal.shade50)
                                      : Colors.teal.shade50,
                                  child: Icon(
                                    isSettlement
                                        ? Icons.handshake_rounded
                                        : Icons.receipt_rounded,
                                    size: 18,
                                    color: isSettlement
                                        ? (isPending
                                              ? Colors.amber.shade900
                                              : Colors.teal.shade800)
                                        : Colors.teal.shade800,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exp.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Paid by ${iAmPayer ? 'You' : peerUser.displayName} • ${DateFormat('dd MMM, hh:mm a').format(exp.createdAt)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Rs. ${exp.owedAmount.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        color: iAmPayer
                                            ? const Color(0xFF059669)
                                            : const Color(0xFFE11D48),
                                      ),
                                    ),
                                    // Sirf aur sirf payer ke unsettled expense par delete ka icon aayega
                                    if (!isSettlement && iAmPayer) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.grey.shade400,
                                          size: 20,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Delete',
                                        onPressed: () async {
                                          try {
                                            await ref
                                                .read(
                                                  directExpenseRepositoryProvider,
                                                )
                                                .deleteDirectExpense(
                                                  uid1: myUid,
                                                  uid2: peerUser.uid,
                                                  currentUserId: myUid,
                                                  expense: exp,
                                                );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Expense deleted successfully.',
                                                  ),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    e.toString().replaceAll(
                                                      'Exception: ',
                                                      '',
                                                    ),
                                                  ),
                                                  backgroundColor:
                                                      Colors.redAccent,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),

                            // Settlement Action Footer
                            if (isPending) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                alignment: WrapAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade200,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      iAmReceiver
                                          ? 'Action Required'
                                          : 'Pending Approval',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                  if (iAmReceiver)
                                    Wrap(
                                      spacing: 6,
                                      children: [
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.teal.shade700,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            elevation: 0,
                                          ),
                                          icon: const Icon(
                                            Icons.check,
                                            size: 14,
                                          ),
                                          label: const Text(
                                            'Confirm',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onPressed: () async {
                                            try {
                                              await ref
                                                  .read(
                                                    directExpenseRepositoryProvider,
                                                  )
                                                  .respondToSettlement(
                                                    uid1: myUid,
                                                    uid2: peerUser.uid,
                                                    expenseId: exp.expenseId,
                                                    accept: true,
                                                    currentUserId: myUid,
                                                    currentUserName: myName,
                                                  );
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      e.toString().replaceAll(
                                                        'Exception: ',
                                                        '',
                                                      ),
                                                    ),
                                                    backgroundColor:
                                                        Colors.redAccent,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                Colors.red.shade700,
                                            side: BorderSide(
                                              color: Colors.red.shade200,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.close,
                                            size: 14,
                                          ),
                                          label: const Text(
                                            'Decline',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onPressed: () async {
                                            try {
                                              await ref
                                                  .read(
                                                    directExpenseRepositoryProvider,
                                                  )
                                                  .respondToSettlement(
                                                    uid1: myUid,
                                                    uid2: peerUser.uid,
                                                    expenseId: exp.expenseId,
                                                    accept: false,
                                                    currentUserId: myUid,
                                                    currentUserName: myName,
                                                  );
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      e.toString().replaceAll(
                                                        'Exception: ',
                                                        '',
                                                      ),
                                                    ),
                                                    backgroundColor:
                                                        Colors.redAccent,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 24),

                  if (activeMutualGroups.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Shared Groups Breakdown (Optimal Debt)',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Tap to open',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...activeMutualGroups.map((b) {
                      final groupNet = b.netAmount;

                      return InkWell(
                        onTap: () {
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
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                    : 'You owe ${peerUser.displayName} in this group',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: groupNet > 0
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFE11D48),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 60),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
