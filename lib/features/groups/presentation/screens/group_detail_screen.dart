import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../data/models/group_expense_model.dart';
import '../../data/models/group_model.dart';
import '../../data/repositories/group_expense_repository.dart';
import '../../data/repositories/group_repository.dart';
import '../../domain/services/debt_calculator.dart';
import '../../domain/services/debt_minimizer.dart';
import '../../../settlements/data/models/settlement_model.dart';
import '../../../settlements/data/models/payment_reminder_model.dart';
import '../../../settlements/data/repositories/settlement_repository.dart';
import '../../../settlements/presentation/widgets/settle_up_dialog.dart';
import '../widgets/add_group_expense_sheet.dart';
import '../../../community/data/repositories/community_repository.dart';
import '../../../../core/widgets/qr_display_dialog.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String initialName;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.initialName,
  });

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  String? _processingSettlementId;
  final Set<String> _dismissedRejectedIds = {};
  bool _showAuditTrail = false;

  void _showAddMemberDialog() {
    final emailCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final contactsAsync = ref.watch(communityContactsStreamProvider);

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Add Member to Group',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter member email or select from the community below:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Member Email',
                      hintText: 'user@example.com',
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  contactsAsync.when(
                    data: (contacts) {
                      if (contacts.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'From Community:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: contacts
                                .map(
                                  (c) => ActionChip(
                                    label: Text(
                                      c.displayName,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor: Colors.teal.shade50,
                                    onPressed: () {
                                      emailCtrl.text = c.email;
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (error, stack) => const SizedBox.shrink(),
                  ),
                ],
              ),
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
                onPressed: isLoading
                    ? null
                    : () async {
                        final email = emailCtrl.text.trim();
                        if (email.isEmpty) return;
                        setDialogState(() => isLoading = true);
                        try {
                          await ref
                              .read(groupRepositoryProvider)
                              .addMemberByEmail(
                                groupId: widget.groupId,
                                email: email,
                              );
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$email added to the group!'),
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
                        } finally {
                          setDialogState(() => isLoading = false);
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Add Member'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleDeleteGroup(
    BuildContext context,
    GroupModel group,
    String currentUserId,
  ) {
    final isAdmin = group.createdById == currentUserId;
    final hasPendingDebt = group.netBalances.values.any(
      (val) => val.abs() > 0.01,
    );

    if (!isAdmin && hasPendingDebt) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
              SizedBox(width: 8),
              Text(
                'Cannot Delete Group',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          content: const Text(
            'There are pending debts in the group. Only the Group Creator (Admin) can delete it at any time.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isAdmin && hasPendingDebt ? 'Force Delete Group?' : 'Delete Group?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isAdmin && hasPendingDebt
              ? 'You are the group creator (Admin). There are still pending debts in the group; are you sure you want to force delete the group?'
              : 'Are you sure you want to permanently delete this group? All expenses and history will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(groupExpenseRepositoryProvider)
                    .deleteGroup(
                      groupId: widget.groupId,
                      currentUserId: currentUserId,
                    );
                if (context.mounted) Navigator.pop(context);
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSettlementLockedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text(
              'Expense Locked',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: const Text(
          'Settlements have already been confirmed in this group. Deleting any past expense will disrupt member balances.\n\nPlease add a new expense to make adjustments.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteExpense(
    BuildContext context,
    GroupExpenseModel expense,
    String currentUserId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Expense?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Deleting "${expense.title}" will automatically reverse the balances of all members.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(groupExpenseRepositoryProvider)
                    .deleteGroupExpense(
                      groupId: widget.groupId,
                      expense: expense,
                      currentUserId: currentUserId,
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveSettlement(SettlementModel settlement) async {
    setState(() => _processingSettlementId = settlement.settlementId);
    try {
      await ref
          .read(settlementRepositoryProvider)
          .confirmSettlement(settlement: settlement);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Settlement of Rs. ${settlement.amount.toStringAsFixed(0)} confirmed! Balance updated.',
            ),
            backgroundColor: Colors.teal.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settlement Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingSettlementId = null);
    }
  }

  Future<void> _declineSettlement(SettlementModel settlement) async {
    setState(() => _processingSettlementId = settlement.settlementId);
    try {
      await ref
          .read(settlementRepositoryProvider)
          .rejectSettlement(
            groupId: widget.groupId,
            settlementId: settlement.settlementId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settlement request declined.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingSettlementId = null);
    }
  }

  Future<void> _handleSendReminder({
    required String groupId,
    required String myUid,
    required String targetUserId,
    required String targetUserName,
    required double amount,
  }) async {
    try {
      await ref
          .read(settlementRepositoryProvider)
          .sendPaymentReminder(
            groupId: groupId,
            fromUserId: myUid,
            toUserId: targetUserId,
            amount: amount,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment reminder sent to $targetUserName!'),
            backgroundColor: Colors.teal.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.orange.shade900,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(singleGroupStreamProvider(widget.groupId));
    final expensesAsync = ref.watch(
      groupExpensesStreamProvider(widget.groupId),
    );
    final settlementsAsync = ref.watch(
      groupSettlementsProvider(widget.groupId),
    );
    final remindersAsync = ref.watch(groupRemindersProvider(widget.groupId));
    final currentUser = ref.watch(authStateProvider).value;

    return groupAsync.when(
      data: (group) {
        if (group == null) {
          return const Scaffold(body: Center(child: Text('Group not found')));
        }

        final myUid = currentUser?.uid ?? '';
        final myTotalBalance = group.netBalances[myUid] ?? 0.0;
        final memberProfilesAsync = ref.watch(
          groupMembersProfilesProvider(group.members),
        );
        final namesMap = memberProfilesAsync.value ?? {};

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Text(
              group.name,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFF1E293B),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_rounded, color: Colors.teal),
                tooltip: 'Group Invite QR',
                onPressed: () {
                  QrDisplayDialog.show(
                    context,
                    title: 'Group Invite QR',
                    subtitle: 'Scan to join this group instantly.',
                    type: QrPayloadType.groupInvite,
                    payloadId: widget.groupId,
                    extraData: widget.initialName,
                  );
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: Colors.teal,
                ),
                tooltip: 'Add Member',
                onPressed: _showAddMemberDialog,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (val) {
                  if (val == 'delete_group') {
                    _handleDeleteGroup(context, group, myUid);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'delete_group',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_forever_rounded,
                          color: Colors.red,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Delete Group',
                          style: TextStyle(
                            color: Colors.red,
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
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => AddGroupExpenseSheet(group: group),
              );
            },
            backgroundColor: Colors.teal.shade600,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: const Text(
              'Add Expense',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Hero Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: myTotalBalance >= 0
                      ? const Color(0xFF0F766E)
                      : const Color(0xFFBE123C),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: (myTotalBalance >= 0 ? Colors.teal : Colors.red)
                          .withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      myTotalBalance >= 0
                          ? 'Total you are owed in this group'
                          : 'Total you owe in this group',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rs. ${NumberFormat('#,##0.00').format(myTotalBalance.abs())}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${group.members.length} Active Members Synced Live',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Pending Reminders Feed
              remindersAsync.when(
                data: (reminders) {
                  final myReminders = reminders
                      .where((r) => r.toUserId == myUid)
                      .toList();
                  if (myReminders.isEmpty) return const SizedBox.shrink();

                  return Column(
                    children: myReminders.map((reminder) {
                      final requesterName =
                          namesMap[reminder.fromUserId] ?? 'Member';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.notifications_active_rounded,
                              color: Color(0xFFB45309),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$requesterName requested payment of Rs. ${reminder.amount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF78350F),
                                ),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB45309),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 4,
                                ),
                                minimumSize: const Size(50, 32),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () async {
                                await ref
                                    .read(settlementRepositoryProvider)
                                    .dismissReminder(
                                      groupId: widget.groupId,
                                      reminderId: reminder.reminderId,
                                    );
                              },
                              child: const Text(
                                'OK',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (error, stack) => const SizedBox.shrink(),
              ),

              // Pending Settlement Handshakes
              settlementsAsync.when(
                data: (settlements) {
                  final pendingForMe = settlements
                      .where(
                        (s) =>
                            s.toUserId == myUid &&
                            s.status == SettlementStatus.pending,
                      )
                      .toList();

                  final myRecentRequests = settlements
                      .where(
                        (s) =>
                            s.fromUserId == myUid &&
                            !_dismissedRejectedIds.contains(s.settlementId),
                      )
                      .take(3)
                      .toList();

                  return Column(
                    children: [
                      ...pendingForMe.map((settlement) {
                        final senderName =
                            namesMap[settlement.fromUserId] ?? 'A member';
                        final isProcessing =
                            _processingSettlementId == settlement.settlementId;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.handshake_rounded,
                                    color: Color(0xFFD97706),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '$senderName sent Rs. ${settlement.amount.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Note: "${settlement.note}"',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF78350F),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (isProcessing)
                                const Center(
                                  child: SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              else
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                      ),
                                      onPressed: () =>
                                          _declineSettlement(settlement),
                                      child: const Text('Decline'),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal.shade700,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () =>
                                          _approveSettlement(settlement),
                                      child: const Text('Confirm Received'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      }),
                      ...myRecentRequests.map((settlement) {
                        final receiverName =
                            namesMap[settlement.toUserId] ?? 'Member';

                        if (settlement.status == SettlementStatus.pending) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 18,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Settlement of Rs. ${settlement.amount.toStringAsFixed(0)} sent to $receiverName. Waiting for confirmation.',
                                    style: TextStyle(
                                      color: Colors.blue.shade900,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else if (settlement.status ==
                            SettlementStatus.rejected) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.cancel_rounded,
                                  size: 18,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$receiverName declined your settlement of Rs. ${settlement.amount.toStringAsFixed(0)}.',
                                    style: TextStyle(
                                      color: Colors.red.shade900,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () => _dismissedRejectedIds.add(
                                        settlement.settlementId,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (error, stack) => const SizedBox.shrink(),
              ),

              // Greedy Optimized Settlements (Default Standardized View)
              expensesAsync.when(
                data: (expenses) {
                  final allPeerDebts = DebtCalculator.calculatePeerDebts(
                    currentUserId: myUid,
                    allMemberIds: group.members,
                    expenses: expenses,
                  );

                  final allSettlements =
                      settlementsAsync.value ?? <SettlementModel>[];
                  final allReminders =
                      remindersAsync.value ?? <PaymentReminderModel>[];

                  // Minimized Cash Flow using Greedy Graph Solver
                  final simplifiedTrans = DebtMinimizer.simplifyDebts(
                    group.netBalances,
                  );

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
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
                            const Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Colors.teal,
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Optimal Debt Settlements',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${simplifiedTrans.length} Transfers',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Circular debts automatically cancelled. Pay directly through these minimum transfers:',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (simplifiedTrans.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: Colors.teal,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'All settled up! Group has zero outstanding debts.',
                                  style: TextStyle(
                                    color: Colors.teal,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...simplifiedTrans.map((tx) {
                            final fromName =
                                namesMap[tx.fromUserId] ?? 'Member';
                            final toName = namesMap[tx.toUserId] ?? 'Member';
                            final iAmSender = tx.fromUserId == myUid;
                            final iAmReceiver = tx.toUserId == myUid;

                            final hasPendingSettlement = allSettlements.any(
                              (s) =>
                                  s.fromUserId == myUid &&
                                  s.toUserId == tx.toUserId &&
                                  s.status == SettlementStatus.pending,
                            );

                            final hasRecentReminder = allReminders.any(
                              (r) =>
                                  r.fromUserId == myUid &&
                                  r.toUserId == tx.fromUserId &&
                                  DateTime.now()
                                          .difference(r.createdAt)
                                          .inMinutes <
                                      60,
                            );

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: (iAmSender || iAmReceiver)
                                    ? (iAmSender
                                          ? const Color(0xFFFFF1F2)
                                          : const Color(0xFFECFDF5))
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: (iAmSender || iAmReceiver)
                                      ? (iAmSender
                                            ? Colors.red.shade200
                                            : Colors.teal.shade200)
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: iAmSender
                                        ? Colors.red.shade100
                                        : (iAmReceiver
                                              ? Colors.teal.shade100
                                              : Colors.grey.shade200),
                                    child: Icon(
                                      Icons.swap_horiz_rounded,
                                      size: 16,
                                      color: iAmSender
                                          ? Colors.red.shade800
                                          : (iAmReceiver
                                                ? Colors.teal.shade800
                                                : Colors.grey.shade700),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text.rich(
                                          TextSpan(
                                            text: iAmSender ? 'You' : fromName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                            children: [
                                              const TextSpan(
                                                text: ' pays ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.normal,
                                                ),
                                              ),
                                              TextSpan(
                                                text: iAmReceiver
                                                    ? 'You'
                                                    : toName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          'Rs. ${tx.amount.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: iAmSender
                                                ? const Color(0xFFE11D48)
                                                : (iAmReceiver
                                                      ? const Color(0xFF059669)
                                                      : const Color(
                                                          0xFF1E293B,
                                                        )),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Action Button for active participant
                                  if (iAmSender)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: hasPendingSettlement
                                            ? Colors.grey.shade300
                                            : Colors.teal.shade600,
                                        foregroundColor: hasPendingSettlement
                                            ? Colors.grey.shade600
                                            : Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        minimumSize: const Size(60, 30),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: hasPendingSettlement
                                          ? null
                                          : () {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) =>
                                                    SettleUpDialog(
                                                      groupId: widget.groupId,
                                                      currentUserId: myUid,
                                                      targetUserId: tx.toUserId,
                                                      targetUserName: toName,
                                                      defaultAmount: tx.amount,
                                                    ),
                                              );
                                            },
                                      child: Text(
                                        hasPendingSettlement
                                            ? 'Pending...'
                                            : 'Settle',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  if (iAmReceiver)
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: hasRecentReminder
                                            ? Colors.grey.shade400
                                            : Colors.teal.shade700,
                                        side: BorderSide(
                                          color: hasRecentReminder
                                              ? Colors.grey.shade300
                                              : Colors.teal.shade300,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        minimumSize: const Size(64, 30),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: hasRecentReminder
                                          ? null
                                          : () => _handleSendReminder(
                                              groupId: widget.groupId,
                                              myUid: myUid,
                                              targetUserId: tx.fromUserId,
                                              targetUserName: fromName,
                                              amount: tx.amount,
                                            ),
                                      child: Text(
                                        hasRecentReminder
                                            ? 'Requested'
                                            : 'Remind',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: hasRecentReminder
                                              ? Colors.grey.shade400
                                              : Colors.teal.shade700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),

                        const SizedBox(height: 10),
                        const Divider(height: 16),

                        // Interactive Transparency Audit Trail
                        InkWell(
                          onTap: () => setState(
                            () => _showAuditTrail = !_showAuditTrail,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _showAuditTrail
                                          ? Icons.visibility_off_rounded
                                          : Icons.info_outline_rounded,
                                      size: 15,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _showAuditTrail
                                          ? 'Hide Raw Calculation Audit'
                                          : 'How was this calculated? (Audit Trail)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  _showAuditTrail
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_showAuditTrail) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Raw Direct Balances (Before Minimization):',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ...allPeerDebts
                                    .where((d) => d.netAmount.abs() > 0.01)
                                    .map((debt) {
                                      final name =
                                          namesMap[debt.otherUserId] ??
                                          'Member';
                                      final net = debt.netAmount;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 2,
                                        ),
                                        child: Text(
                                          net > 0
                                              ? '• $name owes you Rs. ${net.toStringAsFixed(0)} directly'
                                              : '• You owe $name Rs. ${net.abs().toStringAsFixed(0)} directly',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      );
                                    }),
                                const SizedBox(height: 6),
                                Text(
                                  'Greedy solver matched net creditors & debtors to cut loop transactions.',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.teal.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (error, stack) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 24),

              const Text(
                'Group Shared Log',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),

              // Group Shared Expenses Feed
              expensesAsync.when(
                data: (expenses) {
                  if (expenses.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: Center(
                        child: Text(
                          'No shared expenses yet.\nHit "+ Add Expense" to split bills!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final exp = expenses[index];
                      final isMyPayment = exp.paidByUserId == myUid;
                      final payerName = namesMap[exp.paidByUserId] ?? 'Member';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: exp.title.startsWith('Settled:')
                                ? Colors.amber.shade50
                                : Colors.teal.shade50,
                            child: Icon(
                              exp.title.startsWith('Settled:')
                                  ? Icons.handshake_rounded
                                  : Icons.receipt_long_rounded,
                              color: exp.title.startsWith('Settled:')
                                  ? Colors.amber.shade800
                                  : Colors.teal.shade700,
                            ),
                          ),
                          title: Text(
                            exp.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          subtitle: Text(
                            'Paid by ${isMyPayment ? 'You' : payerName} • ${DateFormat('dd MMM, hh:mm a').format(exp.createdAt)}',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Rs. ${NumberFormat('#,##0.00').format(exp.totalAmount)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              if (isMyPayment &&
                                  !exp.title.startsWith('Settled:')) ...[
                                const SizedBox(width: 4),
                                Builder(
                                  builder: (context) {
                                    final hasApprovedSettlement =
                                        (settlementsAsync.value ?? []).any(
                                          (s) =>
                                              s.status ==
                                              SettlementStatus.approved,
                                        );

                                    if (hasApprovedSettlement) {
                                      return IconButton(
                                        icon: Icon(
                                          Icons.lock_outline_rounded,
                                          color: Colors.amber.shade700,
                                          size: 18,
                                        ),
                                        tooltip:
                                            'Locked: Settlement already approved',
                                        onPressed: () =>
                                            _showSettlementLockedDialog(
                                              context,
                                            ),
                                      );
                                    }

                                    return IconButton(
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.grey.shade400,
                                        size: 20,
                                      ),
                                      tooltip: 'Delete your expense',
                                      onPressed: () => _confirmDeleteExpense(
                                        context,
                                        exp,
                                        myUid,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, stack) => Text('Error loading feed: $e'),
              ),
              const SizedBox(height: 60),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, stack) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}
