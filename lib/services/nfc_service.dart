// lib/services/nfc_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'payment_token.dart';

export 'payment_token.dart'; // re-export so old code still works

// AID: F0 (proprietary prefix) + "TAPPAY" in ASCII = F0 54 41 50 50 41 59
const _aid = [0xF0, 0x54, 0x41, 0x50, 0x50, 0x41, 0x59];

// SELECT AID APDU: 00 A4 04 00 <Lc> <AID> 00
final _selectAidApdu = Uint8List.fromList(
    [0x00, 0xA4, 0x04, 0x00, _aid.length, ..._aid, 0x00]);

class NfcService {
  static const int tokenTtlSeconds = 30;

  static const _methodCh = MethodChannel('com.example.tappay/hce');
  static const _eventCh  = EventChannel('com.example.tappay/hce_events');

  static Future<bool> isAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  // ── SEND (HCE — phone-to-phone) ───────────────────────────────────────────
  //
  // Sets the payment token in the Android HCE service so this phone acts as
  // an NFC card. When the receiver taps, Android delivers the token via APDU.
  // onSuccess fires when the phones separate after a successful tap.
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
      await _methodCh.invokeMethod('setToken', token.toNfcPayload());
      onWaitingForTap();

      // Listen for the HCE tap-complete broadcast (fires when phones separate)
      late StreamSubscription<dynamic> sub;
      sub = _eventCh.receiveBroadcastStream().listen(
        (event) {
          if (event == 'tap_complete') {
            sub.cancel();
            _methodCh.invokeMethod('clearToken');
            onSuccess();
          }
        },
        onError: (e) {
          sub.cancel();
          _methodCh.invokeMethod('clearToken');
          onError('NFC send failed: $e');
        },
      );
    } catch (e) {
      _methodCh.invokeMethod('clearToken');
      onError('Could not set up NFC send: $e');
    }
  }

  // ── RECEIVE (IsoDep for phone-to-phone, NDEF fallback for physical tags) ──
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
          // ── Path 1: phone-to-phone via HCE (IsoDep) ──────────────────────
          final isoDep = IsoDep.from(tag);
          if (isoDep != null) {
            final response =
                await isoDep.transceive(data: _selectAidApdu);

            // Response must be at least 2 bytes (SW1 SW2)
            if (response.length < 3) {
              onError('No response from sender. Make sure TapPay is open on their phone.');
              await NfcManager.instance
                  .stopSession(errorMessage: 'No response');
              return;
            }

            final sw1 = response[response.length - 2];
            final sw2 = response[response.length - 1];

            if (sw1 == 0x6A && sw2 == 0x82) {
              onError('Sender not ready. Ask them to start a payment first.');
              await NfcManager.instance
                  .stopSession(errorMessage: 'Sender not ready');
              return;
            }

            if (sw1 != 0x90 || sw2 != 0x00) {
              onError('Unexpected NFC response. Try again.');
              await NfcManager.instance
                  .stopSession(errorMessage: 'Bad response');
              return;
            }

            final rawText =
                utf8.decode(response.sublist(0, response.length - 2));
            final token = _parseToken(rawText, onError);
            if (token == null) {
              await NfcManager.instance
                  .stopSession(errorMessage: 'Invalid token');
              return;
            }

            await NfcManager.instance
                .stopSession(alertMessage: 'Payment received! ✓');
            onTokenReceived(token);
            return;
          }

          // ── Path 2: physical NDEF tag (fallback) ─────────────────────────
          final ndef = Ndef.from(tag);
          if (ndef != null) {
            final message = ndef.cachedMessage;
            if (message == null || message.records.isEmpty) {
              onError('NFC tag is empty.');
              await NfcManager.instance
                  .stopSession(errorMessage: 'No data');
              return;
            }
            final record  = message.records.first;
            final langLen = record.payload[0] & 0x3F;
            final rawText =
                utf8.decode(record.payload.sublist(1 + langLen));

            final token = _parseToken(rawText, onError);
            if (token == null) {
              await NfcManager.instance
                  .stopSession(errorMessage: 'Invalid token');
              return;
            }

            await NfcManager.instance
                .stopSession(alertMessage: 'Payment received! ✓');
            onTokenReceived(token);
            return;
          }

          onError('Could not read NFC device.');
          await NfcManager.instance
              .stopSession(errorMessage: 'Read failed');
        } catch (e) {
          await NfcManager.instance
              .stopSession(errorMessage: 'Read error');
          onError('Read failed: $e');
        }
      });
    } catch (e) {
      onError('Could not start NFC: $e');
    }
  }

  static NfcPaymentToken? _parseToken(
      String raw, void Function(String) onError) {
    try {
      final token = NfcPaymentToken.fromNfcPayload(raw);
      if (token.isExpired) {
        onError('Token expired. Ask sender to retry.');
        return null;
      }
      return token;
    } on FormatException catch (e) {
      onError(e.message);
      return null;
    }
  }

  static void stopSession() {
    try {
      NfcManager.instance.stopSession();
    } catch (_) {}
  }

  // Call this if the user cancels the send screen before a tap occurs
  static Future<void> cancelSend() async {
    try {
      await _methodCh.invokeMethod('clearToken');
    } catch (_) {}
  }
}
