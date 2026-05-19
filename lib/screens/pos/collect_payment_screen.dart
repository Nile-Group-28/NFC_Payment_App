// lib/screens/pos/collect_payment_screen.dart
import 'package:flutter/material.dart';
import '../../services/pos_service.dart';
import '../../services/api_service.dart';

class CollectPaymentScreen extends StatefulWidget {
  const CollectPaymentScreen({super.key});
  @override
  State<CollectPaymentScreen> createState() => _CollectPaymentScreenState();
}

class _CollectPaymentScreenState extends State<CollectPaymentScreen> {
  final _subtotalCtrl    = TextEditingController();
  final _customerIdCtrl  = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _discountCtrl    = TextEditingController(text: '0');

  double _taxRate   = 0;
  double _tipAmount = 0;
  String _paymentMethod = 'NFC';
  bool _sendReceipt  = false;
  String _receiptDelivery = 'SMS';
  bool _loading = false;

  Map<String, dynamic>? _merchantProfile;
  List<int> _tipPresets = [5, 10, 15, 20];

  @override
  void initState() {
    super.initState();
    _loadMerchantProfile();
  }

  Future<void> _loadMerchantProfile() async {
    try {
      final res = await PosApi.activate();
      if (mounted) {
        setState(() {
          _merchantProfile = res['profile'] as Map<String, dynamic>?;
          _taxRate = (_merchantProfile?['tax_rate'] as num?)?.toDouble() ?? 0;
          final presets = _merchantProfile?['tip_preset_percentages'];
          if (presets is List) _tipPresets = presets.cast<int>();
        });
      }
    } catch (_) {}
  }

  double get _subtotal   => double.tryParse(_subtotalCtrl.text)  ?? 0;
  double get _discount   => double.tryParse(_discountCtrl.text)  ?? 0;
  double get _taxAmount  => _subtotal * _taxRate / 100;
  double get _total      => _subtotal + _taxAmount + _tipAmount - _discount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collect Payment'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('Amount'),
            TextField(
              controller: _subtotalCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Subtotal',
                prefixText: '₦',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _discountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Discount',
                prefixText: '₦',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_merchantProfile?['tip_enabled'] == true) ..[
              const SizedBox(height: 12),
              _section('Tip'),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('No Tip'),
                    selected: _tipAmount == 0,
                    onSelected: (_) => setState(() => _tipAmount = 0),
                  ),
                  ..._tipPresets.map((pct) {
                    final tip = _subtotal * pct / 100;
                    return ChoiceChip(
                      label: Text('$pct% (₦${tip.toStringAsFixed(0)})'),
                      selected: _tipAmount == tip,
                      onSelected: (_) => setState(() => _tipAmount = tip),
                    );
                  }),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _section('Customer (optional)'),
            TextField(
              controller: _customerIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Customer TapPay ID / Phone / Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _customerNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Customer Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _customerPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Customer Phone',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _section('Payment Method'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'NFC', label: Text('NFC'), icon: Icon(Icons.contactless)),
                ButtonSegment(value: 'QR',  label: Text('QR Code'), icon: Icon(Icons.qr_code)),
              ],
              selected: {_paymentMethod},
              onSelectionChanged: (s) => setState(() => _paymentMethod = s.first),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Send Receipt'),
              value: _sendReceipt,
              onChanged: (v) => setState(() => _sendReceipt = v),
              dense: true,
            ),
            if (_sendReceipt)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'SMS',   label: Text('SMS')),
                  ButtonSegment(value: 'EMAIL', label: Text('Email')),
                ],
                selected: {_receiptDelivery},
                onSelectionChanged: (s) => setState(() => _receiptDelivery = s.first),
              ),
            const SizedBox(height: 16),
            _buildAmountBreakdown(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading || _total <= 0 ? null : _processPayment,
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                child: _loading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Collect ₦${_total.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
      );

  Widget _buildAmountBreakdown() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _row('Subtotal',  '₦${_subtotal.toStringAsFixed(2)}'),
              if (_taxAmount > 0) _row('Tax (${_taxRate.toStringAsFixed(0)}%)', '₦${_taxAmount.toStringAsFixed(2)}'),
              if (_tipAmount > 0) _row('Tip', '₦${_tipAmount.toStringAsFixed(2)}'),
              if (_discount  > 0) _row('Discount', '-₦${_discount.toStringAsFixed(2)}'),
              const Divider(),
              _row('Total', '₦${_total.toStringAsFixed(2)}', bold: true),
            ],
          ),
        ),
      );

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null),
            Text(value, style: bold ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16) : null),
          ],
        ),
      );

  Future<void> _processPayment() async {
    final customerId = _customerIdCtrl.text.trim();
    if (customerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter customer TapPay ID, phone, or email.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // Resolve customer ID if identifier given
      final result = await PosApi.processTransaction(
        customerId:      customerId,
        subtotal:        _subtotal,
        taxAmount:       _taxAmount,
        tipAmount:       _tipAmount,
        discountAmount:  _discount,
        paymentMethod:   _paymentMethod,
        customerName:    _customerNameCtrl.text.trim().isEmpty ? null : _customerNameCtrl.text.trim(),
        customerPhone:   _customerPhoneCtrl.text.trim().isEmpty ? null : _customerPhoneCtrl.text.trim(),
        sendReceipt:     _sendReceipt,
        receiptDelivery: _sendReceipt ? _receiptDelivery : null,
        terminalId:      await getDeviceId(),
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Payment Successful'),
              ],
            ),
            content: Text('Collected ₦${_total.toStringAsFixed(2)}\n'
                'Transaction ID: ${(result['transactionId'] as String).substring(0, 8).toUpperCase()}'),
            actions: [
              TextButton(
                onPressed: () { Navigator.pop(context); Navigator.pop(context); },
                child: const Text('Done'),
              ),
            ],
          ),
        );
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
