import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_tracker/features/auth/presentation/controllers/auth_controller.dart';
import 'package:expense_tracker/features/groups/data/repositories/group_repository.dart';
import 'package:expense_tracker/features/community/data/repositories/community_repository.dart';

class CreateGroupSheet extends ConsumerStatefulWidget {
  const CreateGroupSheet({super.key});

  @override
  ConsumerState<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<CreateGroupSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _emailController = TextEditingController();
  final List<String> _memberEmails = [];
  bool _isLoading = false;

  void _addEmail() {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isNotEmpty && !_memberEmails.contains(email)) {
      setState(() {
        _memberEmails.add(email);
        _emailController.clear();
      });
    }
  }

  void _toggleCommunityMember(String email) {
    setState(() {
      if (_memberEmails.contains(email)) {
        _memberEmails.remove(email);
      } else {
        _memberEmails.add(email);
      }
    });
  }

  Future<void> _handleCreateGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter group name')),
      );
      return;
    }

    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) return;

    setState(() => _isLoading = true);
    try {
      final desc = _descController.text.trim().isEmpty
          ? 'Shared Expenses'
          : _descController.text.trim();

      await ref.read(groupRepositoryProvider).createGroup(
            name: name,
            description: desc,
            creatorId: currentUser.uid,
            initialMemberEmails: _memberEmails,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Group "$name" created with ${_memberEmails.length + 1} members!'),
            backgroundColor: Colors.teal.shade800,
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(communityContactsStreamProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
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
              'Create New Group',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Group Name',
                hintText: 'e.g. Hostel Expense, Trip to Murree',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'e.g. Monthly flat bills',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Community Contacts Quick Picker
            contactsAsync.when(
              data: (contacts) {
                if (contacts.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pick from Community (1-Tap Add):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: contacts.map((c) {
                        final isSelected =
                            _memberEmails.contains(c.email.toLowerCase());
                        return FilterChip(
                          selected: isSelected,
                          label: Text(c.displayName),
                          selectedColor: Colors.teal.shade100,
                          checkmarkColor: Colors.teal.shade800,
                          onSelected: (_) =>
                              _toggleCommunityMember(c.email.toLowerCase()),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (err, stack) => const SizedBox.shrink(),
            ),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Add Member by Email',
                      hintText: 'friend@example.com',
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _addEmail,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (_memberEmails.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: _memberEmails
                    .map((email) => Chip(
                          label: Text(email, style: const TextStyle(fontSize: 12)),
                          onDeleted: () =>
                              setState(() => _memberEmails.remove(email)),
                          deleteIconColor: Colors.redAccent,
                        ))
                    .toList(),
              ),
            ],
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
              onPressed: _isLoading ? null : _handleCreateGroup,
              child: _isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Create Group',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}