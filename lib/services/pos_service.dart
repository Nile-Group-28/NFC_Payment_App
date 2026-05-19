// lib/services/pos_service.dart
import 'api_service.dart';

class PosApi {
  // ── Merchant setup ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> activate({
    String? businessName,
    String? businessCategory,
    String? businessAddress,
    String? businessPhone,
    double taxRate = 0,
    bool tipEnabled = false,
    List<int>? tipPresets,
    String? receiptFooter,
    String settlementFrequency = 'DAILY',
  }) =>
      _post('/pos/activate', {
        if (businessName != null)    'businessName':    businessName,
        if (businessCategory != null) 'businessCategory': businessCategory,
        if (businessAddress != null) 'businessAddress': businessAddress,
        if (businessPhone != null)   'businessPhone':   businessPhone,
        'taxRate':             taxRate,
        'tipEnabled':          tipEnabled,
        if (tipPresets != null) 'tipPresets': tipPresets,
        if (receiptFooter != null) 'receiptFooter': receiptFooter,
        'settlementFrequency': settlementFrequency,
      });

  // ── Payment collection ───────────────────────────────────────────
  static Future<Map<String, dynamic>> processTransaction({
    required String customerId,
    required double subtotal,
    double taxAmount = 0,
    double tipAmount = 0,
    double discountAmount = 0,
    List<Map<String, dynamic>>? items,
    String paymentMethod = 'NFC',
    String? customerName,
    String? customerPhone,
    bool sendReceipt = false,
    String? receiptDelivery,
    String? terminalId,
  }) =>
      _post('/pos/transaction', {
        'customerId':      customerId,
        'subtotal':        subtotal,
        'taxAmount':       taxAmount,
        'tipAmount':       tipAmount,
        'discountAmount':  discountAmount,
        if (items != null) 'items': items,
        'paymentMethod':   paymentMethod,
        if (customerName != null)  'customerName':  customerName,
        if (customerPhone != null) 'customerPhone': customerPhone,
        'sendReceipt':     sendReceipt,
        if (receiptDelivery != null) 'receiptDelivery': receiptDelivery,
        if (terminalId != null) 'terminalId': terminalId,
      });

  // ── Reports ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getDailyReport({String? date}) =>
      _get('/pos/daily-report${date != null ? '?date=$date' : ''}');

  static Future<Map<String, dynamic>> getSettlementReport({
    String period = 'daily',
    String? startDate,
    String? endDate,
  }) {
    final params = [
      'period=$period',
      if (startDate != null) 'startDate=$startDate',
      if (endDate != null)   'endDate=$endDate',
    ].join('&');
    return _get('/pos/settlement-report?$params');
  }

  static Future<Map<String, dynamic>> getTransactions({
    int page = 1,
    int limit = 50,
    String? startDate,
    String? endDate,
    String? status,
  }) {
    final params = [
      'page=$page', 'limit=$limit',
      if (startDate != null) 'startDate=$startDate',
      if (endDate != null)   'endDate=$endDate',
      if (status != null)    'status=$status',
    ].join('&');
    return _get('/pos/transactions?$params');
  }

  // ── Refunds ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> processRefund({
    required String transactionId,
    required double refundAmount,
    required String reason,
    String refundType = 'FULL',
  }) =>
      _post('/pos/refund', {
        'transactionId': transactionId,
        'refundAmount':  refundAmount,
        'reason':        reason,
        'refundType':    refundType,
      });

  // ── Inventory ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> addInventoryItem({
    required String sku,
    required String itemName,
    String? category,
    required double price,
    int stockQuantity = 0,
    int lowStockAlert = 5,
  }) =>
      _post('/pos/inventory/add', {
        'sku':           sku,
        'itemName':      itemName,
        if (category != null) 'category': category,
        'price':         price,
        'stockQuantity': stockQuantity,
        'lowStockAlert': lowStockAlert,
      });

  static Future<Map<String, dynamic>> getInventory({
    String? search,
    bool lowStockOnly = false,
  }) {
    final params = [
      if (search != null) 'search=${Uri.encodeComponent(search)}',
      if (lowStockOnly) 'lowStock=true',
    ].join('&');
    return _get('/pos/inventory${params.isNotEmpty ? '?$params' : ''}');
  }

  static Future<Map<String, dynamic>> updateInventoryItem(
    String sku, {
    String? itemName,
    String? category,
    double? price,
    int? stockQuantity,
    int? lowStockAlert,
    bool? isActive,
  }) =>
      _put('/pos/inventory/$sku', {
        if (itemName != null)      'itemName':      itemName,
        if (category != null)      'category':      category,
        if (price != null)         'price':         price,
        if (stockQuantity != null) 'stockQuantity': stockQuantity,
        if (lowStockAlert != null) 'lowStockAlert': lowStockAlert,
        if (isActive != null)      'isActive':      isActive,
      });

  static Future<Map<String, dynamic>> adjustStock({
    required String sku,
    required int adjustment,
    String? reason,
  }) =>
      _post('/pos/inventory/adjust-stock', {
        'sku':        sku,
        'adjustment': adjustment,
        if (reason != null) 'reason': reason,
      });

  // ── Receipt ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getReceipt(String transactionId) =>
      _get('/pos/receipt/$transactionId');
}
