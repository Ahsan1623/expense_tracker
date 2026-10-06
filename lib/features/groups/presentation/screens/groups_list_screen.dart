import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/group_repository.dart';
import '../widgets/create_group_sheet.dart';
import 'group_detail_screen.dart';
import '../../../notifications/presentation/widgets/notification_bell_icon.dart';

class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(userGroupsProvider);
    final currentUser = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Shared Groups',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF1E293B),
          ),
        ),
        actions: const [
          NotificationBellIcon(), // <-- Bell icon yahan AppBar me add ho gaya
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
            builder: (context) => const CreateGroupSheet(),
          );
        },
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('New Group', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: groupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.groups_3_rounded, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No shared groups yet.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create a group for trips, roommates, or events!',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final group = groups[index];
              final myUid = currentUser?.uid ?? '';
              final myBalance = group.netBalances[myUid] ?? 0.0;

              return Container(
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
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.teal.shade50,
                    child: Icon(Icons.group_rounded, color: Colors.teal.shade800),
                  ),
                  title: Text(
                    group.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${group.members.length} members • Created by ${group.createdById == myUid ? 'You' : 'Admin'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        myBalance > 0
                            ? '+Rs. ${NumberFormat('#,##0').format(myBalance)}'
                            : myBalance < 0
                                ? '-Rs. ${NumberFormat('#,##0').format(myBalance.abs())}'
                                : 'Settled',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: myBalance > 0
                              ? const Color(0xFF059669)
                              : (myBalance < 0 ? const Color(0xFFE11D48) : Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        myBalance > 0
                            ? 'you are owed'
                            : myBalance < 0
                                ? 'you owe'
                                : '0 pending',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: myBalance > 0
                              ? const Color(0xFF059669)
                              : (myBalance < 0 ? const Color(0xFFE11D48) : Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupDetailScreen(
                          groupId: group.groupId,
                          initialName: group.name,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading groups: $e')),
      ),
    );
  }
}