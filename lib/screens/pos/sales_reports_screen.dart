// lib/screens/pos/sales_reports_screen.dart
import 'package:flutter/material.dart';
import '../../services/pos_service.dart';

class SalesReportsScreen extends StatefulWidget {
  const SalesReportsScreen({super.key});
  @override
  State<SalesReportsScreen> createState() => _SalesReportsScreenState();
}

class _SalesReportsScreenState extends State<SalesReportsScreen> {
  Map<String, dynamic>? _report;
  bool _loading = true;
  String _selectedDate = DateTime.now().toIso8601String().split('T')[0];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    try {
      final res = await PosApi.getDailyReport(date: _selectedDate);
      if (mounted) setState(() { _report = res; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _report == null
              ? const Center(child: Text('No data available.'))
              : RefreshIndicator(
                  onRefresh: _loadReport,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(_selectedDate,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey)),
                      const SizedBox(height: 12),
                      _buildMetricsRow(),
                      const SizedBox(height: 16),
                      _buildBreakdownCard(),
                      const SizedBox(height: 16),
                      _buildTopItemsCard(),
                      const SizedBox(height: 16),
                      _buildHourlyCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMetricsRow() {
    final total = (_report!['totalSales'] as num?)?.toDouble() ?? 0;
    final count = (_report!['transactionCount'] as num?)?.toInt() ?? 0;
    final avg   = (_report!['averageTransaction'] as num?)?.toDouble() ?? 0;
    final tips  = (_report!['totalTips'] as num?)?.toDouble() ?? 0;
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: [
        _metricCard('Total Sales', '₦${total.toStringAsFixed(2)}', Colors.green),
        _metricCard('Transactions', '$count', Colors.blue),
        _metricCard('Avg. Sale', '₦${avg.toStringAsFixed(0)}', Colors.orange),
        _metricCard('Tips', '₦${tips.toStringAsFixed(0)}', Colors.purple),
      ],
    );
  }

  Widget _metricCard(String label, String value, Color color) => SizedBox(
        width: (MediaQuery.of(context).size.width - 48) / 2,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );

  Widget _buildBreakdownCard() {
    final bd  = _report!['breakdown'] as Map<String, dynamic>? ?? {};
    final nfc = bd['nfc'] as Map<String, dynamic>? ?? {};
    final qr  = bd['qr']  as Map<String, dynamic>? ?? {};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment Methods', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            _breakdownRow(Icons.contactless, 'NFC', nfc),
            const SizedBox(height: 8),
            _breakdownRow(Icons.qr_code, 'QR Code', qr),
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow(IconData icon, String label, Map<String, dynamic> data) => Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text('${data['count'] ?? 0} txns'),
          const SizedBox(width: 12),
          Text('₦${((data['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      );

  Widget _buildTopItemsCard() {
    final items = (_report!['topSellingItems'] as List?) ?? [];
    if (items.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top Selling Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...items.take(5).map((item) => ListTile(
                  dense: true,
                  title: Text(item['name'] ?? ''),
                  subtitle: Text('${item['total_qty']} sold'),
                  trailing: Text('₦${((item['total_revenue'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}'),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyCard() {
    final hours = (_report!['hourlyDistribution'] as List?) ?? [];
    if (hours.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hourly Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...hours.map((h) => ListTile(
                  dense: true,
                  title: Text('${h['hour']}:00 — ${(int.tryParse(h['hour'].toString()) ?? 0) + 1}:00'),
                  trailing: Text('${h['count']} txns • ₦${((h['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}'),
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_selectedDate) ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate:  DateTime.now(),
    );
    if (picked != null) {
      _selectedDate = picked.toIso8601String().split('T')[0];
      _loadReport();
    }
  }
}
