import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/services/audit_service.dart';
import '../../data/models/audit_log_model.dart';
import '../../data/repositories/profile_repository.dart';

class ActivityHistoryScreen extends ConsumerWidget {
  const ActivityHistoryScreen({super.key});

  void _confirmClearHistory(BuildContext context, WidgetRef ref, String userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All History?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Kya aap tamam recorded history clear karna chahte hain? Is se aapke active balances ya group records par koi asar nahi parega.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(auditServiceProvider).clearAllUserHistory(userId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('History cleared successfully!')),
                );
              }
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditLogsAsync = ref.watch(userAuditLogsStreamProvider);
    final user = ref.watch(profileRepositoryProvider).currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Activity & Audit History',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1E293B))),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
            tooltip: 'Clear History',
            onPressed: () {
              if (user != null) _confirmClearHistory(context, ref, user.uid);
            },
          ),
        ],
      ),
      body: auditLogsAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('No history entries recorded yet.',
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Personal & group transactions will be logged here permanently.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final log = logs[index];
              final isReceived = log.type == AuditType.settlementReceived;
              final isSent = log.type == AuditType.settlementSent;

              Color badgeColor = Colors.teal;
              IconData icon = Icons.receipt_long_rounded;

              if (isReceived) {
                badgeColor = const Color(0xFF059669);
                icon = Icons.call_received_rounded;
              } else if (isSent) {
                badgeColor = const Color(0xFFE11D48);
                icon = Icons.call_made_rounded;
              }

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: badgeColor.withValues(alpha: 0.12),
                    child: Icon(icon, color: badgeColor, size: 20),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(log.title,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1E293B))),
                      ),
                      Text(
                        'Rs. ${NumberFormat('#,##0.00').format(log.amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: isReceived ? const Color(0xFF059669) : (isSent ? const Color(0xFFE11D48) : const Color(0xFF1E293B)),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log.description, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (log.groupName != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6)),
                                child: Text('Group: ${log.groupName}',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              DateFormat('dd MMM yyyy, hh:mm a').format(log.timestamp),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading history: $e')),
      ),
    );
  }
}