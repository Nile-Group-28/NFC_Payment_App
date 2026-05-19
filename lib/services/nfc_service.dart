// lib/services/nfc_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'payment_token.dart';

export 'payment_token.dart'; // re-export so old code still works

// AID: F0 (proprietary prefix) + "TAPPAY" in ASCII = F0 54 41 50 50 41 59
const _aid = [0xF0, 0x54, 0x41, 0x50, 0x50, 0x41, 0x59];

// SELECT AID APDU: 00 A4 04 00 <Lc> <AID> 00
final _selectAidApdu =
    Uint8List.fromList([0x00, 0xA4, 0x04, 0x00, _aid.length, ..._aid, 0x00]);

void _log(String msg) => debugPrint('[NFC] $msg');

class NfcService {
  static const int tokenTtlSeconds = 30;

  static const _methodCh = MethodChannel('com.example.tappay/hce');
  static const _eventCh = EventChannel('com.example.tappay/hce_events');

  static Future<bool> isAvailable() async {
    try {
      final available = await NfcManager.instance.isAvailable();
      _log('isAvailable → $available');
      return available;
    } catch (e) {
      _log('isAvailable threw: $e');
      return false;
    }
  }

  // ── SEND (HCE — phone-to-phone) ───────────────────────────────────────────
  static Future<void> startSendSession({
    required String senderId,
    required double amount,
    required void Function() onWaitingForTap,
    required void Function() onSuccess,
    required void Function(String msg) onError,
  }) async {
    _log('startSendSession — sender:$senderId amount:$amount');

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

    _log('Token created — id:${token.tokenId} expires:${token.expiresAt}');

    try {
      _log('Arming HCE service with token…');
      await _methodCh.invokeMethod('setToken', token.toNfcPayload());
      _log('HCE armed — waiting for receiver to tap');
      onWaitingForTap();

      late StreamSubscription<dynamic> sub;
      sub = _eventCh.receiveBroadcastStream().listen(
        (event) {
          _log('HCE event received: $event');
          if (event == 'tap_complete') {
            sub.cancel();
            // Give receiver 2 seconds to complete the HTTP settle before
            // clearing token and surfacing success to sender.
            _log('Tap complete — waiting 2s for receiver to settle');
            Future.delayed(const Duration(seconds: 2), () {
              _methodCh.invokeMethod('clearToken');
              onSuccess();
            });
          }
        },
        onError: (e) {
          _log('HCE event channel error: $e');
          sub.cancel();
          _methodCh.invokeMethod('clearToken');
          onError('NFC send failed: $e');
        },
      );
    } catch (e) {
      _log('startSendSession error: $e');
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
    _log('startReceiveSession — starting NFC session');

    if (!await isAvailable()) {
      onError('NFC not available.');
      return;
    }

    try {
      onWaitingForTap();
      NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
        _log('Tag discovered — techs: ${tag.data.keys.toList()}');

        try {
          // ── Path 1: phone-to-phone via HCE (IsoDep) ──────────────────────
          final isoDep = IsoDep.from(tag);
          if (isoDep != null) {
            _log('IsoDep tag detected — sending SELECT AID');
            _log(
                'APDU → ${_selectAidApdu.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

            final response = await isoDep.transceive(data: _selectAidApdu);
            _log(
                'APDU ← ${response.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')} (${response.length} bytes)');

            if (response.length < 3) {
              _log(
                  'Response too short (${response.length} bytes) — sender not ready?');
              onError(
                  'No response from sender. Make sure TapPay is open on their phone.');
              await NfcManager.instance
                  .stopSession(errorMessage: 'No response');
              return;
            }

            final sw1 = response[response.length - 2];
            final sw2 = response[response.length - 1];
            _log(
                'Status word: ${sw1.toRadixString(16).padLeft(2, '0')} ${sw2.toRadixString(16).padLeft(2, '0')}');

            if (sw1 == 0x6A && sw2 == 0x82) {
              _log('SW 6A82 — sender HCE has no token set');
              onError('Sender not ready. Ask them to start a payment first.');
              await NfcManager.instance
                  .stopSession(errorMessage: 'Sender not ready');
              return;
            }

            if (sw1 != 0x90 || sw2 != 0x00) {
              _log('Unexpected SW — not 9000');
              onError('Unexpected NFC response. Try again.');
              await NfcManager.instance
                  .stopSession(errorMessage: 'Bad response');
              return;
            }

            final rawText =
                utf8.decode(response.sublist(0, response.length - 2));
            _log('Token payload received (${rawText.length} chars): $rawText');

            final token = _parseToken(rawText, onError);
            if (token == null) {
              await NfcManager.instance
                  .stopSession(errorMessage: 'Invalid token');
              return;
            }

            _log(
                'Token valid — id:${token.tokenId} sender:${token.senderId} amount:${token.amount}');
            await NfcManager.instance
                .stopSession(alertMessage: 'Payment received! ✓');
            onTokenReceived(token);
            return;
          }

          // ── Path 2: physical NDEF tag (fallback) ─────────────────────────
          _log('No IsoDep — trying NDEF (physical tag path)');
          final ndef = Ndef.from(tag);
          if (ndef != null) {
            _log('NDEF tag found');
            final message = ndef.cachedMessage;
            if (message == null || message.records.isEmpty) {
              _log('NDEF tag is empty');
              onError('NFC tag is empty.');
              await NfcManager.instance.stopSession(errorMessage: 'No data');
              return;
            }
            final record = message.records.first;
            final langLen = record.payload[0] & 0x3F;
            final rawText = utf8.decode(record.payload.sublist(1 + langLen));
            _log('NDEF payload: $rawText');

            final token = _parseToken(rawText, onError);
            if (token == null) {
              await NfcManager.instance
                  .stopSession(errorMessage: 'Invalid token');
              return;
            }

            _log('NDEF token valid — id:${token.tokenId}');
            await NfcManager.instance
                .stopSession(alertMessage: 'Payment received! ✓');
            onTokenReceived(token);
            return;
          }

          _log(
              'Tag has neither IsoDep nor NDEF — unsupported: ${tag.data.keys}');
          onError('Could not read NFC device.');
          await NfcManager.instance.stopSession(errorMessage: 'Read failed');
        } catch (e) {
          _log('onDiscovered threw: $e');
          await NfcManager.instance.stopSession(errorMessage: 'Read error');
          onError('Read failed: $e');
        }
      });
    } catch (e) {
      _log('startReceiveSession threw: $e');
      onError('Could not start NFC: $e');
    }
  }

  static NfcPaymentToken? _parseToken(
      String raw, void Function(String) onError) {
    try {
      final token = NfcPaymentToken.fromNfcPayload(raw);
      if (token.isExpired) {
        _log('Token expired — id:${token.tokenId}');
        onError('Token expired. Ask sender to retry.');
        return null;
      }
      return token;
    } on FormatException catch (e) {
      _log('Token parse failed: ${e.message}');
      onError(e.message);
      return null;
    }
  }

  static void stopSession() {
    _log('stopSession called');
    try {
      NfcManager.instance.stopSession();
    } catch (_) {}
  }

  static Future<void> cancelSend() async {
    _log('cancelSend — clearing HCE token');
    try {
      await _methodCh.invokeMethod('clearToken');
    } catch (_) {}
  }
}
