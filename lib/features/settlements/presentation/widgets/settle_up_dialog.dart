import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settlement_repository.dart';

class SettleUpDialog extends ConsumerStatefulWidget {
  final String groupId;
  final String currentUserId;
  final String targetUserId;
  final String targetUserName;
  final double defaultAmount;

  const SettleUpDialog({
    super.key,
    required this.groupId,
    required this.currentUserId,
    required this.targetUserId,
    required this.targetUserName,
    required this.defaultAmount,
  });

  @override
  ConsumerState<SettleUpDialog> createState() => _SettleUpDialogState();
}

class _SettleUpDialogState extends ConsumerState<SettleUpDialog> {
  late TextEditingController _amountController;
  final _noteController = TextEditingController(text: 'Paid via Cash / Bank');
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.defaultAmount.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(settlementRepositoryProvider).requestSettlement(
            groupId: widget.groupId,
            fromUserId: widget.currentUserId,
            toUserId: widget.targetUserId,
            amount: amount,
            note: _noteController.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settlement request sent to ${widget.targetUserName}! Awaiting confirmation.'),
            backgroundColor: Colors.teal.shade800,
          ),
        );
      }
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Settle With ${widget.targetUserName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
            decoration: InputDecoration(
              prefixText: 'Rs. ',
              prefixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
              labelText: 'Settlement Amount',
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'Payment Note',
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade600, foregroundColor: Colors.white),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Send Confirmation Request'),
        ),
      ],
    );
  }
}