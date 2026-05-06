// lib/services/payment_token.dart
// Shared model — imported by nfc_service, qr_service, and payment_screen
// Keep this file exactly as is.

import 'dart:convert';

class NfcPaymentToken {
  final String tokenId;
  final String senderId;
  final double amount;
  final String currency;
  final DateTime createdAt;
  final DateTime expiresAt;

  NfcPaymentToken({
    required this.tokenId,
    required this.senderId,
    required this.amount,
    required this.currency,
    required this.createdAt,
    required this.expiresAt,
  });

  String toNfcPayload() => jsonEncode({
        'tokenId': tokenId,
        'senderId': senderId,
        'amount': amount,
        'currency': currency,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'app': 'TAPPAY',
      });

  factory NfcPaymentToken.fromNfcPayload(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    if (map['app'] != 'TAPPAY')
      throw const FormatException('Not a TapPay token.');
    return NfcPaymentToken(
      tokenId: map['tokenId'],
      senderId: map['senderId'],
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] ?? 'NGN',
      createdAt: DateTime.parse(map['createdAt']),
      expiresAt: DateTime.parse(map['expiresAt']),
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
