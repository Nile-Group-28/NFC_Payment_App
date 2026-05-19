// lib/screens/pos/inventory_screen.dart
import 'package:flutter/material.dart';
import '../../services/pos_service.dart';
import '../../services/api_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  bool _showLowStockOnly = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() => _loading = true);
    try {
      final res = await PosApi.getInventory(
        search:       _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        lowStockOnly: _showLowStockOnly,
      );
      if (mounted) setState(() { _items = (res['items'] as List?) ?? []; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lowStockCount = _items.where((i) =>
        (i['stock_quantity'] as num) <= (i['low_stock_alert'] as num)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search items...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => _loadInventory(),
            ),
          ),
          SwitchListTile(
            title: const Text('Low stock only'),
            value: _showLowStockOnly,
            onChanged: (v) { setState(() => _showLowStockOnly = v); _loadInventory(); },
            dense: true,
          ),
          if (lowStockCount > 0)
            Container(
              color: Colors.orange,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('$lowStockCount items running low',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('No items. Tap + to add.'))
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) => _buildItemTile(_items[i] as Map<String, dynamic>),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    final stock     = (item['stock_quantity'] as num).toInt();
    final threshold = (item['low_stock_alert'] as num).toInt();
    final isLow     = stock <= threshold;
    return ListTile(
      leading: CircleAvatar(child: Text((item['item_name'] as String)[0].toUpperCase())),
      title: Text(item['item_name'] as String),
      subtitle: Text('SKU: ${item['sku']} • Stock: $stock'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('₦${(item['price'] as num).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (isLow)
            const Text('Low', style: TextStyle(color: Colors.orange, fontSize: 11)),
        ],
      ),
      onTap: () => _showEditDialog(item),
    );
  }

  void _showAddDialog() => _showItemDialog();
  void _showEditDialog(Map<String, dynamic> item) => _showItemDialog(item: item);

  void _showItemDialog({Map<String, dynamic>? item}) {
    final skuCtrl    = TextEditingController(text: item?['sku']  as String? ?? '');
    final nameCtrl   = TextEditingController(text: item?['item_name'] as String? ?? '');
    final priceCtrl  = TextEditingController(text: item == null ? '' : (item['price'] as num).toString());
    final stockCtrl  = TextEditingController(text: item == null ? '0' : (item['stock_quantity'] as num).toString());
    final alertCtrl  = TextEditingController(text: item == null ? '5' : (item['low_stock_alert'] as num).toString());
    final categoryCtrl = TextEditingController(text: item?['category'] as String? ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item == null ? 'Add Item' : 'Edit Item'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              if (item == null)
                TextField(controller: skuCtrl,    decoration: const InputDecoration(labelText: 'SKU')),
              TextField(controller: nameCtrl,   decoration: const InputDecoration(labelText: 'Item Name')),
              TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Category')),
              TextField(controller: priceCtrl,  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price', prefixText: '₦')),
              TextField(controller: stockCtrl,  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stock Quantity')),
              TextField(controller: alertCtrl,  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Low Stock Alert')),
            ].map((w) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: w,
            )).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            child: const Text('Save'),
            onPressed: () async {
              Navigator.pop(context);
              try {
                if (item == null) {
                  await PosApi.addInventoryItem(
                    sku:           skuCtrl.text.trim(),
                    itemName:      nameCtrl.text.trim(),
                    category:      categoryCtrl.text.trim().isEmpty ? null : categoryCtrl.text.trim(),
                    price:         double.tryParse(priceCtrl.text) ?? 0,
                    stockQuantity: int.tryParse(stockCtrl.text) ?? 0,
                    lowStockAlert: int.tryParse(alertCtrl.text) ?? 5,
                  );
                } else {
                  await PosApi.updateInventoryItem(
                    item['sku'] as String,
                    itemName:      nameCtrl.text.trim(),
                    category:      categoryCtrl.text.trim().isEmpty ? null : categoryCtrl.text.trim(),
                    price:         double.tryParse(priceCtrl.text),
                    stockQuantity: int.tryParse(stockCtrl.text),
                    lowStockAlert: int.tryParse(alertCtrl.text),
                  );
                }
                _loadInventory();
              } on ApiException catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message), backgroundColor: Colors.red),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
