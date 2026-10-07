import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../data/models/group_expense_model.dart';
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
  
  bool _isMultiPayer = false;
  String? _singlePayer;
  final Map<String, TextEditingController> _payerControllers = {};
  final Set<String> _selectedMembersForSplit = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final allIds = widget.group.allMemberIds;
    final currentUid = ref.read(authStateProvider).value?.uid;

    if (currentUid != null && allIds.contains(currentUid)) {
      _singlePayer = currentUid;
    } else if (allIds.isNotEmpty) {
      _singlePayer = allIds.first;
    }

    _selectedMembersForSplit.addAll(allIds);

    for (var id in allIds) {
      _payerControllers[id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    for (var c in _payerControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _getMemberName(String id, Map<String, String> namesMap) {
    if (widget.group.tempMembers.containsKey(id)) {
      return '${widget.group.tempMembers[id]} (Guest)';
    }
    return namesMap[id] ?? 'Member (${id.length > 5 ? id.substring(0, 5) : id})';
  }

  void _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an expense title')),
      );
      return;
    }

    if (_selectedMembersForSplit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one person to split with')),
      );
      return;
    }

    double totalAmount = 0.0;
    List<PayerItem> payers = [];

    if (_isMultiPayer) {
      for (var entry in _payerControllers.entries) {
        final val = double.tryParse(entry.value.text.trim()) ?? 0.0;
        if (val > 0) {
          payers.add(PayerItem(userId: entry.key, amount: val));
          totalAmount += val;
        }
      }

      if (payers.isEmpty || totalAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter paid amounts for payers')),
        );
        return;
      }
    } else {
      final parsed = double.tryParse(_amountController.text.trim());
      if (parsed == null || parsed <= 0 || _singlePayer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid amount and payer')),
        );
        return;
      }
      totalAmount = parsed;
      payers = [PayerItem(userId: _singlePayer!, amount: totalAmount)];
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(groupExpenseRepositoryProvider).addGroupExpense(
            groupId: widget.group.groupId,
            title: title,
            totalAmount: totalAmount,
            paidByUserId: payers.first.userId,
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
    final allIds = widget.group.allMemberIds;
    final myUid = ref.read(authStateProvider).value?.uid;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Group Expense',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _isMultiPayer = !_isMultiPayer);
                  },
                  icon: Icon(_isMultiPayer ? Icons.person_rounded : Icons.people_alt_rounded, size: 16),
                  label: Text(_isMultiPayer ? 'Single Payer' : 'Multiple Payers', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_isMultiPayer) ...[
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
            ],
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
            if (!_isMultiPayer) ...[
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
                    value: _singlePayer,
                    isExpanded: true,
                    items: allIds.map((mId) {
                      final name = _getMemberName(mId, namesMap);
                      final isMe = mId == myUid;
                      return DropdownMenuItem<String>(
                        value: mId,
                        child: Text(isMe ? '$name (You)' : name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _singlePayer = val);
                    },
                  ),
                ),
              ),
            ] else ...[
              const Text('Enter amount paid by each person:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
              const SizedBox(height: 8),
              ...allIds.map((mId) {
                final name = _getMemberName(mId, namesMap);
                final isMe = mId == myUid;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(isMe ? '$name (You)' : name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _payerControllers[mId],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            prefixText: 'Rs. ',
                            hintText: '0',
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Split Among (Who Shares):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedMembersForSplit.length == allIds.length) {
                        _selectedMembersForSplit.clear();
                      } else {
                        _selectedMembersForSplit.addAll(allIds);
                      }
                    });
                  },
                  child: Text(
                    _selectedMembersForSplit.length == allIds.length ? 'Deselect All' : 'Select All',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allIds.map((mId) {
                final isSelected = _selectedMembersForSplit.contains(mId);
                final name = _getMemberName(mId, namesMap);
                final isMe = mId == myUid;

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