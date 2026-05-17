// lib/services/payment_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'payment_token.dart';
import 'nfc_service.dart';
import 'qr_service.dart';
import 'api_service.dart';

// ─── Private button ───────────────────────────────────────────────────────────
class _Btn extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const _Btn({required this.label, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 3))
            : Text(label,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ─── Payment Screen ───────────────────────────────────────────────────────────
class TapPayPaymentScreen extends StatefulWidget {
  final void Function(String, double)? onPaymentSuccess;
  const TapPayPaymentScreen({super.key, this.onPaymentSuccess});
  @override
  State<TapPayPaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<TapPayPaymentScreen> {
  String _mode = 'IDLE';
  bool _nfcAvailable = false;
  bool _settling = false;
  String _statusMessage = 'Hold phones together';
  String _errorMessage = '';
  double _settledAmount = 0;
  bool _isSend = true;
  Timer? _qrPollTimer;
  int _prevTxCount = 0;
  double? _qrAmount;
  final TextEditingController _amtCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkNfc().then((_) {
      if (_nfcAvailable && mounted) _autoReceive();
    });
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _qrPollTimer?.cancel();
    NfcService.stopSession();
    NfcService.cancelSend();
    super.dispose();
  }

  Future<void> _checkNfc() async {
    final ok = await NfcService.isAvailable();
    if (mounted) setState(() => _nfcAvailable = ok);
  }

  double? get _amount {
    final v = double.tryParse(_amtCtrl.text);
    return (v != null && v > 0) ? v : null;
  }

  // ── Auto-receive in background when screen opens ──────────────────────────
  void _autoReceive() {
    NfcService.startReceiveSession(
      onWaitingForTap: () {},
      onTokenReceived: (NfcPaymentToken token) async {
        if (!mounted || _mode != 'IDLE') return;
        _handleTokenReceived(token);
      },
      onError: (_) {
        // Silent — user might be sending, not receiving
      },
    );
  }

  Future<void> _handleTokenReceived(NfcPaymentToken token) async {
    if (!mounted) return;
    setState(() { _settling = true; _isSend = false; });
    try {
      await WalletApi.nfcSettle(
        senderId: token.senderId,
        amount: token.amount,
        tokenId: token.tokenId,
      );
      if (mounted) {
        setState(() {
          _settling = false;
          _settledAmount = token.amount;
          _mode = 'SUCCESS';
          _isSend = false;
        });
        widget.onPaymentSuccess?.call('NFC Payment Received', token.amount);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } on ApiException catch (e) {
      if (mounted)
        setState(() {
          _settling = false;
          _mode = 'ERROR';
          _errorMessage = e.message;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _settling = false;
          _mode = 'ERROR';
          _errorMessage = 'Settlement failed: $e';
        });
    }
  }

  // ── NFC send ──────────────────────────────────────────────────────────────
  void _startNfc() {
    final amt = _amount;
    if (amt == null) return;
    final uid = Session.user?['id'] as String? ?? 'unknown';

    // Cancel background auto-receive before arming HCE
    NfcService.stopSession();

    NfcService.startSendSession(
      senderId: uid,
      amount: amt,
      onWaitingForTap: () {
        if (mounted)
          setState(() {
            _mode = 'NFC_WAITING';
            _statusMessage = 'Hold near receiver\'s phone';
            _isSend = true;
          });
      },
      onSuccess: () {
        if (mounted) {
          setState(() {
            _settledAmount = amt;
            _mode = 'SUCCESS';
            _isSend = true;
          });
          widget.onPaymentSuccess?.call('NFC Payment Sent', amt);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.pop(context);
          });
        }
      },
      onError: (msg) {
        if (mounted)
          setState(() {
            _mode = 'ERROR';
            _errorMessage = msg;
          });
      },
    );
  }

  // ── NFC receive (explicit button) ─────────────────────────────────────────
  void _startNfcReceive() {
    NfcService.stopSession();
    setState(() {
      _mode = 'NFC_RECEIVING';
      _statusMessage = 'Hold near sender\'s phone';
      _isSend = false;
    });

    NfcService.startReceiveSession(
      onWaitingForTap: () {
        if (mounted)
          setState(() => _statusMessage = 'Hold near sender\'s phone');
      },
      onTokenReceived: (NfcPaymentToken token) async {
        await _handleTokenReceived(token);
      },
      onError: (msg) {
        if (mounted)
          setState(() {
            _mode = 'ERROR';
            _errorMessage = msg;
          });
      },
    );
  }

  // ── QR show (with polling for sender feedback) ────────────────────────────
  void _showQr() {
    if (_amount == null) return;
    _qrAmount = _amount;
    _prevTxCount = 0; // reset
    setState(() => _mode = 'QR_DISPLAY');
    _startQrPoll();
  }

  void _startQrPoll() {
    _qrPollTimer?.cancel();
    _qrPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_mode != 'QR_DISPLAY' || !mounted) {
        _qrPollTimer?.cancel();
        return;
      }
      try {
        final data = await WalletApi.getTransactions(limit: 5);
        final txs = (data['transactions'] as List? ?? []);
        // Look for a new debit transaction matching the amount
        for (final tx in txs) {
          if (tx['isCredit'] == false &&
              (tx['amount'] as num).toDouble() == _qrAmount &&
              (tx['type'] as String).toUpperCase() == 'NFC') {
            _qrPollTimer?.cancel();
            if (mounted) {
              setState(() {
                _settledAmount = _qrAmount!;
                _mode = 'SUCCESS';
                _isSend = true;
              });
              widget.onPaymentSuccess?.call('QR Payment Sent', _qrAmount!);
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) Navigator.pop(context);
              });
            }
            return;
          }
        }
      } catch (_) {}
    });
  }

  void _onQrExpired() {
    _qrPollTimer?.cancel();
    if (mounted)
      setState(() {
        _mode = 'ERROR';
        _errorMessage = 'QR expired. Go back and try again.';
      });
  }

  // ── QR scan (receiver) ────────────────────────────────────────────────────
  void _openScanner() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => QrScannerScreen(
                  onTokenScanned: (NfcPaymentToken token) async {
                    setState(() => _settling = true);
                    try {
                      await WalletApi.nfcSettle(
                          senderId: token.senderId,
                          amount: token.amount,
                          tokenId: token.tokenId);
                      if (mounted) {
                        setState(() {
                          _settling = false;
                          _settledAmount = token.amount;
                          _mode = 'SUCCESS';
                          _isSend = false;
                        });
                        widget.onPaymentSuccess
                            ?.call('QR Payment Received', token.amount);
                        Future.delayed(const Duration(seconds: 2), () {
                          if (mounted) Navigator.pop(context);
                        });
                      }
                    } on ApiException catch (e) {
                      if (mounted)
                        setState(() {
                          _settling = false;
                          _mode = 'ERROR';
                          _errorMessage = e.message;
                        });
                    }
                  },
                  onError: (msg) {
                    if (mounted)
                      setState(() {
                        _mode = 'ERROR';
                        _errorMessage = msg;
                      });
                  },
                )));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_settling)
      return const Scaffold(
          body: Center(
              child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Processing…', style: TextStyle(fontWeight: FontWeight.bold))
        ],
      )));
    switch (_mode) {
      case 'NFC_WAITING':
        return _nfcWaiting();
      case 'NFC_RECEIVING':
        return _nfcReceiving();
      case 'QR_DISPLAY':
        return _qrDisplay();
      case 'SUCCESS':
        return _success();
      case 'ERROR':
        return _error();
      default:
        return _idle();
    }
  }

  Widget _idle() => Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
            title: const Text('Make Payment',
                style: TextStyle(fontWeight: FontWeight.bold)),
            leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context))),
        body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                32,
                16,
                32,
                MediaQuery.of(context).viewInsets.bottom + 32),
            child: Column(children: [
              const Text('ENTER AMOUNT',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text('₦',
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black38)),
                    Expanded(
                        child: TextField(
                      controller: _amtCtrl,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                          fontSize: 64, fontWeight: FontWeight.w900),
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '0',
                          hintStyle: TextStyle(color: Colors.black12)),
                      onChanged: (_) => setState(() {}),
                    )),
                  ]),
              const SizedBox(height: 32),
              if (_nfcAvailable) ...[
                _MBtn(
                    icon: Icons.contactless,
                    label: 'NFC Tap — Send',
                    sub: 'Tap phones together to send money',
                    bg: const Color(0xFF0F172A),
                    fg: Colors.white,
                    enabled: _amount != null,
                    onTap: _startNfc),
                const SizedBox(height: 12),
                _MBtn(
                    icon: Icons.contactless,
                    label: 'NFC Tap — Receive',
                    sub: 'Tap phones together to receive money',
                    bg: Colors.white,
                    fg: Colors.green.shade700,
                    border: Colors.green.shade200,
                    enabled: true,
                    onTap: _startNfcReceive),
                const SizedBox(height: 12),
              ],
              _MBtn(
                  icon: Icons.qr_code,
                  label: _nfcAvailable ? 'Show QR Code' : 'Pay with QR Code',
                  sub: _nfcAvailable
                      ? 'Let receiver scan your QR'
                      : 'NFC unavailable — use QR',
                  bg: Colors.white,
                  fg: Colors.black,
                  border: Colors.grey.shade200,
                  enabled: _amount != null,
                  onTap: _showQr),
              const SizedBox(height: 12),
              TextButton.icon(
                  onPressed: _openScanner,
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('Scan QR to Receive Payment',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(height: 8),
            ])),
      );

  Widget _nfcWaiting() => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
          const Spacer(),
          Center(
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.blue.shade200)),
              SizedBox(
                  width: 155,
                  height: 155,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.blue.shade100,
                      value: 0.7)),
              Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.05),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.contactless,
                      size: 52, color: Color(0xFF0F172A))),
            ]),
          ),
          const SizedBox(height: 48),
          const Text('Ready to Send',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(_statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 32),
          Text('₦${_amount?.toStringAsFixed(2) ?? '0.00'}',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 42, fontWeight: FontWeight.w900)),
          const Spacer(),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
              child: TextButton(
                  onPressed: () {
                    NfcService.cancelSend();
                    setState(() => _mode = 'IDLE');
                    _autoReceive();
                  },
                  child: const Text('Cancel',
                      style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)))),
        ])),
      );

  Widget _nfcReceiving() => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
          const Spacer(),
          Center(
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.green.shade200)),
              SizedBox(
                  width: 155,
                  height: 155,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.green.shade100,
                      value: 0.7)),
              Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.08),
                      shape: BoxShape.circle),
                  child:
                      const Icon(Icons.contactless, size: 52, color: Colors.green)),
            ]),
          ),
          const SizedBox(height: 48),
          const Text('Ready to Receive',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(_statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 32),
          const Text('Waiting for sender…',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const Spacer(),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
              child: TextButton(
                  onPressed: () {
                    NfcService.stopSession();
                    setState(() => _mode = 'IDLE');
                    _autoReceive();
                  },
                  child: const Text('Cancel',
                      style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)))),
        ])),
      );

  Widget _qrDisplay() => Scaffold(
        appBar: AppBar(
            title: const Text('Your Payment QR',
                style: TextStyle(fontWeight: FontWeight.bold)),
            leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _qrPollTimer?.cancel();
                  setState(() => _mode = 'IDLE');
                })),
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: QrDisplayWidget(
                    senderId: Session.user?['id'] as String? ?? 'unknown',
                    amount: _amount ?? 0,
                    onExpired: _onQrExpired))),
      );

  Widget _success() => Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle),
                  child:
                      const Icon(Icons.check, color: Colors.white, size: 65))),
          const SizedBox(height: 40),
          Text(_isSend ? 'Payment Sent' : 'Payment Received',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('₦${_settledAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 36,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Returning to home…',
              style: TextStyle(color: Colors.white38, fontSize: 14)),
        ])),
      );

  Widget _error() => Scaffold(
        backgroundColor: Colors.white,
        body: Center(
            child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle),
                          child: Icon(Icons.error_outline,
                              size: 55, color: Colors.red.shade400)),
                      const SizedBox(height: 32),
                      const Text('Payment Failed',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      Text(_errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 15, height: 1.5)),
                      const SizedBox(height: 40),
                      _Btn(
                          label: 'Try Again',
                          onPressed: () => setState(() {
                                _mode = 'IDLE';
                                _errorMessage = '';
                                _autoReceive();
                              })),
                      const SizedBox(height: 16),
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel',
                              style: TextStyle(color: Colors.grey))),
                    ]))),
      );
}

// ─── Method button ────────────────────────────────────────────────────────────
class _MBtn extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color bg, fg;
  final Color? border;
  final bool enabled;
  final VoidCallback onTap;
  const _MBtn(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.bg,
      required this.fg,
      required this.enabled,
      required this.onTap,
      this.border});

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: GestureDetector(
            onTap: enabled ? onTap : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(24),
                  border: border != null ? Border.all(color: border!) : null,
                  boxShadow: bg == const Color(0xFF0F172A)
                      ? [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 16,
                              offset: const Offset(0, 6))
                        ]
                      : null),
              child: Row(children: [
                Icon(icon, color: fg, size: 28),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label,
                      style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text(sub,
                      style:
                          TextStyle(color: fg.withOpacity(0.5), fontSize: 11)),
                ]),
                const Spacer(),
                Icon(Icons.arrow_forward_ios,
                    color: fg.withOpacity(0.3), size: 14),
              ]),
            )),
      );
}
