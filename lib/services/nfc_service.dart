// lib/services/nfc_service.dart
import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';
import 'payment_token.dart';

export 'payment_token.dart'; // re-export so old code still works

class NfcService {
  static const int tokenTtlSeconds = 30;

  static Future<bool> isAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  static Future<void> startSendSession({
    required String senderId,
    required double amount,
    required void Function() onWaitingForTap,
    required void Function() onSuccess,
    required void Function(String msg) onError,
  }) async {
    if (!await isAvailable()) {
      onError('NFC not available.');
      return;
    }

    final token = NfcPaymentToken(
      tokenId: 'txn_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      amount: amount,
      currency: 'NGN',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(seconds: tokenTtlSeconds)),
    );

    try {
      onWaitingForTap();
      NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            onError('Not NDEF compatible.');
            await NfcManager.instance
                .stopSession(errorMessage: 'Not compatible');
            return;
          }
          if (!ndef.isWritable) {
            onError('NFC tag is read-only.');
            await NfcManager.instance.stopSession(errorMessage: 'Read only');
            return;
          }
          await ndef.write(
              NdefMessage([NdefRecord.createText(token.toNfcPayload())]));
          await NfcManager.instance
              .stopSession(alertMessage: 'Payment sent! ✓');
          onSuccess();
        } catch (e) {
          await NfcManager.instance.stopSession(errorMessage: 'Send failed');
          onError('NFC write failed: $e');
        }
      });
    } catch (e) {
      onError('Could not start NFC: $e');
    }
  }

  static Future<void> startReceiveSession({
    required void Function() onWaitingForTap,
    required void Function(NfcPaymentToken token) onTokenReceived,
    required void Function(String msg) onError,
  }) async {
    if (!await isAvailable()) {
      onError('NFC not available.');
      return;
    }

    try {
      onWaitingForTap();
      NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            onError('Could not read NFC.');
            await NfcManager.instance.stopSession(errorMessage: 'Read failed');
            return;
          }
          final message = ndef.cachedMessage;
          if (message == null || message.records.isEmpty) {
            onError('NFC tag empty.');
            await NfcManager.instance.stopSession(errorMessage: 'No data');
            return;
          }

          final record = message.records.first;
          final langLen = record.payload[0] & 0x3F;
          final rawText = utf8.decode(record.payload.sublist(1 + langLen));

          NfcPaymentToken token;
          try {
            token = NfcPaymentToken.fromNfcPayload(rawText);
          } on FormatException catch (e) {
            onError(e.message);
            await NfcManager.instance
                .stopSession(errorMessage: 'Invalid token');
            return;
          }

          if (token.isExpired) {
            onError('Token expired. Tap again.');
            await NfcManager.instance.stopSession(errorMessage: 'Expired');
            return;
          }

          await NfcManager.instance
              .stopSession(alertMessage: 'Payment received! ✓');
          onTokenReceived(token);
        } catch (e) {
          await NfcManager.instance.stopSession(errorMessage: 'Read error');
          onError('Read failed: $e');
        }
      });
    } catch (e) {
      onError('Could not start NFC: $e');
    }
  }

  static void stopSession() {
    try {
      NfcManager.instance.stopSession();
    } catch (_) {}
  }
}
