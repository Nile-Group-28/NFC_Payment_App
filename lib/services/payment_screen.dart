// lib/services/payment_screen.dart
import 'package:flutter/material.dart';
import 'payment_token.dart'; // NfcPaymentToken model
import 'nfc_service.dart'; // NfcService class
import 'qr_service.dart'; // QrDisplayWidget, QrScannerScreen
import 'api_service.dart'; // WalletApi, Session, ApiException

// ─── Private button — no dependency on main.dart ──────────────────────────────
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
  final TextEditingController _amtCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkNfc();
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    NfcService.stopSession();
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

  // ── NFC send ──────────────────────────────────────────────────────────────
  void _startNfc() {
    final amt = _amount;
    if (amt == null) return;
    final uid = Session.user?['id'] as String? ?? 'unknown';

    NfcService.startSendSession(
      senderId: uid,
      amount: amt,
      onWaitingForTap: () {
        if (mounted)
          setState(() {
            _mode = 'NFC_WAITING';
            _statusMessage = 'Hold near receiver\'s phone';
          });
      },
      onSuccess: () {
        if (mounted) {
          setState(() {
            _settledAmount = amt;
            _mode = 'SUCCESS';
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

  // ── QR show ───────────────────────────────────────────────────────────────
  void _showQr() {
    if (_amount != null) setState(() => _mode = 'QR_DISPLAY');
  }

  void _onQrExpired() {
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
        appBar: AppBar(
            title: const Text('Make Payment',
                style: TextStyle(fontWeight: FontWeight.bold)),
            leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context))),
        body: Padding(
            padding: const EdgeInsets.all(32),
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
              const Spacer(),
              if (_nfcAvailable) ...[
                _MBtn(
                    icon: Icons.contactless,
                    label: 'NFC Tap',
                    sub: 'Touch phones together',
                    bg: const Color(0xFF0F172A),
                    fg: Colors.white,
                    enabled: _amount != null,
                    onTap: _startNfc),
                const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              TextButton.icon(
                  onPressed: _openScanner,
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('Scan QR to Receive Payment',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(height: 16),
            ])),
      );

  Widget _nfcWaiting() => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Spacer(),
          Stack(alignment: Alignment.center, children: [
            SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.blue.shade200)),
            SizedBox(
                width: 155,
                height: 155,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: Colors.blue.shade100, value: 0.7)),
            Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withOpacity(0.05),
                    shape: BoxShape.circle),
                child: const Icon(Icons.contactless,
                    size: 52, color: Color(0xFF0F172A))),
          ]),
          const SizedBox(height: 48),
          const Text('Ready to Tap',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(_statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 32),
          Text('₦${_amount?.toStringAsFixed(0) ?? '0'}',
              style:
                  const TextStyle(fontSize: 42, fontWeight: FontWeight.w900)),
          const Spacer(),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
              child: TextButton(
                  onPressed: () {
                    NfcService.stopSession();
                    setState(() => _mode = 'IDLE');
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
                onPressed: () => setState(() => _mode = 'IDLE'))),
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
          const Text('Payment Successful',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('₦${_settledAmount.toStringAsFixed(0)}',
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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(28),
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
                Icon(icon, color: fg, size: 32),
                const SizedBox(width: 20),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label,
                      style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.bold,
                          fontSize: 17)),
                  Text(sub,
                      style:
                          TextStyle(color: fg.withOpacity(0.5), fontSize: 12)),
                ]),
                const Spacer(),
                Icon(Icons.arrow_forward_ios,
                    color: fg.withOpacity(0.3), size: 16),
              ]),
            )),
      );
}
