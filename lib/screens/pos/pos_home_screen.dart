// lib/screens/pos/pos_home_screen.dart
import 'package:flutter/material.dart';
import 'collect_payment_screen.dart';
import 'transaction_history_screen.dart';
import 'sales_reports_screen.dart';
import 'inventory_screen.dart';
import 'pos_settings_screen.dart';
import '../../services/pos_service.dart';

class POSHomeScreen extends StatefulWidget {
  const POSHomeScreen({super.key});
  @override
  State<POSHomeScreen> createState() => _POSHomeScreenState();
}

class _POSHomeScreenState extends State<POSHomeScreen> {
  Map<String, dynamic>? _dailyReport;
  List<dynamic> _recentTx = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final [report, txData] = await Future.wait([
        PosApi.getDailyReport(),
        PosApi.getTransactions(limit: 5),
      ]);
      if (mounted) {
        setState(() {
          _dailyReport = report;
          _recentTx    = (txData['transactions'] as List?) ?? [];
          _loading     = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SoftPOS Terminal'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const POSSettingsScreen()),
            ).then((_) => _loadData()),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSalesSummaryCard(),
                  const SizedBox(height: 16),
                  _buildActionGrid(context),
                  const SizedBox(height: 16),
                  _buildRecentTransactions(),
                ],
              ),
            ),
    );
  }

  Widget _buildSalesSummaryCard() {
    final total = (_dailyReport?['totalSales'] as num?)?.toDouble() ?? 0;
    final count = (_dailyReport?['transactionCount'] as num?)?.toInt() ?? 0;
    final tips  = (_dailyReport?['totalTips'] as num?)?.toDouble() ?? 0;
    return Card(
      color: Colors.deepPurple,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Today\'s Sales',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            Text('₦${total.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _statChip('$count transactions'),
                const SizedBox(width: 8),
                _statChip('Tips: ₦${tips.toStringAsFixed(0)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      );

  Widget _buildActionGrid(BuildContext context) {
    final actions = [
      _Action(Icons.payment,      'Collect Payment',    Colors.green,      () => _nav(context, const CollectPaymentScreen())),
      _Action(Icons.receipt_long, 'Transactions',       Colors.blue,       () => _nav(context, const TransactionHistoryScreen())),
      _Action(Icons.analytics,    'Sales Reports',      Colors.orange,     () => _nav(context, const SalesReportsScreen())),
      _Action(Icons.inventory_2,  'Inventory',          Colors.teal,       () => _nav(context, const InventoryScreen())),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: actions.map(_buildActionCard).toList(),
    );
  }

  Widget _buildActionCard(_Action a) => InkWell(
        onTap: a.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Card(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(a.icon, color: a.color, size: 32),
              const SizedBox(height: 8),
              Text(a.label, textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      );

  Widget _buildRecentTransactions() {
    if (_recentTx.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Transactions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._recentTx.map((tx) {
          final amount = (tx['total_amount'] ?? tx['amount'] as num).toDouble();
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.shade100,
              child: Icon(tx['type'] == 'QR' ? Icons.qr_code : Icons.contactless,
                  color: Colors.green),
            ),
            title: Text('₦${amount.toStringAsFixed(2)}'),
            subtitle: Text(tx['customer_name'] ?? 'Customer'),
            dense: true,
          );
        }),
      ],
    );
  }

  void _nav(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
          .then((_) => _loadData());
}

class _Action {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Action(this.icon, this.label, this.color, this.onTap);
}
