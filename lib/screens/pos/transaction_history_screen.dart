// lib/screens/pos/transaction_history_screen.dart
import 'package:flutter/material.dart';
import '../../services/pos_service.dart';
import 'refund_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});
  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  List<dynamic> _transactions = [];
  bool _loading = true;
  int _page = 1;
  bool _hasMore = true;
  String? _filterStatus;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions({bool reset = false}) async {
    if (reset) { _page = 1; _transactions = []; }
    setState(() => _loading = true);
    try {
      final res = await PosApi.getTransactions(
        page:      _page,
        limit:     30,
        startDate: _dateRange?.start.toIso8601String().split('T')[0],
        endDate:   _dateRange?.end.toIso8601String().split('T')[0],
        status:    _filterStatus,
      );
      final txList = (res['transactions'] as List?) ?? [];
      final total  = (res['pagination']?['total'] as num?)?.toInt() ?? 0;
      setState(() {
        _transactions = [..._transactions, ...txList];
        _hasMore      = _transactions.length < total;
        _loading      = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _transactions.isEmpty && _loading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? const Center(child: Text('No transactions found.'))
              : ListView.separated(
                  itemCount: _transactions.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    if (i == _transactions.length) {
                      _page++;
                      _loadTransactions();
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _buildTxTile(_transactions[i] as Map<String, dynamic>);
                  },
                ),
    );
  }

  Widget _buildTxTile(Map<String, dynamic> tx) {
    final amount     = (tx['total_amount'] ?? tx['amount'] as num).toDouble();
    final isRefunded = tx['is_refunded'] == true;
    final type       = tx['type'] as String? ?? 'NFC';
    final name       = tx['pos_customer_name'] ?? tx['customer_name'] ?? 'Customer';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isRefunded ? Colors.red.shade100 : Colors.green.shade100,
        child: Icon(
          type == 'QR' ? Icons.qr_code : Icons.contactless,
          color: isRefunded ? Colors.red : Colors.green,
        ),
      ),
      title: Text('₦${amount.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('$name • ${_formatDate(tx['created_at'])}'),
      trailing: PopupMenuButton<String>(
        onSelected: (v) => _handleAction(v, tx),
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'receipt', child: Text('View Receipt')),
          PopupMenuItem(
            value: 'refund',
            enabled: !isRefunded,
            child: Text('Refund', style: TextStyle(color: isRefunded ? Colors.grey : Colors.red)),
          ),
        ],
      ),
      onTap: () => _showDetails(tx),
    );
  }

  void _handleAction(String action, Map<String, dynamic> tx) {
    if (action == 'receipt') {
      _showReceiptDialog(tx['id'] as String);
    } else if (action == 'refund') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RefundScreen(transaction: tx)),
      ).then((_) => _loadTransactions(reset: true));
    }
  }

  void _showReceiptDialog(String txId) {
    PosApi.getReceipt(txId).then((res) {
      final r = res['receipt'] as Map<String, dynamic>;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Receipt #${r['reference']}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['businessName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (r['businessAddress'] != null) Text(r['businessAddress']),
                const Divider(),
                Text('Total: ₦${(r['totalAmount'] as num).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Date: ${_formatDate(r['date'])}'),
                Text('Method: ${r['paymentMethod']}'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    });
  }

  void _showDetails(Map<String, dynamic> tx) {
    final items = tx['items'] as List?;
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Transaction Details',
                style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Text('Amount: ₦${(tx['total_amount'] ?? tx['amount']).toString()}'),
            Text('Type: ${tx['type']}'),
            Text('Status: ${tx['status']}'),
            if (tx['tip_amount'] != null && (tx['tip_amount'] as num) > 0)
              Text('Tip: ₦${tx['tip_amount']}'),
            if (items != null && items.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...items.map((item) =>
                Text('• ${item['name']} x${item['qty']} @ ₦${item['price']}')),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showFilterDialog() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate:  DateTime.now(),
    );
    if (range != null) {
      setState(() => _dateRange = range);
      _loadTransactions(reset: true);
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return raw.toString(); }
  }
}
