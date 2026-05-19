// lib/screens/pos/refund_screen.dart
import 'package:flutter/material.dart';
import '../../services/pos_service.dart';
import '../../services/api_service.dart';

class RefundScreen extends StatefulWidget {
  final Map<String, dynamic> transaction;
  const RefundScreen({super.key, required this.transaction});
  @override
  State<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends State<RefundScreen> {
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _loading = false;

  double get _maxRefund =>
      (widget.transaction['total_amount'] ?? widget.transaction['amount'] as num).toDouble();

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = _maxRefund.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Process Refund'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Original Transaction',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Amount: ₦$_maxRefund',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    Text('ID: ${(widget.transaction['id'] as String).substring(0, 8).toUpperCase()}'),
                    Text('Method: ${widget.transaction['type']}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Refund Amount',
                prefixText: '₦',
                helperText: 'Max: ₦$_maxRefund',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason for Refund',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _processRefund,
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: _loading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Process Refund', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processRefund() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0 || amount > _maxRefund) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter a valid amount (max ₦$_maxRefund).')),
      );
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provide a reason for the refund.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Refund'),
        content: Text('Refund ₦${amount.toStringAsFixed(2)} to customer?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Refund'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await PosApi.processRefund(
        transactionId: widget.transaction['id'] as String,
        refundAmount:  amount,
        reason:        _reasonCtrl.text.trim(),
        refundType:    amount == _maxRefund ? 'FULL' : 'PARTIAL',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Refund of ₦${amount.toStringAsFixed(2)} processed.')),
        );
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
