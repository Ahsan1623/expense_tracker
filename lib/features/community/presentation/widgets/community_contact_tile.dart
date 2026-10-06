import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:expense_tracker/features/auth/data/models/user_model.dart';
import 'package:expense_tracker/features/community/domain/services/peer_ledger_service.dart';
import 'package:expense_tracker/features/community/data/repositories/direct_expense_repository.dart';
import 'package:expense_tracker/features/community/presentation/screens/peer_ledger_screen.dart';
import 'package:expense_tracker/core/widgets/image_preview_dialog.dart';

class CommunityContactTile extends ConsumerWidget {
  final UserModel friend;
  final String currentUserId;
  final VoidCallback onRemove;

  const CommunityContactTile({
    super.key,
    required this.friend,
    required this.currentUserId,
    required this.onRemove,
  });

  ImageProvider? _getAvatar(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    if (photoUrl.startsWith('data:image')) {
      final base64Data = photoUrl.split(',').last;
      return MemoryImage(base64Decode(base64Data));
    }
    return NetworkImage(photoUrl);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Group-level ledger stream
    final groupLedgerAsync = ref.watch(
      peerLedgerProvider((myUid: currentUserId, peerUid: friend.uid)),
    );

    // 2. Direct 1-to-1 expense stream
    final directExpensesAsync = ref.watch(
      directExpensesStreamProvider((myUid: currentUserId, peerUid: friend.uid)),
    );

    double groupNet = groupLedgerAsync.value?.totalNetAmount ?? 0.0;
    double directNet = 0.0;

    final directExpenses = directExpensesAsync.value ?? [];
    for (final exp in directExpenses) {
      if (exp.isSettlement) {
        if (exp.payerId == currentUserId) {
          directNet += exp.owedAmount;
        } else {
          directNet -= exp.owedAmount;
        }
      } else {
        if (exp.payerId == currentUserId) {
          directNet += exp.owedAmount;
        } else {
          directNet -= exp.owedAmount;
        }
      }
    }

    final totalNet = groupNet + directNet;
    final avatar = _getAvatar(friend.photoUrl);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: GestureDetector(
        onTap: () {
          if (friend.photoUrl != null && friend.photoUrl!.isNotEmpty) {
            ImagePreviewDialog.show(
              context,
              photoUrl: friend.photoUrl,
              title: friend.displayName,
            );
          }
        },
        child: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.teal.shade50,
          backgroundImage: avatar,
          child: avatar == null
              ? Text(
                  friend.displayName.isNotEmpty
                      ? friend.displayName[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800,
                  ),
                )
              : null,
        ),
      ),
      title: Text(
        friend.displayName,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            friend.email,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 3),
          if (totalNet > 0.01)
            Text(
              'owes you Rs. ${NumberFormat('#,##0').format(totalNet)}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF059669),
              ),
            )
          else if (totalNet < -0.01)
            Text(
              'you owe Rs. ${NumberFormat('#,##0').format(totalNet.abs())}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE11D48),
              ),
            )
          else
            const Text(
              'All settled up (Rs. 0)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: totalNet > 0.01
                  ? const Color(0xFFECFDF5)
                  : totalNet < -0.01
                      ? const Color(0xFFFFF1F2)
                      : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              totalNet > 0.01
                  ? '+Rs. ${totalNet.toStringAsFixed(0)}'
                  : totalNet < -0.01
                      ? '-Rs. ${totalNet.abs().toStringAsFixed(0)}'
                      : 'Rs. 0',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: totalNet > 0.01
                    ? const Color(0xFF059669)
                    : totalNet < -0.01
                        ? const Color(0xFFE11D48)
                        : Colors.grey.shade600,
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
            onSelected: (val) {
              if (val == 'remove') {
                onRemove();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.person_remove_rounded, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Remove Contact',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PeerLedgerScreen(peerUser: friend),
          ),
        );
      },
    );
  }
}