import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_tracker/features/community/data/repositories/community_repository.dart';
import 'package:expense_tracker/features/auth/presentation/controllers/auth_controller.dart';
import 'package:expense_tracker/features/notifications/presentation/widgets/notification_bell_icon.dart';
import 'package:expense_tracker/features/community/presentation/widgets/community_contact_tile.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final _emailController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSending = false;

  void _showAddFriendDialog() {
    _emailController.clear();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Add Connection',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children:[
              const Text(
                'Enter your friends registered email so they can join your financial community.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Friend Email',
                  hintText: 'dost@example.com',
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
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
              onPressed: _isSending
                  ? null
                  : () async {
                      final email = _emailController.text.trim();
                      if (email.isEmpty) return;

                      setDialogState(() => _isSending = true);
                      try {
                        await ref
                            .read(communityRepositoryProvider)
                            .sendConnectionRequest(email);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Request sent to $email!'),
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
                        setDialogState(() => _isSending = false);
                      }
                    },
              child: _isSending
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveFriend(String peerUid, String peerName) {
    final myUid = ref.read(authStateProvider).value?.uid ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove $peerName?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to remove $peerName from your community? If there are any pending balances in shared groups or direct ledgers, they will not be able to be removed.',
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
                    .read(communityRepositoryProvider)
                    .removeConnection(
                      currentUserId: myUid,
                      targetUserId: peerUid,
                    );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$peerName removed from community.'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(authStateProvider).value?.uid ?? '';
    final incomingRequestsAsync = ref.watch(incomingRequestsStreamProvider);
    final contactsAsync = ref.watch(communityContactsStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'My Community',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF1E293B),
          ),
        ),
        actions: [
          const NotificationBellIcon(),
          IconButton(
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
              color: Colors.teal,
            ),
            tooltip: 'Add Connection',
            onPressed: _showAddFriendDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade700, const Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.hub_rounded, color: Colors.white, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verified Financial Circle',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tap on any contact to view their 1-to-1 cross-group and direct accounting information.',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Live Search Bar
          TextField(
            controller: _searchController,
            onChanged: (val) =>
                setState(() => _searchQuery = val.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search connections by name or email...',
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.teal),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Incoming Pending Requests
          incomingRequestsAsync.when(
            data: (requests) {
              if (requests.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Pending Invitations',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade700,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${requests.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...requests.map(
                    (req) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.amber.shade100,
                            child: Text(
                              req.senderName.isNotEmpty
                                  ? req.senderName[0].toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  req.senderName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                                Text(
                                  req.senderEmail,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            onPressed: () => ref
                                .read(communityRepositoryProvider)
                                .declineRequest(req.requestId),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.check_rounded,
                              color: Colors.teal,
                              size: 22,
                            ),
                            onPressed: () => ref
                                .read(communityRepositoryProvider)
                                .acceptRequest(req),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (error, stack) => const SizedBox.shrink(),
          ),

          // Mutual Contacts List with dynamic net balance badges
          const Text(
            'Mutual Connections',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 10),

          contactsAsync.when(
            data: (contacts) {
              final filteredContacts = contacts.where((c) {
                if (_searchQuery.isEmpty) return true;
                return c.displayName.toLowerCase().contains(_searchQuery) ||
                    c.email.toLowerCase().contains(_searchQuery);
              }).toList();

              if (filteredContacts.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No connections yet.'
                              : 'No matching connections found.',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Tap the '
                                    ' icon in the top right to invite friends!'
                              : 'Try searching with another name or email.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Container(
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
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredContacts.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (context, index) {
                    final friend = filteredContacts[index];
                    return CommunityContactTile(
                      friend: friend,
                      currentUserId: myUid,
                      onRemove: () =>
                          _confirmRemoveFriend(friend.uid, friend.displayName),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}
