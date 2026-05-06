// lib/services/qr_service.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'payment_token.dart'; // ← only this, NOT nfc_service.dart

class QrService {
  static String generatePayload({
    required String senderId,
    required double amount,
  }) {
    final token = NfcPaymentToken(
      tokenId: 'qr_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      amount: amount,
      currency: 'NGN',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(seconds: 120)),
    );
    return token.toNfcPayload();
  }

  static NfcPaymentToken? parsePayload(String raw) {
    try {
      return NfcPaymentToken.fromNfcPayload(raw);
    } catch (_) {
      return null;
    }
  }
}

// ── QR Display widget (sender shows this) ────────────────────────────────────

class QrDisplayWidget extends StatefulWidget {
  final String senderId;
  final double amount;
  final void Function() onExpired;

  const QrDisplayWidget({
    super.key,
    required this.senderId,
    required this.amount,
    required this.onExpired,
  });

  @override
  State<QrDisplayWidget> createState() => _QrDisplayWidgetState();
}

class _QrDisplayWidgetState extends State<QrDisplayWidget> {
  late String _payload;
  late DateTime _expiresAt;
  int _secondsLeft = 120;

  @override
  void initState() {
    super.initState();
    _payload = QrService.generatePayload(
      senderId: widget.senderId,
      amount: widget.amount,
    );
    _expiresAt = DateTime.now().add(const Duration(seconds: 120));
    _startCountdown();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      final left = _expiresAt.difference(DateTime.now()).inSeconds;
      if (left <= 0) {
        widget.onExpired();
        return false;
      }
      setState(() => _secondsLeft = left);
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _secondsLeft / 120;
    final isUrgent = _secondsLeft <= 30;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: QrImageView(
            data: _payload,
            version: QrVersions.auto,
            size: 220,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF0F172A),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'QR expires in',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${_secondsLeft}s',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isUrgent ? Colors.red : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isUrgent ? Colors.red : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '₦${widget.amount.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Show this to the receiver to scan',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      ],
    );
  }
}

// ── QR Scanner screen (receiver scans) ───────────────────────────────────────

class QrScannerScreen extends StatefulWidget {
  final void Function(NfcPaymentToken token) onTokenScanned;
  final void Function(String error) onError;

  const QrScannerScreen({
    super.key,
    required this.onTokenScanned,
    required this.onError,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _hasScanned = false;

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    _hasScanned = true;

    final token = QrService.parsePayload(barcode!.rawValue!);
    if (token == null) {
      widget.onError('Invalid QR — not a TapPay payment.');
      Navigator.pop(context);
      return;
    }
    if (token.isExpired) {
      widget.onError('QR expired. Ask sender to refresh.');
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context);
    widget.onTokenScanned(token);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(children: [_ScanLine(), ..._corners()]),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'Center the TapPay QR code in the frame',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Payment will be processed automatically',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _corners() {
    const s = 24.0;
    const t = 3.0;
    const c = Color(0xFF3B82F6);
    Widget corner(AlignmentGeometry a, double r) => Align(
          alignment: a,
          child: Transform.rotate(
            angle: r,
            child: Container(
              width: s,
              height: s,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: c, width: t),
                  left: BorderSide(color: c, width: t),
                ),
              ),
            ),
          ),
        );
    return [
      corner(Alignment.topLeft, 0),
      corner(Alignment.topRight, 1.5708),
      corner(Alignment.bottomRight, 3.14159),
      corner(Alignment.bottomLeft, -1.5708),
    ];
  }
}

class _ScanLine extends StatefulWidget {
  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Positioned(
        top: _anim.value * 240,
        left: 0,
        right: 0,
        child: Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.blue.withOpacity(0.8),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
