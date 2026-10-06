import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../data/models/group_model.dart';
import '../../data/repositories/group_expense_repository.dart';
import '../../data/repositories/group_repository.dart';

class AddGroupExpenseSheet extends ConsumerStatefulWidget {
  final GroupModel group;
  const AddGroupExpenseSheet({super.key, required this.group});

  @override
  ConsumerState<AddGroupExpenseSheet> createState() => _AddGroupExpenseSheetState();
}

class _AddGroupExpenseSheetState extends ConsumerState<AddGroupExpenseSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedPayer;
  final Set<String> _selectedMembersForSplit = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final currentUid = ref.read(authStateProvider).value?.uid;
    if (currentUid != null && widget.group.members.contains(currentUid)) {
      _selectedPayer = currentUid;
    } else if (widget.group.members.isNotEmpty) {
      _selectedPayer = widget.group.members.first;
    }
    // By default sab members selected honge
    _selectedMembersForSplit.addAll(widget.group.members);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());

    if (title.isEmpty || amount == null || amount <= 0 || _selectedPayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid title, amount, and payer')),
      );
      return;
    }

    if (_selectedMembersForSplit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kam az kam ek member ko split me select karein')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(groupExpenseRepositoryProvider).addGroupExpense(
            groupId: widget.group.groupId,
            title: title,
            totalAmount: amount,
            paidByUserId: _selectedPayer!,
            splitAmongMemberIds: _selectedMembersForSplit.toList(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberProfilesAsync = ref.watch(groupMembersProfilesProvider(widget.group.members));
    final namesMap = memberProfilesAsync.value ?? {};

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add Group Expense',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.teal),
              decoration: InputDecoration(
                prefixText: 'Rs. ',
                prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal),
                hintText: '0.00',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Expense Description',
                hintText: 'e.g. Dinner, Fuel, Grocery',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Paid By:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPayer,
                  isExpanded: true,
                  items: widget.group.members.map((memberId) {
                    final name = namesMap[memberId] ?? 'Member (${memberId.substring(0, memberId.length > 5 ? 5 : memberId.length)})';
                    final isMe = memberId == ref.read(authStateProvider).value?.uid;
                    return DropdownMenuItem<String>(
                      value: memberId,
                      child: Text(isMe ? '$name (You)' : name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedPayer = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Member Selection for Split
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Split Among (Select Who Shares):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedMembersForSplit.length == widget.group.members.length) {
                        _selectedMembersForSplit.clear();
                      } else {
                        _selectedMembersForSplit.addAll(widget.group.members);
                      }
                    });
                  },
                  child: Text(
                    _selectedMembersForSplit.length == widget.group.members.length ? 'Deselect All' : 'Select All',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.group.members.map((mId) {
                final isSelected = _selectedMembersForSplit.contains(mId);
                final name = namesMap[mId] ?? 'Member';
                final isMe = mId == ref.read(authStateProvider).value?.uid;

                return FilterChip(
                  label: Text(isMe ? '$name (You)' : name),
                  selected: isSelected,
                  selectedColor: Colors.teal.shade100,
                  checkmarkColor: Colors.teal.shade800,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.teal.shade900 : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedMembersForSplit.add(mId);
                      } else {
                        _selectedMembersForSplit.remove(mId);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Split Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}