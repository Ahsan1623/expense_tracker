import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/direct_expense_model.dart';
import '../../data/repositories/direct_expense_repository.dart';
import '../../../auth/data/models/user_model.dart';

class AddDirectExpenseSheet extends ConsumerStatefulWidget {
  final String myUid;
  final String myName;
  final UserModel peerUser;

  const AddDirectExpenseSheet({
    super.key,
    required this.myUid,
    required this.myName,
    required this.peerUser,
  });

  @override
  ConsumerState<AddDirectExpenseSheet> createState() => _AddDirectExpenseSheetState();
}

class _AddDirectExpenseSheetState extends ConsumerState<AddDirectExpenseSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  DirectSplitType _splitType = DirectSplitType.equal50_50;
  bool _isLoading = false;

  Future<void> _handleSubmit() async {
    final title = _titleController.text.trim();
    final amountText = _amountController.text.trim();

    if (title.isEmpty || amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(directExpenseRepositoryProvider).addDirectExpense(
            payerId: widget.myUid,
            borrowerId: widget.peerUser.uid,
            title: title,
            totalAmount: amount,
            splitType: _splitType,
            payerName: widget.myName,
            borrowerName: widget.peerUser.displayName,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('1-to-1 expense added successfully!'),
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
            Text(
              'Add Expense with ${widget.peerUser.displayName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Expense Description',
                hintText: 'e.g. Chai & Paratha, Uber ride, Petrol',
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
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Total Amount (Rs.)',
                hintText: '500',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Split Mode:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Split 50/50'),
                    selected: _splitType == DirectSplitType.equal50_50,
                    selectedColor: Colors.teal.shade100,
                    onSelected: (val) {
                      if (val) setState(() => _splitType = DirectSplitType.equal50_50);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Friend Owes 100%'),
                    selected: _splitType == DirectSplitType.fullAmount,
                    selectedColor: Colors.teal.shade100,
                    onSelected: (val) {
                      if (val) setState(() => _splitType = DirectSplitType.fullAmount);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _splitType == DirectSplitType.equal50_50
                  ? 'Paid by you, both will share equally (50% each).'
                  : 'You paid on behalf of ${widget.peerUser.displayName}. They owe full 100%.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : _handleSubmit,
              child: _isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Expense', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}