import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import 'services/api_service.dart';
import 'services/payment_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark));
  runApp(const TappayApp());
}

const kDark = Color(0xFF0F172A);
const kSlate = Color(0xFF475569);
const kBg = Color(0xFFF8FAFC);
const kCard = Colors.white;
const kBorder = Color(0xFFE2E8F0);

class TappayApp extends StatelessWidget {
  const TappayApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'TapPay',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: kDark, primary: kDark),
          scaffoldBackgroundColor: kBg,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            titleTextStyle: TextStyle(
                color: kDark, fontWeight: FontWeight.w700, fontSize: 18),
            iconTheme: IconThemeData(color: kDark),
            systemOverlayStyle: SystemUiOverlayStyle.dark,
          ),
        ),
        home: const AuthWrapper(),
      );
}

// ─── Models ───────────────────────────────────────────────────────────────────
enum UserRole { consumer, merchant }

class Transaction {
  final String id, description, type;
  final double amount;
  final DateTime timestamp;
  final bool isCredit;
  final String? senderName, receiverName, status;

  Transaction(
      {required this.id,
      required this.type,
      required this.amount,
      required this.description,
      required this.timestamp,
      required this.isCredit,
      this.senderName,
      this.receiverName,
      this.status});

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
        id: j['id'] ?? '',
        type: (j['type'] as String? ?? 'PAYMENT').toUpperCase(),
        amount: (j['amount'] as num? ?? 0).toDouble(),
        description: j['description'] ?? '',
        isCredit: j['isCredit'] == true,
        timestamp: DateTime.tryParse(j['timestamp'] ?? '') ?? DateTime.now(),
        senderName: j['senderName'],
        receiverName: j['receiverName'],
        status: j['status'],
      );
}

// ─── App State ────────────────────────────────────────────────────────────────
class AppState extends ChangeNotifier {
  bool isAuthenticated = false, isLoading = false;
  UserRole activeRole = UserRole.consumer;
  String userName = '', userPhone = '', userEmail = '', userAddress = '';
  int kycTier = 0;
  String kycStatus = 'UNVERIFIED';
  double balance = 0, dailySpent = 0;
  bool hasPassword = false;
  List<Transaction> transactions = [];
  List<Map<String, dynamic>> linkedAccounts = [];
  String? _err;
  String? get errorMessage => _err;

  void _load(bool v) {
    isLoading = v;
    notifyListeners();
  }

  void _setErr(String m) {
    _err = m;
    notifyListeners();
  }

  void clearError() {
    _err = null;
    notifyListeners();
  }

  Future<bool> register(
      {required String name,
      String? email,
      String? phone,
      required String pin,
      String? password}) async {
    _load(true);
    clearError();
    try {
      final d = await AuthApi.register(
          name: name, email: email, phone: phone, pin: pin, password: password);
      _apply(d['user']);
      isAuthenticated = true;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setErr(e.message);
      return false;
    } finally {
      _load(false);
    }
  }

  Future<bool> login(
      {required String identifier, String? pin, String? password}) async {
    _load(true);
    clearError();
    try {
      final d = await AuthApi.login(
          identifier: identifier, pin: pin, password: password);
      _apply(d['user']);
      isAuthenticated = true;
      notifyListeners();
      await loadWallet();
      return true;
    } on ApiException catch (e) {
      _setErr(e.message);
      return false;
    } finally {
      _load(false);
    }
  }

  void logout() {
    AuthApi.logout();
    isAuthenticated = false;
    userName = userPhone = '';
    balance = 0;
    kycTier = 0;
    transactions = [];
    linkedAccounts = [];
    hasPassword = false;
    notifyListeners();
  }

  void _apply(Map<String, dynamic>? u) {
    if (u == null) return;
    userName = u['name'] ?? '';
    userEmail = u['email'] ?? '';
    userPhone = u['phone'] ?? '';
    kycTier = u['kycTier'] ?? 0;
    kycStatus = u['kycStatus'] ?? 'UNVERIFIED';
    balance = (u['balance'] as num? ?? 0).toDouble();
    hasPassword = u['hasPassword'] == true;
    userAddress = u['address'] ?? '';
  }

  Future<void> loadWallet() async {
    try {
      final d = await WalletApi.getWallet();
      final w = d['wallet'] as Map<String, dynamic>? ?? {};
      balance = (w['balance'] as num? ?? 0).toDouble();
      dailySpent = (w['dailySpent'] as num? ?? 0).toDouble();
      linkedAccounts =
          List<Map<String, dynamic>>.from(d['linkedAccounts'] ?? []);
      notifyListeners();
    } on ApiException catch (e) {
      _setErr(e.message);
    }
  }

  Future<void> loadTransactions({String? type}) async {
    try {
      final d = await WalletApi.getTransactions(type: type);
      transactions = (d['transactions'] as List? ?? [])
          .map((j) => Transaction.fromJson(j as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } on ApiException catch (e) {
      _setErr(e.message);
    }
  }

  Future<Map<String, dynamic>?> initTopUp(double amount) async {
    _load(true);
    clearError();
    try {
      return await WalletApi.initializeTopUp(amount);
    } on ApiException catch (e) {
      _setErr(e.message);
      return null;
    } finally {
      _load(false);
    }
  }

  Future<bool> verifyTopUp(String ref) async {
    _load(true);
    clearError();
    try {
      final d = await WalletApi.verifyTopUp(ref);
      balance = (d['newBalance'] as num? ?? balance).toDouble();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setErr(e.message);
      return false;
    } finally {
      _load(false);
    }
  }

  Future<bool> transfer(
      {required String recipient,
      required double amount,
      String? description}) async {
    _load(true);
    clearError();
    try {
      final d = await WalletApi.transfer(
          recipientIdentifier: recipient,
          amount: amount,
          description: description);
      balance = (d['newBalance'] as num? ?? balance).toDouble();
      notifyListeners();
      await loadTransactions();
      return true;
    } on ApiException catch (e) {
      _setErr(e.message);
      return false;
    } finally {
      _load(false);
    }
  }

  Future<bool> submitKyc1({String? bvn, String? nin}) async {
    _load(true);
    clearError();
    try {
      final d = await KycApi.submitTier1(bvn: bvn, nin: nin);
      kycTier = d['kycTier'] ?? kycTier;
      kycStatus = d['kycStatus'] ?? kycStatus;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setErr(e.message);
      return false;
    } finally {
      _load(false);
    }
  }

  Future<bool> submitKyc2(
      {required String bvn,
      required String nin,
      required String docType}) async {
    _load(true);
    clearError();
    try {
      final d =
          await KycApi.submitTier2(bvn: bvn, nin: nin, documentType: docType);
      kycTier = d['kycTier'] ?? kycTier;
      kycStatus = d['kycStatus'] ?? kycStatus;
      _err = d['message']; // surface success message
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setErr(e.message);
      return false;
    } finally {
      _load(false);
    }
  }

  Future<bool> submitKyc3({required String docType}) async {
    _load(true);
    clearError();
    try {
      final d = await KycApi.submitTier3(documentType: docType);
      kycTier = d['kycTier'] ?? kycTier;
      kycStatus = d['kycStatus'] ?? kycStatus;
      _err = d['message']; // surface success message
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setErr(e.message);
      return false;
    } finally {
      _load(false);
    }
  }

  Future<bool> updateProfile(
      {String? name, String? email, String? phone, String? address}) async {
    _load(true);
    clearError();
    try {
      await AuthApi.updateProfile(
          name: name, email: email, phone: phone, address: address);
      if (name != null) userName = name;
      if (email != null) userEmail = email;
      if (phone != null) userPhone = phone;
      if (address != null) userAddress = address;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setErr(e.message);
      return false;
    } finally {
      _load(false);
    }
  }

  void toggleRole() {
    activeRole =
        activeRole == UserRole.consumer ? UserRole.merchant : UserRole.consumer;
    notifyListeners();
  }
}

final appState = AppState();

// ─── Helpers ──────────────────────────────────────────────────────────────────
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    appState.addListener(_u);
  }

  @override
  void dispose() {
    appState.removeListener(_u);
    super.dispose();
  }

  void _u() => setState(() {});
  @override
  Widget build(BuildContext context) =>
      appState.isAuthenticated ? const MainLayout() : const AuthScreen();
}

// Abbreviated (for daily limit display only)
String _fmt(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}

// Full amount with thousand separators
String _fmtFull(double v) {
  final parts = v.toStringAsFixed(2).split('.');
  final whole = parts[0];
  final buffer = StringBuffer();
  for (int i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return '${buffer.toString()}.${parts[1]}';
}

String _timeAgo(DateTime dt) {
  final d = DateTime.now().difference(dt);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

PageRouteBuilder _slide(Widget page) => PageRouteBuilder(
      pageBuilder: (_, a, __) => page,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, a, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
void _snack(BuildContext ctx, String msg, {bool error = false}) =>
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : null,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));

// ─── Primary Button ───────────────────────────────────────────────────────────
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  const PrimaryButton(
      {super.key,
      required this.label,
      this.onPressed,
      this.loading = false,
      this.icon});
  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _s = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.loading && widget.onPressed != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => _c.forward() : null,
      onTapUp: enabled
          ? (_) {
              _c.reverse();
              widget.onPressed!();
            }
          : null,
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
          scale: _s,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              color: enabled ? kDark : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(18),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                          color: kDark.withOpacity(0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 5))
                    ]
                  : [],
            ),
            alignment: Alignment.center,
            child: widget.loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon,
                          color: enabled ? Colors.white : Colors.grey.shade500,
                          size: 18),
                      const SizedBox(width: 8)
                    ],
                    Text(widget.label,
                        style: TextStyle(
                            color:
                                enabled ? Colors.white : Colors.grey.shade500,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ]),
          )),
    );
  }
}

// ─── PIN Pad ──────────────────────────────────────────────────────────────────
class PinPad extends StatefulWidget {
  final int length;
  final Future<void> Function(String) onComplete;
  const PinPad({super.key, this.length = 4, required this.onComplete});
  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with TickerProviderStateMixin {
  String _v = '';
  bool _busy = false;
  late AnimationController _shakeCtrl;
  late Animation<double> _shake;
  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shake = Tween<double>(begin: 0.0, end: 1.0).animate(_shakeCtrl);
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _tap(String d) {
    if (_busy || _v.length >= widget.length) return;
    setState(() => _v += d);
    HapticFeedback.lightImpact();
    if (_v.length == widget.length) _submit();
  }

  void _del() {
    if (_busy || _v.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _v = _v.substring(0, _v.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await widget.onComplete(_v);
    } catch (_) {
      await _shakeCtrl.forward(from: 0);
      setState(() {
        _v = '';
        _busy = false;
      });
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        AnimatedBuilder(
          animation: _shake,
          builder: (_, child) => Transform.translate(
              offset: Offset(math.sin(_shake.value * math.pi * 8) * 8, 0),
              child: child),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.length, (i) {
                final f = i < _v.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: f ? 18 : 14,
                  height: f ? 18 : 14,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: f ? kDark : Colors.transparent,
                      border: Border.all(
                          color: f ? kDark : Colors.grey.shade400, width: 2)),
                );
              })),
        ),
        const SizedBox(height: 36),
        if (_busy)
          const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: kDark, strokeWidth: 2.5))
        else
          Column(children: [
            for (final row in [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['', '0', '⌫']
            ])
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: row.map((k) {
                    if (k.isEmpty) return const SizedBox(width: 88, height: 72);
                    return _Key(
                        label: k, onTap: k == '⌫' ? _del : () => _tap(k));
                  }).toList()),
          ]),
      ]);
}

class _Key extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _Key({required this.label, required this.onTap});
  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
    _s = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => _c.forward(),
        onTapUp: (_) {
          _c.reverse();
          widget.onTap();
        },
        onTapCancel: () => _c.reverse(),
        child: ScaleTransition(
            scale: _s,
            child: Container(
              width: 88,
              height: 72,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: widget.label == '⌫' ? Colors.transparent : kCard,
                borderRadius: BorderRadius.circular(18),
                boxShadow: widget.label == '⌫'
                    ? []
                    : [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ],
              ),
              alignment: Alignment.center,
              child: widget.label == '⌫'
                  ? const Icon(Icons.backspace_outlined,
                      color: kSlate, size: 22)
                  : Text(widget.label,
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: kDark)),
            )),
      );
}

// ─── Auth Screen ──────────────────────────────────────────────────────────────
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String _step = 'WELCOME';
  bool _usePassword = false;
  final _idCtrl = TextEditingController(),
      _nameCtrl = TextEditingController(),
      _phoneCtrl = TextEditingController(),
      _pwCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    appState.addListener(_u);
  }

  @override
  void dispose() {
    appState.removeListener(_u);
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  void _u() => setState(() {});
  void _go(String step) => setState(() => _step = step);

  Future<void> _doLogin(String credential) async {
    bool ok;
    if (_usePassword)
      ok = await appState.login(
          identifier: _idCtrl.text.trim(), password: credential);
    else
      ok = await appState.login(
          identifier: _idCtrl.text.trim(), pin: credential);
    if (!ok && mounted)
      _snack(context, appState.errorMessage ?? 'Login failed', error: true);
  }

  Future<void> _doRegister(String pin) async {
    final ok = await appState.register(
        name: _nameCtrl.text.trim(), phone: _phoneCtrl.text.trim(), pin: pin);
    if (!ok && mounted)
      _snack(context, appState.errorMessage ?? 'Registration failed',
          error: true);
  }

  @override
  Widget build(BuildContext context) => _screen();

  Widget _screen() {
    switch (_step) {
      case 'WELCOME':
        return _welcome();
      case 'IDENTIFIER':
        return _identifier();
      case 'LOGIN_CRED':
        return _loginCred();
      case 'REG_NAME':
        return _regName();
      case 'REG_PHONE':
        return _regPhone();
      case 'REG_PIN':
        return _regPin();
      default:
        return _welcome();
    }
  }

  Widget _welcome() => Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 40),
              child: Column(children: [
                const Spacer(flex: 2),
                Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                        color: kDark, borderRadius: BorderRadius.circular(28)),
                    child: const Icon(Icons.contactless_rounded,
                        size: 52, color: Colors.white)),
                const SizedBox(height: 28),
                const Text('TapPay',
                    style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: kDark,
                        letterSpacing: -1.5)),
                const SizedBox(height: 8),
                Text('Instant. Contactless. Yours.',
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500)),
                const Spacer(flex: 3),
                PrimaryButton(
                    label: 'Sign In',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () => _go('IDENTIFIER')),
                const SizedBox(height: 14),
                SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => _go('REG_NAME'),
                      style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: Colors.grey.shade300, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18))),
                      child: const Text('Create an Account',
                          style: TextStyle(
                              color: kDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                    )),
                const SizedBox(height: 24),
                Text('Secured by TapPay · CBN Compliant',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              ]))));

  Widget _identifier() => _shell(
      back: () => _go('WELCOME'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _hdr('Welcome back.', 'Enter your phone number or email to continue.'),
        const SizedBox(height: 36),
        _fld(
            ctrl: _idCtrl,
            label: 'Phone or Email',
            icon: Icons.person_outline_rounded,
            keyboard: TextInputType.emailAddress,
            onChange: (_) => setState(() {})),
        const Spacer(),
        PrimaryButton(
            label: 'Continue',
            onPressed:
                _idCtrl.text.trim().isEmpty ? null : () => _go('LOGIN_CRED')),
      ]));

  Widget _loginCred() => _shell(
      back: () => _go('IDENTIFIER'),
      child: Column(children: [
        const SizedBox(height: 8),
        Text(_usePassword ? 'Enter Password' : 'Enter your PIN',
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800, color: kDark)),
        const SizedBox(height: 8),
        Text(
            _usePassword
                ? 'Use your account password to sign in'
                : 'Use your 4-digit TapPay PIN',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        const SizedBox(height: 32),
        if (_usePassword) ...[
          _fld(
              ctrl: _pwCtrl,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              obscure: true,
              onChange: (_) => setState(() {})),
          const Spacer(),
          PrimaryButton(
              label: 'Sign In',
              loading: appState.isLoading,
              onPressed: _pwCtrl.text.isNotEmpty
                  ? () => _doLogin(_pwCtrl.text)
                  : null),
        ] else
          PinPad(onComplete: _doLogin),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() {
            _usePassword = !_usePassword;
            _pwCtrl.clear();
          }),
          child: Text(_usePassword ? 'Use PIN instead' : 'Use password instead',
              style: TextStyle(color: kSlate, fontWeight: FontWeight.w600)),
        ),
      ]));

  Widget _regName() => _shell(
      back: () => _go('WELCOME'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _hdr('Let\'s get started.', 'What should we call you?'),
        const SizedBox(height: 36),
        _fld(
            ctrl: _nameCtrl,
            label: 'Full Name',
            icon: Icons.badge_outlined,
            cap: TextCapitalization.words,
            onChange: (_) => setState(() {})),
        const Spacer(),
        PrimaryButton(
            label: 'Continue',
            onPressed:
                _nameCtrl.text.trim().isEmpty ? null : () => _go('REG_PHONE')),
      ]));

  Widget _regPhone() => _shell(
      back: () => _go('REG_NAME'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _hdr('Your phone number.',
            'This will be your TapPay account identifier.'),
        const SizedBox(height: 36),
        _fld(
            ctrl: _phoneCtrl,
            label: 'e.g. 08012345678',
            icon: Icons.phone_outlined,
            keyboard: TextInputType.phone,
            onChange: (_) => setState(() {})),
        const Spacer(),
        PrimaryButton(
            label: 'Continue',
            onPressed:
                _phoneCtrl.text.trim().isEmpty ? null : () => _go('REG_PIN')),
      ]));

  Widget _regPin() => _shell(
      back: () => _go('REG_PHONE'),
      child: Column(children: [
        const SizedBox(height: 8),
        const Text('Create a 4-digit PIN',
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800, color: kDark)),
        const SizedBox(height: 8),
        Text('You\'ll use this to sign in and authorise transactions',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        const SizedBox(height: 48),
        PinPad(onComplete: _doRegister),
        const Spacer(),
      ]));

  Widget _shell({required Widget child, required VoidCallback back}) =>
      Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
            leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: back)),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                child: child)),
      );
  Widget _hdr(String t, String s) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t,
            style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: kDark,
                height: 1.1)),
        const SizedBox(height: 8),
        Text(s, style: TextStyle(fontSize: 15, color: Colors.grey.shade500)),
      ]);
  Widget _fld(
          {required TextEditingController ctrl,
          required String label,
          required IconData icon,
          TextInputType keyboard = TextInputType.text,
          TextCapitalization cap = TextCapitalization.none,
          bool obscure = false,
          required Function(String) onChange}) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        textCapitalization: cap,
        autofocus: true,
        obscureText: obscure,
        onChanged: onChange,
        style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w600, color: kDark),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: kSlate, size: 20),
          labelStyle: TextStyle(
              color: Colors.grey.shade500, fontWeight: FontWeight.w500),
          filled: true,
          fillColor: kCard,
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: kBorder, width: 1.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: kDark, width: 2)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      );
}

// ─── Main Layout ──────────────────────────────────────────────────────────────
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _idx = 0;
  @override
  Widget build(BuildContext context) {
    final screens = appState.activeRole == UserRole.merchant
        ? [
            const MerchantDashboard(),
            const ActivityScreen(),
            const WalletScreen(),
            const ProfileScreen()
          ]
        : [
            const ConsumerDashboard(),
            const ActivityScreen(),
            const WalletScreen(),
            const ProfileScreen()
          ];
    return Scaffold(
      body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(key: ValueKey(_idx), child: screens[_idx])),
      extendBody: true,
      bottomNavigationBar:
          _NavBar(current: _idx, onTap: (i) => setState(() => _idx = i)),
      floatingActionButton: _PayFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class _NavBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _NavBar({required this.current, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
        height: 72,
        decoration: BoxDecoration(
            color: kCard,
            border: const Border(top: BorderSide(color: kBorder, width: 1)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, -4))
            ]),
        child: Row(children: [
          _tab(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
          _tab(1, Icons.receipt_long_rounded, Icons.receipt_long_outlined,
              'Activity'),
          const SizedBox(width: 72),
          _tab(2, Icons.account_balance_wallet_rounded,
              Icons.account_balance_wallet_outlined, 'Wallet'),
          _tab(
              3, Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
        ]),
      );
  Widget _tab(int i, IconData active, IconData idle, String label) {
    final s = current == i;
    return Expanded(
        child: GestureDetector(
      onTap: () => onTap(i),
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(s ? active : idle,
                key: ValueKey(s),
                color: s ? kDark : Colors.grey.shade400,
                size: 24)),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: s ? FontWeight.w700 : FontWeight.w500,
                color: s ? kDark : Colors.grey.shade400)),
      ]),
    ));
  }
}

class _PayFab extends StatefulWidget {
  @override
  State<_PayFab> createState() => _PayFabState();
}

class _PayFabState extends State<_PayFab> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _s = Tween<double>(begin: 1.0, end: 0.90)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => _c.forward(),
        onTapUp: (_) {
          _c.reverse();
          Navigator.push(
              context,
              _slide(TapPayPaymentScreen(
                  onTransferTap: () => Navigator.push(
                      context, _slide(const TransferScreen()))))).then((_) {
            appState.loadWallet();
            appState.loadTransactions();
          });
        },
        onTapCancel: () => _c.reverse(),
        child: ScaleTransition(
            scale: _s,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: kDark,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: kDark.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6))
                  ]),
              child: const Icon(Icons.contactless_rounded,
                  color: Colors.white, size: 30),
            )),
      );
}

// ─── Consumer Dashboard ───────────────────────────────────────────────────────
class ConsumerDashboard extends StatefulWidget {
  const ConsumerDashboard({super.key});
  @override
  State<ConsumerDashboard> createState() => _ConsumerDashboardState();
}

class _ConsumerDashboardState extends State<ConsumerDashboard> {
  bool _balVis = true;
  final _scrollCtrl = ScrollController();
  int _prevTxCount = 0;

  @override
  void initState() {
    super.initState();
    appState.addListener(_u);
    appState.loadWallet();
    appState.loadTransactions();
  }

  @override
  void dispose() {
    appState.removeListener(_u);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _u() {
    if (mounted) {
      final newCount = appState.transactions.length;
      if (newCount > _prevTxCount && _prevTxCount > 0) {
        // New transaction arrived — scroll to top
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut);
          }
        });
      }
      _prevTxCount = newCount;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final greeting = h < 12
        ? 'Good morning'
        : h < 17
            ? 'Good afternoon'
            : 'Good evening';
    return Scaffold(
        backgroundColor: kBg,
        body: RefreshIndicator(
          color: kDark,
          strokeWidth: 2,
          onRefresh: () async {
            await appState.loadWallet();
            await appState.loadTransactions();
          },
          child: CustomScrollView(controller: _scrollCtrl, slivers: [
            SliverToBoxAdapter(
                child: Column(children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(24, 64, 24, 0),
                  child: Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(greeting,
                              style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          Text(
                              appState.userName.isEmpty
                                  ? 'Welcome'
                                  : appState.userName,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: kDark)),
                        ])),
                    GestureDetector(
                      onTap: () =>
                          Navigator.push(context, _slide(const KycScreen())),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: appState.kycTier == 0
                              ? const Color(0xFFFEF2F2)
                              : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: appState.kycTier == 0
                                  ? const Color(0xFFFECACA)
                                  : const Color(0xFFBBF7D0)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                              appState.kycTier == 0
                                  ? Icons.warning_amber_rounded
                                  : Icons.verified_rounded,
                              size: 13,
                              color: appState.kycTier == 0
                                  ? Colors.red.shade600
                                  : Colors.green.shade600),
                          const SizedBox(width: 5),
                          Text(
                              appState.kycTier == 0
                                  ? 'Verify Identity'
                                  : 'Tier ${appState.kycTier} Verified',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: appState.kycTier == 0
                                      ? Colors.red.shade600
                                      : Colors.green.shade600)),
                        ]),
                      ),
                    ),
                  ])),
              const SizedBox(height: 24),
              // Balance card
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                            color: kDark.withOpacity(0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 10))
                      ],
                    ),
                    child: Stack(children: [
                      Positioned(
                          right: -20,
                          top: -20,
                          child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.04)))),
                      Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text('TOTAL BALANCE',
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5)),
                                  const Spacer(),
                                  GestureDetector(
                                      onTap: () =>
                                          setState(() => _balVis = !_balVis),
                                      child: Icon(
                                          _balVis
                                              ? Icons.visibility_rounded
                                              : Icons.visibility_off_rounded,
                                          color: Colors.white.withOpacity(0.4),
                                          size: 18)),
                                ]),
                                const SizedBox(height: 10),
                                Text(
                                    _balVis
                                        ? '₦${_fmtFull(appState.balance)}'
                                        : '₦ ••••••',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 34,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1)),
                                const SizedBox(height: 4),
                                _limitRow(),
                                const SizedBox(height: 28),
                                Row(children: [
                                  Expanded(
                                      child: _CBtn(
                                          label: 'Add Money',
                                          icon: Icons.add_rounded,
                                          onTap: () => Navigator.push(context,
                                              _slide(const TopUpScreen())))),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: _CBtn(
                                          label: 'Send',
                                          icon: Icons.arrow_upward_rounded,
                                          ghost: true,
                                          onTap: () => Navigator.push(context,
                                              _slide(const TransferScreen())))),
                                ]),
                              ])),
                    ]),
                  )),
              const SizedBox(height: 32),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sLbl('Quick Actions'),
                        const SizedBox(height: 16),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _ATile(
                                  icon: Icons.contactless_rounded,
                                  label: 'NFC Send',
                                  color: const Color(0xFF0F172A),
                                  ic: Colors.white,
                                  onTap: () => Navigator.push(
                                      context,
                                      _slide(TapPayPaymentScreen(
                                          onTransferTap: () => Navigator.push(
                                              context,
                                              _slide(const TransferScreen())))))),
                              _ATile(
                                  icon: Icons.contactless_outlined,
                                  label: 'NFC Receive',
                                  color: const Color(0xFFF0FDF4),
                                  ic: const Color(0xFF16A34A),
                                  onTap: () => Navigator.push(
                                      context,
                                      _slide(TapPayPaymentScreen(
                                          initialMode: 'NFC_RECEIVE',
                                          onTransferTap: () => Navigator.push(
                                              context,
                                              _slide(const TransferScreen())))))),
                              _ATile(
                                  icon: Icons.qr_code_rounded,
                                  label: 'Show QR',
                                  color: const Color(0xFFEFF6FF),
                                  ic: const Color(0xFF3B82F6),
                                  onTap: () => Navigator.push(
                                      context,
                                      _slide(TapPayPaymentScreen(
                                          onTransferTap: () => Navigator.push(
                                              context,
                                              _slide(const TransferScreen())))))),
                              _ATile(
                                  icon: Icons.qr_code_scanner_rounded,
                                  label: 'Scan QR',
                                  color: const Color(0xFFFFFBEB),
                                  ic: const Color(0xFFF59E0B),
                                  onTap: () => Navigator.push(
                                      context,
                                      _slide(TapPayPaymentScreen(
                                          initialMode: 'QR_SCAN',
                                          onTransferTap: () => Navigator.push(
                                              context,
                                              _slide(const TransferScreen())))))),
                            ]),
                      ])),
              const SizedBox(height: 32),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(children: [
                    _sLbl('Recent Transactions'),
                    const Spacer(),
                    TextButton(
                        onPressed: () {},
                        child: Text('See all',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600))),
                  ])),
              const SizedBox(height: 8),
            ])),
            appState.transactions.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(children: [
                          Icon(Icons.receipt_long_rounded,
                              size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No transactions yet',
                              style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.w500)),
                        ])))
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _TxTile(
                            tx: appState.transactions[i],
                            onTap: () => Navigator.push(
                                context,
                                _slide(TransactionDetailScreen(
                                    tx: appState.transactions[i]))))),
                    childCount: appState.transactions.length > 6
                        ? 6
                        : appState.transactions.length,
                  )),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ]),
        ));
  }

  Widget _limitRow() {
    final limits = [0, 30000, 200000, 5000000];
    final limit =
        appState.kycTier < limits.length ? limits[appState.kycTier] : 5000000;
    if (appState.kycTier == 0)
      return Text('Identity verification required to transact',
          style: TextStyle(
              color: Colors.orange.shade300,
              fontSize: 11,
              fontWeight: FontWeight.w500));
    return Text(
        'Daily limit: ₦${_fmt(limit.toDouble())}  ·  Tier ${appState.kycTier}',
        style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 11,
            fontWeight: FontWeight.w500));
  }
}

Widget _sLbl(String t) => Text(t,
    style: const TextStyle(
        fontSize: 16, fontWeight: FontWeight.w800, color: kDark));

class _CBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool ghost;
  const _CBtn(
      {required this.label,
      required this.icon,
      required this.onTap,
      this.ghost = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
            color: ghost ? Colors.white.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: ghost
                ? Border.all(color: Colors.white.withOpacity(0.15))
                : null),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              size: 16, color: ghost ? Colors.white.withOpacity(0.8) : kDark),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: ghost ? Colors.white.withOpacity(0.8) : kDark)),
        ]),
      ));
}

class _ATile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, ic;
  final VoidCallback onTap;
  const _ATile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.ic,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
      label: label,
      button: true,
      child: GestureDetector(
          onTap: onTap,
          child: Column(children: [
            Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(20)),
                child: Icon(icon, color: ic, size: 26)),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: kDark)),
          ])));
}

// ─── Transaction Tile ─────────────────────────────────────────────────────────
class _TxTile extends StatelessWidget {
  final Transaction tx;
  final VoidCallback? onTap;
  const _TxTile({required this.tx, this.onTap});
  IconData get _icon {
    switch (tx.type) {
      case 'TOP_UP':
        return Icons.add_circle_outline_rounded;
      case 'TRANSFER':
        return Icons.arrow_upward_rounded;
      case 'WITHDRAWAL':
        return Icons.account_balance_rounded;
      case 'RECEIVE':
        return Icons.arrow_downward_rounded;
      default:
        return Icons.contactless_rounded;
    }
  }

  String get _label {
    switch (tx.type) {
      case 'TOP_UP':
        return 'Top-Up';
      case 'TRANSFER':
        return 'Transfer';
      case 'WITHDRAWAL':
        return 'Withdrawal';
      case 'RECEIVE':
        return 'Received';
      default:
        return 'Payment';
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBorder, width: 1)),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: tx.isCredit
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(_icon,
                    color: tx.isCredit ? const Color(0xFF16A34A) : kSlate,
                    size: 20)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(tx.description,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: kDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(_label,
                      style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${tx.isCredit ? '+' : '−'}₦${_fmtFull(tx.amount)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: tx.isCredit ? const Color(0xFF16A34A) : kDark)),
              Text(_timeAgo(tx.timestamp),
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
            ]),
          ]),
        ),
      );
}

// ─── Transaction Detail + Receipt ────────────────────────────────────────────
class TransactionDetailScreen extends StatelessWidget {
  final Transaction tx;
  const TransactionDetailScreen({super.key, required this.tx});
  String get _typeLabel {
    switch (tx.type) {
      case 'TOP_UP':
        return 'Wallet Top-Up';
      case 'TRANSFER':
        return 'Money Transfer';
      case 'WITHDRAWAL':
        return 'Bank Withdrawal';
      case 'NFC':
        return 'NFC Payment';
      case 'QR':
        return 'QR Payment';
      default:
        return 'Payment';
    }
  }

  String _fmtDate(DateTime dt) => '${dt.day} ${[
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][dt.month - 1]} ${dt.year}';
  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(title: const Text('Receipt'), actions: [
          IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: () => _share(context)),
        ]),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                      color: tx.status == 'SUCCESS'
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFFEF2F2),
                      shape: BoxShape.circle),
                  child: Icon(
                      tx.status == 'SUCCESS'
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      size: 44,
                      color: tx.status == 'SUCCESS'
                          ? const Color(0xFF16A34A)
                          : Colors.red.shade400)),
              const SizedBox(height: 16),
              Text('${tx.isCredit ? '+' : '−'}₦${tx.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 38, fontWeight: FontWeight.w900, color: kDark)),
              const SizedBox(height: 4),
              Text(_typeLabel,
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 15,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 28),
              Container(
                  decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: kBorder)),
                  child: Column(children: [
                    Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(children: [
                          _row(
                              'Reference',
                              tx.id.length > 16
                                  ? '${tx.id.substring(0, 16)}…'
                                  : tx.id),
                          _row('Type', _typeLabel),
                          _row('Status', tx.status ?? 'SUCCESS',
                              valueColor: tx.status == 'SUCCESS'
                                  ? const Color(0xFF16A34A)
                                  : Colors.orange),
                          _row('Amount', '₦${tx.amount.toStringAsFixed(2)}'),
                          _row('Direction',
                              tx.isCredit ? 'Incoming' : 'Outgoing'),
                          if (tx.senderName != null)
                            _row('From', tx.senderName!),
                          if (tx.receiverName != null)
                            _row('To', tx.receiverName!),
                          _row('Date', _fmtDate(tx.timestamp)),
                          _row('Time', _fmtTime(tx.timestamp)),
                        ])),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: List.generate(
                              30,
                              (_) => Expanded(
                                  child: Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 2),
                                      height: 1,
                                      color: kBorder))),
                        )),
                    Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(children: [
                          Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                  color: kDark,
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.contactless_rounded,
                                  color: Colors.white, size: 18)),
                          const SizedBox(width: 10),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('TapPay',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: kDark)),
                                Text('Contactless Digital Wallet',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500)),
                              ]),
                          const Spacer(),
                          Text('CBN Licensed',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.w600)),
                        ])),
                  ])),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                    child: _OutBtn(
                        icon: Icons.screenshot_rounded,
                        label: 'Screenshot',
                        onTap: () => _snack(context,
                            'Take a screenshot of this screen to save your receipt'))),
                const SizedBox(width: 12),
                Expanded(
                    child: _OutBtn(
                        icon: Icons.share_rounded,
                        label: 'Share',
                        onTap: () => _share(context))),
              ]),
              const SizedBox(height: 12),
              PrimaryButton(
                  label: 'Done', onPressed: () => Navigator.pop(context)),
            ])),
      );

  Widget _row(String label, String value, {Color? valueColor}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: valueColor ?? kDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w700))),
        ]),
      );

  void _share(BuildContext context) {
    final text =
        'TapPay Receipt\n──────────────\nType: $_typeLabel\nAmount: ₦${tx.amount.toStringAsFixed(2)}\nStatus: ${tx.status ?? 'SUCCESS'}\nDate: ${_fmtDate(tx.timestamp)} ${_fmtTime(tx.timestamp)}\nRef: ${tx.id}\n──────────────\nPowered by TapPay';
    Clipboard.setData(ClipboardData(text: text));
    _snack(context, 'Receipt copied to clipboard — paste anywhere to share');
  }
}

class _OutBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OutBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: kDark),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14, color: kDark))
        ]),
      ));
}

// ─── Merchant Dashboard ───────────────────────────────────────────────────────
class MerchantDashboard extends StatelessWidget {
  const MerchantDashboard({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
          child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Merchant Terminal',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: kDark)),
                  Text('Accept payments instantly',
                      style: TextStyle(color: kSlate, fontSize: 13)),
                ])),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBBF7D0))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: Color(0xFF22C55E), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text('Terminal Active',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A))),
                ])),
          ]),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
                child: _MStat(
                    label: "Today's Revenue",
                    value: '₦0.00',
                    icon: Icons.trending_up_rounded,
                    ic: const Color(0xFF22C55E))),
            const SizedBox(width: 12),
            Expanded(
                child: _MStat(
                    label: 'Transactions',
                    value: '0',
                    icon: Icons.receipt_long_rounded,
                    ic: const Color(0xFF3B82F6))),
          ]),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () =>
                Navigator.push(
                    context,
                    _slide(TapPayPaymentScreen(
                        onTransferTap: () => Navigator.push(
                            context, _slide(const TransferScreen()))))),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [kDark, Color(0xFF1E3A5F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                        color: kDark.withOpacity(0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 10))
                  ]),
              child: Column(children: [
                Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.contactless_rounded,
                        color: Colors.white, size: 36)),
                const SizedBox(height: 20),
                const Text('Accept Payment',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Tap to collect via NFC or QR code',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 13)),
              ]),
            ),
          ),
        ]),
      )));
}

class _MStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color ic;
  const _MStat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.ic});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: ic, size: 22),
        const SizedBox(height: 12),
        Text(value,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: kDark)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500))
      ]));
}

// ─── Activity Screen ──────────────────────────────────────────────────────────
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String _filter = 'All';
  @override
  void initState() {
    super.initState();
    appState.addListener(_u);
    appState.loadTransactions();
  }

  @override
  void dispose() {
    appState.removeListener(_u);
    super.dispose();
  }

  void _u() => setState(() {});

  List<Transaction> get _list {
    if (_filter == 'All') return appState.transactions;
    final m = {
      'Received': 'RECEIVE',
      'Sent': 'TRANSFER',
      'Top-Ups': 'TOP_UP',
      'Payments': 'NFC'
    };
    return appState.transactions.where((t) => t.type == m[_filter]).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ['All', 'Received', 'Sent', 'Top-Ups', 'Payments'];
    return Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Activity',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: kDark)),
                    Text('Your full transaction history',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13)),
                    const SizedBox(height: 20),
                    SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: filters.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final s = _filter == filters[i];
                            return GestureDetector(
                              onTap: () => setState(() => _filter = filters[i]),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 18),
                                decoration: BoxDecoration(
                                    color: s ? kDark : kCard,
                                    borderRadius: BorderRadius.circular(50),
                                    border:
                                        Border.all(color: s ? kDark : kBorder)),
                                alignment: Alignment.center,
                                child: Text(filters[i],
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: s
                                            ? Colors.white
                                            : Colors.grey.shade500)),
                              ),
                            );
                          },
                        )),
                    const SizedBox(height: 20),
                  ])),
          Expanded(
              child: _list.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          Icon(Icons.receipt_long_rounded,
                              size: 52, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No transactions here',
                              style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.w500)),
                        ]))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _list.length,
                      itemBuilder: (_, i) => _TxTile(
                          tx: _list[i],
                          onTap: () => Navigator.push(context,
                              _slide(TransactionDetailScreen(tx: _list[i])))),
                    )),
        ])));
  }
}

// ─── Wallet Screen ────────────────────────────────────────────────────────────
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    appState.addListener(_u);
    appState.loadWallet();
  }

  @override
  void dispose() {
    appState.removeListener(_u);
    super.dispose();
  }

  void _u() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final tierLabels = [
      'Unverified',
      'Basic (Tier 1)',
      'Standard (Tier 2)',
      'Premium (Tier 3)'
    ];
    final tierLabel = appState.kycTier < tierLabels.length
        ? tierLabels[appState.kycTier]
        : 'Premium';
    return Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Wallet',
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800, color: kDark)),
            Text('Manage your TapPay funds',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [kDark, Color(0xFF1E3A5F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                        color: kDark.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ]),
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.contactless_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 6),
                      Text('TAPPAY WALLET',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5)),
                    ]),
                    const SizedBox(height: 16),
                    Text('₦${appState.balance.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1)),
                    const SizedBox(height: 4),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(tierLabel,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w600))),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                          child: _CBtn(
                              label: 'Add Money',
                              icon: Icons.add_rounded,
                              onTap: () => Navigator.push(
                                  context, _slide(const TopUpScreen())))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _CBtn(
                              label: 'Send',
                              icon: Icons.send_rounded,
                              ghost: true,
                              onTap: () => Navigator.push(
                                  context, _slide(const TransferScreen())))),
                      const SizedBox(width: 10),
                      GestureDetector(
                          onTap: () => Navigator.push(
                              context, _slide(const KycScreen())),
                          child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.15))),
                              child: const Icon(Icons.shield_rounded,
                                  color: Colors.white, size: 20))),
                    ]),
                  ]),
            ),
            const SizedBox(height: 32),
            _sLbl('Linked Bank Accounts'),
            const SizedBox(height: 14),
            if (appState.linkedAccounts.isEmpty)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('No bank accounts linked yet.',
                      style:
                          TextStyle(color: Colors.grey.shade400, fontSize: 13)))
            else
              ...appState.linkedAccounts.map((a) => _BankTile(
                  name: a['bank_name'] ?? '', acct: a['account_name'] ?? '')),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () =>
                  Navigator.push(context, _slide(const AddBankScreen())),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kBorder, width: 1.5)),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_rounded, color: kSlate, size: 20),
                  const SizedBox(width: 8),
                  Text('Link a Bank Account',
                      style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ]),
              ),
            ),
          ]),
        )));
  }
}

class _BankTile extends StatelessWidget {
  final String name, acct;
  const _BankTile({required this.name, required this.acct});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kBorder)),
        child: Row(children: [
          Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: kBg, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.account_balance_rounded,
                  color: kDark, size: 20)),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14, color: kDark)),
            Text(acct,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ]),
          const Spacer(),
          const Icon(Icons.chevron_right_rounded, color: kSlate, size: 20),
        ]),
      );
}

// ─── Profile Screen ───────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    appState.addListener(_u);
  }

  @override
  void dispose() {
    appState.removeListener(_u);
    super.dispose();
  }

  void _u() => setState(() {});

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                  color: kDark,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: kDark.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6))
                  ]),
              child: const Icon(Icons.person_rounded,
                  size: 44, color: Colors.white)),
          const SizedBox(height: 14),
          Text(appState.userName.isEmpty ? 'TapPay User' : appState.userName,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: kDark)),
          Text(
              appState.userPhone.isEmpty
                  ? appState.userEmail
                  : appState.userPhone,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.push(context, _slide(const KycScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: appState.kycTier == 0
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: appState.kycTier == 0
                        ? const Color(0xFFFECACA)
                        : const Color(0xFFBBF7D0)),
              ),
              child: Text(
                  appState.kycTier == 0
                      ? 'Identity not verified — tap to verify'
                      : 'Tier ${appState.kycTier} Verified · ${appState.kycStatus}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: appState.kycTier == 0
                          ? Colors.red.shade600
                          : Colors.green.shade600)),
            ),
          ),
          const SizedBox(height: 32),
          _Sec(children: [
            _Tile(
                icon: Icons.edit_rounded,
                label: 'Edit Profile',
                sub: 'Update your name, phone and address',
                onTap: () =>
                    Navigator.push(context, _slide(const EditProfileScreen()))),
            _Tile(
                icon: Icons.verified_user_rounded,
                label: 'Identity Verification',
                sub: 'BVN / NIN and document submission',
                onTap: () =>
                    Navigator.push(context, _slide(const KycScreen()))),
            _Tile(
                icon: Icons.account_balance_rounded,
                label: 'Linked Bank Accounts',
                sub: 'Manage withdrawal accounts',
                onTap: () =>
                    Navigator.push(context, _slide(const AddBankScreen()))),
          ]),
          const SizedBox(height: 16),
          _Sec(children: [
            _Tile(
                icon: Icons.pin_rounded,
                label: 'Change PIN',
                sub: 'Update your 4-digit security PIN',
                onTap: () =>
                    Navigator.push(context, _slide(const ChangePinScreen()))),
            _Tile(
                icon: Icons.lock_rounded,
                label:
                    appState.hasPassword ? 'Change Password' : 'Set a Password',
                sub: appState.hasPassword
                    ? 'Update your account password'
                    : 'Add a password for extra security',
                onTap: () =>
                    Navigator.push(context, _slide(const SetPasswordScreen()))),
          ]),
          const SizedBox(height: 16),
          _Sec(children: [
            StatefulBuilder(
                builder: (ctx, set) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: kBg,
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.storefront_rounded,
                              color: kDark, size: 20)),
                      title: const Text('Merchant Mode',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: kDark)),
                      subtitle: Text('Switch to Soft POS terminal',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                      trailing: Switch.adaptive(
                          value: appState.activeRole == UserRole.merchant,
                          activeColor: kDark,
                          onChanged: (_) {
                            appState.toggleRole();
                            set(() {});
                          }),
                    )),
          ]),
          const SizedBox(height: 16),
          _Sec(children: [
            _Tile(
                icon: Icons.logout_rounded,
                label: 'Sign Out',
                iconColor: Colors.red.shade400,
                textColor: Colors.red.shade600,
                onTap: () => showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          title: const Text('Sign Out?',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          content: const Text(
                              'You\'ll need your PIN to sign back in.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  appState.logout();
                                },
                                child: Text('Sign Out',
                                    style: TextStyle(
                                        color: Colors.red.shade600,
                                        fontWeight: FontWeight.w700))),
                          ],
                        ))),
          ]),
        ]),
      )));
}

class _Sec extends StatelessWidget {
  final List<Widget> children;
  const _Sec({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBorder)),
        child: Column(
            children: children
                .map((w) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: w))
                .toList()),
      );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback onTap;
  final Color? iconColor, textColor;
  const _Tile(
      {required this.icon,
      required this.label,
      this.sub,
      required this.onTap,
      this.iconColor,
      this.textColor});
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: onTap,
        leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: kBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor ?? kDark, size: 20)),
        title: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: textColor ?? kDark)),
        subtitle: sub != null
            ? Text(sub!,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12))
            : null,
        trailing:
            const Icon(Icons.chevron_right_rounded, color: kSlate, size: 20),
      );
}

// ─── Edit Profile Screen ──────────────────────────────────────────────────────
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _name, _email, _phone, _address;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: appState.userName);
    _email = TextEditingController(text: appState.userEmail);
    _phone = TextEditingController(text: appState.userPhone);
    _address = TextEditingController(text: appState.userAddress);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await appState.updateProfile(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim());
    if (!mounted) return;
    if (ok) {
      _snack(context, 'Profile updated successfully');
      Navigator.pop(context);
    } else {
      _snack(context, appState.errorMessage ?? 'Update failed', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(title: const Text('Edit Profile')),
        body: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(children: [
              const SizedBox(height: 16),
              _f('Full Name', Icons.badge_outlined, _name),
              const SizedBox(height: 14),
              _f('Email Address', Icons.email_outlined, _email,
                  keyboard: TextInputType.emailAddress),
              const SizedBox(height: 14),
              _f('Phone Number', Icons.phone_outlined, _phone,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 14),
              _f('Address', Icons.location_on_outlined, _address),
              const Spacer(),
              PrimaryButton(
                  label: 'Save Changes',
                  loading: appState.isLoading,
                  onPressed: _save),
            ])),
      );

  Widget _f(String label, IconData icon, TextEditingController ctrl,
          {TextInputType keyboard = TextInputType.text}) =>
      TextField(
          controller: ctrl,
          keyboardType: keyboard,
          style: const TextStyle(fontWeight: FontWeight.w600, color: kDark),
          decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon, color: kSlate, size: 20),
              labelStyle: TextStyle(color: Colors.grey.shade500),
              filled: true,
              fillColor: kCard,
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: kBorder, width: 1.5)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: kDark, width: 2)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 18)));
}

// ─── Change PIN Screen ────────────────────────────────────────────────────────
class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});
  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  String _step = 'CURRENT', _currentPin = '';
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar:
            AppBar(title: Text(_step == 'CURRENT' ? 'Current PIN' : 'New PIN')),
        body: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(children: [
              Text(
                  _step == 'CURRENT'
                      ? 'Enter your current 4-digit PIN to continue'
                      : 'Choose your new 4-digit PIN',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              const SizedBox(height: 48),
              PinPad(
                  key: ValueKey(_step),
                  onComplete: (pin) async {
                    if (_step == 'CURRENT') {
                      setState(() {
                        _currentPin = pin;
                        _step = 'NEW';
                      });
                      return;
                    }
                    try {
                      await AuthApi.changePin(
                          currentPin: _currentPin, newPin: pin);
                      if (mounted) {
                        _snack(context, 'PIN changed successfully');
                        Navigator.pop(context);
                      }
                    } on ApiException catch (e) {
                      if (mounted) _snack(context, e.message, error: true);
                      rethrow;
                    }
                  }),
            ])),
      );
}

// ─── Set Password Screen ──────────────────────────────────────────────────────
class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});
  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _pinCtrl = TextEditingController(),
      _pw1 = TextEditingController(),
      _pw2 = TextEditingController();
  bool _obscure = true;
  @override
  void dispose() {
    _pinCtrl.dispose();
    _pw1.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_pw1.text != _pw2.text) {
      _snack(context, 'Passwords do not match', error: true);
      return;
    }
    if (_pw1.text.length < 6) {
      _snack(context, 'Password must be at least 6 characters', error: true);
      return;
    }
    if (_pinCtrl.text.length != 4) {
      _snack(context, 'Enter your 4-digit PIN to confirm', error: true);
      return;
    }
    try {
      await AuthApi.setPassword(password: _pw1.text, currentPin: _pinCtrl.text);
      if (mounted) {
        appState.hasPassword = true;
        appState.notifyListeners();
        _snack(context, 'Password set successfully');
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
            title: Text(
                appState.hasPassword ? 'Change Password' : 'Set a Password')),
        body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(children: [
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE))),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: Color(0xFF3B82F6), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(
                                'Your PIN handles quick daily access. A password gives you an alternative sign-in method and adds an extra layer of security.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                    height: 1.5))),
                      ])),
              const SizedBox(height: 24),
              _f('Current PIN (to confirm identity)', Icons.pin_rounded,
                  _pinCtrl,
                  keyboard: TextInputType.number, obscure: true),
              const SizedBox(height: 14),
              _f('New Password', Icons.lock_outline_rounded, _pw1,
                  obscure: _obscure),
              const SizedBox(height: 14),
              _f('Confirm Password', Icons.lock_rounded, _pw2,
                  obscure: _obscure),
              const SizedBox(height: 8),
              Row(children: [
                Checkbox(
                    value: !_obscure,
                    onChanged: (v) => setState(() => _obscure = !(v ?? false)),
                    activeColor: kDark),
                Text('Show password',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ]),
              const SizedBox(height: 24),
              PrimaryButton(
                  label: 'Save Password',
                  loading: appState.isLoading,
                  onPressed: _save),
            ])),
      );

  Widget _f(String label, IconData icon, TextEditingController ctrl,
          {TextInputType keyboard = TextInputType.text,
          bool obscure = false}) =>
      TextField(
          controller: ctrl,
          keyboardType: keyboard,
          obscureText: obscure,
          style: const TextStyle(fontWeight: FontWeight.w600, color: kDark),
          decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon, color: kSlate, size: 20),
              labelStyle: TextStyle(color: Colors.grey.shade500),
              filled: true,
              fillColor: kCard,
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: kBorder, width: 1.5)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: kDark, width: 2)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 18)));
}

// ─── KYC Screen ──────────────────────────────────────────────────────────────
class KycScreen extends StatefulWidget {
  const KycScreen({super.key});
  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _bvn1 = TextEditingController(), _nin1 = TextEditingController();
  final _bvn2 = TextEditingController(), _nin2 = TextEditingController();
  String _docType2 = 'National Passport', _docType3 = 'Utility Bill';
  @override
  void dispose() {
    _bvn1.dispose();
    _nin1.dispose();
    _bvn2.dispose();
    _nin2.dispose();
    super.dispose();
  }

  Future<void> _t1() async {
    if (_bvn1.text.trim().isEmpty && _nin1.text.trim().isEmpty) {
      _snack(context, 'Enter your BVN or NIN', error: true);
      return;
    }
    final ok = await appState.submitKyc1(
        bvn: _bvn1.text.trim().isEmpty ? null : _bvn1.text.trim(),
        nin: _nin1.text.trim().isEmpty ? null : _nin1.text.trim());
    if (!mounted) return;
    if (ok) {
      // Pre-fill tier 2 fields with the same BVN/NIN
      if (_bvn1.text.trim().isNotEmpty) _bvn2.text = _bvn1.text.trim();
      if (_nin1.text.trim().isNotEmpty) _nin2.text = _nin1.text.trim();
      _snack(context, 'Tier 1 verified! You can now transact up to ₦30,000/day.');
    } else {
      _snack(context, appState.errorMessage ?? 'Failed', error: true);
    }
  }

  Future<void> _t2() async {
    if (_bvn2.text.trim().isEmpty || _nin2.text.trim().isEmpty) {
      _snack(context, 'Both BVN and NIN are required for Tier 2', error: true);
      return;
    }
    final ok = await appState.submitKyc2(
        bvn: _bvn2.text.trim(), nin: _nin2.text.trim(), docType: _docType2);
    if (!mounted) return;
    ok
        ? _snack(context, appState.errorMessage ?? 'Tier 2 verified! Daily limit raised to ₦200,000.')
        : _snack(context, appState.errorMessage ?? 'Failed', error: true);
  }

  Future<void> _t3() async {
    final ok = await appState.submitKyc3(docType: _docType3);
    if (!mounted) return;
    ok
        ? _snack(context, appState.errorMessage ?? 'Tier 3 verified! Maximum limits unlocked.')
        : _snack(context, appState.errorMessage ?? 'Failed', error: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(title: const Text('Identity Verification')),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Status card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: appState.kycTier == 0
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: appState.kycTier == 0
                            ? const Color(0xFFFECACA)
                            : const Color(0xFFBBF7D0))),
                child: Row(children: [
                  Icon(
                      appState.kycTier == 0
                          ? Icons.warning_amber_rounded
                          : Icons.verified_rounded,
                      color: appState.kycTier == 0
                          ? Colors.orange.shade600
                          : Colors.green.shade600,
                      size: 28),
                  const SizedBox(width: 14),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            appState.kycTier == 0
                                ? 'Not Verified'
                                : 'Tier ${appState.kycTier} — ${appState.kycStatus}',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: appState.kycTier == 0
                                    ? Colors.orange.shade700
                                    : Colors.green.shade700)),
                        Text(
                            appState.kycTier == 0
                                ? 'Transactions are currently disabled'
                                : 'Your account is active',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ]),
                ]),
              ),
              const SizedBox(height: 28),

              // Tier 1
              _tierBox(
                tier: 1,
                title: 'Tier 1',
                subtitle: 'BVN or NIN  ·  ₦30,000/day  ·  ₦300,000 balance cap',
                unlocked: appState.kycTier >= 1,
                active: appState.kycTier == 0,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Provide your BVN or NIN to unlock basic transactions.',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600)),
                      const SizedBox(height: 16),
                      _kf(_bvn1, 'Bank Verification Number (BVN)', '11 digits'),
                      const SizedBox(height: 10),
                      _kf(_nin1, 'National Identity Number (NIN)', '11 digits'),
                      const SizedBox(height: 16),
                      PrimaryButton(
                          label: 'Submit Tier 1 Verification',
                          loading: appState.isLoading,
                          onPressed: appState.kycTier == 0 ? _t1 : null),
                    ]),
              ),
              const SizedBox(height: 14),

              // Tier 2
              _tierBox(
                tier: 2,
                title: 'Tier 2',
                subtitle:
                    'BVN + NIN + Gov. ID  ·  ₦200,000/day  ·  ₦500,000 balance cap',
                unlocked: appState.kycTier >= 2,
                active: appState.kycTier == 1,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Provide both BVN and NIN plus a government-issued ID for higher limits.',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600)),
                      const SizedBox(height: 16),
                      _kf(_bvn2, 'BVN', '11-digit BVN'),
                      const SizedBox(height: 10),
                      _kf(_nin2, 'NIN', '11-digit NIN'),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _docType2,
                        decoration: InputDecoration(
                            labelText: 'Government-Issued ID Type',
                            filled: true,
                            fillColor: kBg,
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: kBorder)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: kDark, width: 2)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14)),
                        items: [
                          'National Passport',
                          'Driver\'s Licence',
                          'Voter\'s Card',
                          'National ID Card'
                        ]
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _docType2 = v ?? _docType2),
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                          label: 'Submit Tier 2 Documents',
                          loading: appState.isLoading,
                          onPressed: appState.kycTier == 1 ? _t2 : null),
                    ]),
              ),
              const SizedBox(height: 14),

              // Tier 3
              _tierBox(
                tier: 3,
                title: 'Tier 3',
                subtitle: 'Full KYC  ·  ₦5,000,000/day  ·  No balance cap',
                unlocked: appState.kycTier >= 3,
                active: appState.kycTier == 2,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Submit proof of address for unlimited transaction limits. Applications are manually reviewed within 2-3 business days.',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _docType3,
                        decoration: InputDecoration(
                            labelText: 'Proof of Address Document',
                            filled: true,
                            fillColor: kBg,
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: kBorder)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: kDark, width: 2)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14)),
                        items: [
                          'Utility Bill',
                          'Bank Statement',
                          'NEPA Bill',
                          'Water Bill',
                          'Government Letter'
                        ]
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _docType3 = v ?? _docType3),
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                          label: 'Submit Tier 3 Application',
                          loading: appState.isLoading,
                          onPressed: appState.kycTier == 2 ? _t3 : null),
                    ]),
              ),
              const SizedBox(height: 20),
              Center(
                  child: Text(
                      'All personal data is encrypted and handled in accordance with CBN guidelines and the Nigeria Data Protection Act.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade400))),
            ])),
      );

  Widget _tierBox(
          {required int tier,
          required String title,
          required String subtitle,
          required bool unlocked,
          required bool active,
          required Widget child}) =>
      Container(
        decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: unlocked
                    ? const Color(0xFFBBF7D0)
                    : active
                        ? kDark
                        : kBorder,
                width: active ? 2 : 1)),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: unlocked
                    ? const Color(0xFFF0FDF4)
                    : active
                        ? kDark.withOpacity(0.04)
                        : const Color(0xFFF8FAFC),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(19))),
            child: Row(children: [
              Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: unlocked
                          ? Colors.green.shade600
                          : active
                              ? kDark
                              : Colors.grey.shade200),
                  child: Icon(
                      unlocked
                          ? Icons.check_rounded
                          : active
                              ? Icons.radio_button_checked_rounded
                              : Icons.lock_outline_rounded,
                      color: unlocked || active
                          ? Colors.white
                          : Colors.grey.shade400,
                      size: 18)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Text(title,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: unlocked ? Colors.green.shade700 : kDark)),
                      const SizedBox(width: 8),
                      if (unlocked)
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8)),
                            child: const Text('Verified',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF16A34A)))),
                      if (active)
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: kDark.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8)),
                            child: const Text('Current Step',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: kDark))),
                    ]),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ])),
            ]),
          ),
          if (active || (!unlocked && tier == appState.kycTier + 1))
            Padding(padding: const EdgeInsets.all(18), child: child),
          if (unlocked)
            Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: Text(
                    '✓ Verified. Proceed to the next tier above for higher limits.',
                    style:
                        TextStyle(fontSize: 12, color: Colors.green.shade600))),
        ]),
      );

  Widget _kf(TextEditingController ctrl, String label, String hint) =>
      TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        maxLength: 11,
        style: const TextStyle(fontWeight: FontWeight.w600, color: kDark),
        decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            counterText: '',
            filled: true,
            fillColor: kBg,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kDark, width: 2)),
            labelStyle: TextStyle(color: Colors.grey.shade500),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
      );
}

// ─── Top-Up Screen ────────────────────────────────────────────────────────────
class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});
  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final _ctrl = TextEditingController();
  String _phase = 'AMOUNT', _ref = '', _url = '', _errMsg = '';
  final _presets = [1000.0, 2000.0, 5000.0, 10000.0];
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(_ctrl.text);

  Future<void> _start() async {
    final amt = _amount;
    if (amt == null || amt < 100) {
      _snack(context, 'Minimum top-up is ₦100', error: true);
      return;
    }
    setState(() => _phase = 'PROCESSING');
    final data = await appState.initTopUp(amt);
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _phase = 'ERROR';
        _errMsg = appState.errorMessage ?? 'Could not initiate payment';
      });
      return;
    }
    setState(() {
      _ref = data['reference'] ?? '';
      _url = data['authorizationUrl'] ?? '';
      _phase = 'CONFIRM';
    });
  }

  Future<void> _verify() async {
    setState(() => _phase = 'PROCESSING');
    final ok = await appState.verifyTopUp(_ref);
    if (!mounted) return;
    if (ok) {
      setState(() => _phase = 'SUCCESS');
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) Navigator.pop(context);
      });
    } else {
      setState(() {
        _phase = 'ERROR';
        _errMsg = appState.errorMessage ?? 'Payment could not be confirmed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case 'PROCESSING':
        return _processing();
      case 'CONFIRM':
        return _confirm();
      case 'SUCCESS':
        return _success();
      case 'ERROR':
        return _error();
      default:
        return _picker();
    }
  }

  Widget _picker() => Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text('Add Money')),
      body: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(children: [
            const SizedBox(height: 16),
            Text('How much would you like to add?',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: kBorder)),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('₦',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade400)),
                const SizedBox(width: 4),
                IntrinsicWidth(
                    child: TextField(
                        controller: _ctrl,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: kDark),
                        decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '0',
                            hintStyle: TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 48,
                                fontWeight: FontWeight.w900)),
                        onChanged: (_) => setState(() {}))),
              ]),
            ),
            const SizedBox(height: 20),
            Row(
                children: _presets
                    .map((p) => Expanded(
                        child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                                onTap: () {
                                  _ctrl.text = p.toInt().toString();
                                  setState(() {});
                                },
                                child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                        color: _amount == p ? kDark : kCard,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: _amount == p
                                                ? kDark
                                                : kBorder)),
                                    alignment: Alignment.center,
                                    child: Text('₦${_fmt(p)}',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: _amount == p
                                                ? Colors.white
                                                : kDark)))))))
                    .toList()),
            const Spacer(),
            PrimaryButton(
                label: 'Continue to Payment',
                icon: Icons.arrow_forward_rounded,
                loading: appState.isLoading,
                onPressed: _amount != null && _amount! >= 100 ? _start : null),
          ])));

  Widget _processing() => Scaffold(
      backgroundColor: kBg,
      body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(color: kDark, strokeWidth: 3)),
        const SizedBox(height: 24),
        const Text('Processing…',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: kDark)),
        Text('Please wait a moment',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      ])));

  Widget _confirm() => Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text('Complete Payment')),
      body: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFBBF7D0))),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.credit_card_rounded,
                          color: Color(0xFF16A34A), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              'Tap "Pay with Paystack" to complete payment in-app. After paying, tap "I\'ve Paid" to confirm.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green.shade800,
                                  height: 1.5))),
                    ])),
            const SizedBox(height: 20),
            _infoRow('Reference', _ref, copy: true),
            const SizedBox(height: 8),
            Text(
                'Test card: 4084 0840 8408 4081  ·  Any future expiry  ·  CVV: 408',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            const Spacer(),
            PrimaryButton(
                label: 'Pay with Paystack',
                icon: Icons.open_in_new_rounded,
                onPressed: () => Navigator.push(context, _slide(_PaystackWebView(url: _url, onComplete: _verify)))),
            const SizedBox(height: 12),
            PrimaryButton(
                label: 'I\'ve Paid — Confirm',
                icon: Icons.check_circle_outline_rounded,
                onPressed: _verify),
            const SizedBox(height: 12),
            SizedBox(
                width: double.infinity,
                child: TextButton(
                    onPressed: () => setState(() {
                          _phase = 'AMOUNT';
                          _ref = '';
                          _url = '';
                        }),
                    child: Text('Cancel',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600)))),
          ])));

  Widget _infoRow(String label, String value,
          {bool copy = false, bool isLink = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade400,
                letterSpacing: 1)),
        const SizedBox(height: 6),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder)),
            child: Row(children: [
              Expanded(
                  child: Text(value,
                      maxLines: 2,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isLink ? Colors.blue.shade600 : kDark,
                          decoration:
                              isLink ? TextDecoration.underline : null))),
              if (copy)
                GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      _snack(context, '$label copied');
                    },
                    child: const Icon(Icons.copy_rounded,
                        size: 18, color: kSlate)),
            ])),
      ]);

  Widget _success() => Scaffold(
      backgroundColor: kDark,
      body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (_, v, c) => Transform.scale(scale: v, child: c),
            child: Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                    color: Color(0xFF22C55E), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 56))),
        const SizedBox(height: 32),
        const Text('Payment Confirmed',
            style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('₦${_fmt(_amount ?? 0)} added to your wallet',
            style:
                TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
        const SizedBox(height: 12),
        Text('Returning to wallet…',
            style:
                TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
      ])));

  Widget _error() => Scaffold(
      backgroundColor: kBg,
      body: Center(
          child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                            color: Colors.red.shade50, shape: BoxShape.circle),
                        child: Icon(Icons.error_outline_rounded,
                            size: 48, color: Colors.red.shade400)),
                    const SizedBox(height: 24),
                    const Text('Something went wrong',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: kDark)),
                    const SizedBox(height: 8),
                    Text(_errMsg,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                            height: 1.5)),
                    const SizedBox(height: 32),
                    PrimaryButton(
                        label: 'Try Again',
                        onPressed: () => setState(() {
                              _phase = 'AMOUNT';
                              _errMsg = '';
                            })),
                  ]))));
}

// ─── Paystack Checkout Screen ─────────────────────────────────────────────────
class _PaystackWebView extends StatefulWidget {
  final String url;
  final VoidCallback onComplete;
  const _PaystackWebView({required this.url, required this.onComplete});
  @override
  State<_PaystackWebView> createState() => _PaystackWebViewState();
}

class _PaystackWebViewState extends State<_PaystackWebView> {
  bool _opened = false;

  Future<void> _open() async {
    final uri = Uri.parse(widget.url);
    try {
      // ignore: deprecated_member_use
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) setState(() => _opened = true);
    } catch (_) {
      if (mounted) _snack(context, 'Could not open payment link', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Paystack Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBBF7D0))),
              child: const Icon(Icons.payment_rounded,
                  size: 52, color: Color(0xFF16A34A)),
            ),
            const SizedBox(height: 24),
            const Text('Paystack Secure Checkout',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kDark)),
            const SizedBox(height: 8),
            Text(
                _opened
                    ? 'Browser opened. Complete payment, then return here and confirm.'
                    : 'Tap below to open secure Paystack checkout in your browser.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14, height: 1.5)),
            const SizedBox(height: 8),
            Text('Test card: 4084 0840 8408 4081  ·  CVV: 408  ·  Any future expiry',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            const SizedBox(height: 40),
            PrimaryButton(
                label: _opened ? 'Re-open Paystack' : 'Open Paystack Checkout',
                icon: Icons.open_in_new_rounded,
                onPressed: _open),
            const SizedBox(height: 16),
            if (_opened)
              PrimaryButton(
                  label: 'I\'ve Paid — Confirm',
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onComplete();
                  }),
            const SizedBox(height: 12),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel',
                    style: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }
}

// ─── Transfer Screen ──────────────────────────────────────────────────────────
class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});
  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _to = TextEditingController(),
      _amt = TextEditingController(),
      _des = TextEditingController();
  @override
  void dispose() {
    _to.dispose();
    _amt.dispose();
    _des.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final amt = double.tryParse(_amt.text);
    if (_to.text.trim().isEmpty || amt == null || amt <= 0) {
      _snack(context, 'Enter a valid recipient and amount', error: true);
      return;
    }
    final ok = await appState.transfer(
        recipient: _to.text.trim(),
        amount: amt,
        description: _des.text.trim().isEmpty ? null : _des.text.trim());
    if (!mounted) return;
    if (ok) {
      _snack(context, 'Transfer successful');
      Navigator.pop(context);
    } else {
      _snack(context, appState.errorMessage ?? 'Transfer failed', error: true);
    }
  }

  Widget _f(TextEditingController ctrl, String label, IconData icon,
          {TextInputType keyboard = TextInputType.text,
          Function(String)? onChange}) =>
      TextField(
          controller: ctrl,
          keyboardType: keyboard,
          onChanged: onChange,
          style: const TextStyle(fontWeight: FontWeight.w600, color: kDark),
          decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon, color: kSlate, size: 20),
              filled: true,
              fillColor: kCard,
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: kBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: kDark, width: 2)),
              labelStyle: TextStyle(color: Colors.grey.shade500),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 18)));

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text('Send Money')),
      body: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(children: [
            const SizedBox(height: 8),
            _f(_to, 'Recipient phone or email', Icons.person_search_rounded),
            const SizedBox(height: 14),
            _f(_amt, 'Amount (₦)', Icons.payments_outlined,
                keyboard: TextInputType.number,
                onChange: (_) => setState(() {})),
            const SizedBox(height: 14),
            _f(_des, 'Note (optional)', Icons.notes_rounded),
            const Spacer(),
            PrimaryButton(
                label: 'Send Money',
                loading: appState.isLoading,
                onPressed:
                    _to.text.isNotEmpty && _amt.text.isNotEmpty ? _send : null),
          ])));
}

// ─── Add Bank Screen ──────────────────────────────────────────────────────────
class AddBankScreen extends StatefulWidget {
  const AddBankScreen({super.key});
  @override
  State<AddBankScreen> createState() => _AddBankScreenState();
}

class _AddBankScreenState extends State<AddBankScreen> {
  final _bName = TextEditingController(),
      _acct = TextEditingController(),
      _acctName = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _bName.dispose();
    _acct.dispose();
    _acctName.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    if (_bName.text.isEmpty || _acct.text.isEmpty) {
      _snack(context, 'Bank name and account number are required', error: true);
      return;
    }
    if (_acct.text.trim().length != 10 || int.tryParse(_acct.text.trim()) == null) {
      _snack(context, 'Account number must be exactly 10 digits', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await WalletApi.linkBankAccount(
          bankName: _bName.text.trim(),
          accountNumber: _acct.text.trim(),
          accountName: _acctName.text.trim().isEmpty ? null : _acctName.text.trim());
      if (!mounted) return;
      await appState.loadWallet();
      _snack(context, 'Bank account linked successfully');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _f(String label, IconData icon, TextEditingController ctrl,
          {TextInputType keyboard = TextInputType.text}) =>
      TextField(
          controller: ctrl,
          keyboardType: keyboard,
          style: const TextStyle(fontWeight: FontWeight.w600, color: kDark),
          decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon, color: kSlate, size: 20),
              filled: true,
              fillColor: kCard,
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: kBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: kDark, width: 2)),
              labelStyle: TextStyle(color: Colors.grey.shade500),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 18)));

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text('Link Bank Account')),
      body: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 16),
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBFDBFE))),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Color(0xFF3B82F6), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              'Link any Nigerian bank account to withdraw your TapPay balance directly. Enter your bank name and 10-digit NUBAN account number.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                  height: 1.5))),
                    ])),
            const SizedBox(height: 24),
            _f('Bank Name (e.g. GTBank, Access)', Icons.account_balance_rounded, _bName),
            const SizedBox(height: 14),
            _f('Account Number (10 digits)', Icons.numbers_rounded, _acct,
                keyboard: TextInputType.number),
            const SizedBox(height: 14),
            _f('Account Name (optional)', Icons.person_outline_rounded, _acctName),
            const Spacer(),
            PrimaryButton(
                label: 'Link Account',
                icon: Icons.link_rounded,
                loading: _loading,
                onPressed: _link),
          ])));
}
