
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

void main() {
  runApp(const TappayApp());
}

class TappayApp extends StatelessWidget {
  const TappayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TAPPAY',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          primary: const Color(0xFF0F172A),
          secondary: const Color(0xFF1E293B),
        ),
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const AuthWrapper(),
    );
  }
}

// --- Models ---

enum UserRole { consumer, merchant, admin }
enum TransactionType { payment, topUp, transfer, receive, withdraw }

class Transaction {
  final String id;
  final TransactionType type;
  final double amount;
  final String description;
  final DateTime timestamp;
  final bool isCredit;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.timestamp,
    required this.isCredit,
  });
}

// --- Services ---

class PaystackService {
  static Future<String> initializeTransaction(String email, double amount) async {
    await Future.delayed(const Duration(seconds: 2));
    return "T${DateTime.now().millisecondsSinceEpoch}";
  }

  static Future<bool> verifyTransaction(String reference) async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }
}

// --- State Management ---

class AppState extends ChangeNotifier {
  bool isAuthenticated = false;
  UserRole activeRole = UserRole.consumer;
  double balance = 125400.0;
  List<Transaction> transactions = [
    Transaction(
      id: "tx_1",
      type: TransactionType.payment,
      amount: 1500,
      description: "Starbucks Coffee",
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isCredit: false,
    ),
    Transaction(
      id: "tx_2",
      type: TransactionType.topUp,
      amount: 50000,
      description: "Paystack Wallet Funding",
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      isCredit: true,
    ),
  ];

  void login() {
    isAuthenticated = true;
    notifyListeners();
  }

  void logout() {
    isAuthenticated = false;
    notifyListeners();
  }

  void toggleRole() {
    activeRole = activeRole == UserRole.consumer ? UserRole.merchant : UserRole.consumer;
    notifyListeners();
  }

  void addTransaction(Transaction tx) {
    transactions.insert(0, tx);
    if (tx.isCredit) {
      balance += tx.amount;
    } else {
      balance -= tx.amount;
    }
    notifyListeners();
  }
}

// --- Global State Instance ---
final appState = AppState();

// --- Auth Wrapper ---

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    appState.addListener(_update);
  }

  @override
  void dispose() {
    appState.removeListener(_update);
    super.dispose();
  }

  void _update() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (!appState.isAuthenticated) {
      return const AuthScreen();
    }
    return const MainLayout();
  }
}

// --- Custom Widgets ---

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                  Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }
}

class PinInputField extends StatefulWidget {
  final int length;
  final Function(String) onComplete;
  final bool isPassword;

  const PinInputField({
    super.key,
    this.length = 4,
    required this.onComplete,
    this.isPassword = true,
  });

  @override
  State<PinInputField> createState() => _PinInputFieldState();
}

class _PinInputFieldState extends State<PinInputField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hidden input
          Opacity(
            opacity: 0,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              autofocus: true,
              onChanged: (val) {
                if (val.length == widget.length) {
                  widget.onComplete(val);
                }
              },
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
            ),
          ),
          // Visible Boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(widget.length, (index) {
              bool isFilled = _controller.text.length > index;
              bool isFocused = _controller.text.length == index;
              String char = isFilled ? _controller.text[index] : "";

              return Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isFocused ? const Color(0xFF0F172A) : Colors.grey.shade200,
                    width: 2,
                  ),
                  boxShadow: isFocused ? [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.05), blurRadius: 10, spreadRadius: 5)] : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.isPassword && isFilled ? "•" : char,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// --- Main Layout ---

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> consumerScreens = [
      const ConsumerDashboard(),
      const ActivityScreen(),
      const WalletScreen(),
      const ProfileScreen(),
    ];

    final List<Widget> merchantScreens = [
      const MerchantDashboard(),
      const ActivityScreen(), // Sharing for now
      const WalletScreen(),
      const ProfileScreen(),
    ];

    final screens = appState.activeRole == UserRole.merchant ? merchantScreens : consumerScreens;

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade100, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF0F172A),
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
            const BottomNavigationBarItem(icon: Icon(Icons.history), label: "Activity"),
            const BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: "Wallet"),
            const BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentScreen()));
        },
        backgroundColor: const Color(0xFF0F172A),
        shape: const CircleBorder(),
        elevation: 8,
        child: const Icon(Icons.contactless, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

// --- Screens ---

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String _step = "WELCOME";
  final TextEditingController _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    if (_step == "WELCOME") {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)],
                ),
                child: const Icon(Icons.smartphone, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 32),
              const Text("TAPPAY", style: TextStyle(fontSize: 40, fontWeight: FontWeight.black, letterSpacing: -1)),
              const Text("The future of contactless payments.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 18)),
              const Spacer(),
              PrimaryButton(label: "Sign In", onPressed: () => setState(() => _step = "IDENTIFIER")),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {},
                  child: const Text("Create New Account", style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_step == "IDENTIFIER") {
      return Scaffold(
        appBar: AppBar(leading: IconButton(onPressed: () => setState(() => _step = "WELCOME"), icon: const Icon(Icons.chevron_left))),
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Welcome Back", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const Text("Sign in to access your wallet", style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 48),
              TextField(
                controller: _emailController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: "Email or Phone",
                  prefixIcon: const Icon(Icons.mail_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
              const Spacer(),
              PrimaryButton(label: "Continue", onPressed: () => setState(() => _step = "PIN")),
            ],
          ),
        ),
      );
    }

    if (_step == "PIN") {
      return Scaffold(
        appBar: AppBar(leading: IconButton(onPressed: () => setState(() => _step = "IDENTIFIER"), icon: const Icon(Icons.chevron_left))),
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text("Security PIN", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const Text("Enter your 4-digit security PIN", style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 64),
              PinInputField(onComplete: (val) {
                appState.login();
              }),
              const SizedBox(height: 32),
              TextButton(onPressed: () {}, child: const Text("Forgot Security PIN?")),
            ],
          ),
        ),
      );
    }

    return const Center(child: CircularProgressIndicator());
  }
}

class ConsumerDashboard extends StatelessWidget {
  const ConsumerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Hello,", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text(appState.activeRole == UserRole.merchant ? "Business Hub" : "TAPPAY User", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.black)),
                ],
              ),
              const CircleAvatar(backgroundColor: Color(0xFF0F172A), child: Icon(Icons.person, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 32),
          // Balance Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
              borderRadius: BorderRadius.circular(40),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("AVAILABLE BALANCE", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.black, letterSpacing: 2)),
                const SizedBox(height: 8),
                Text("₦${appState.balance.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.black)),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        child: const Text("Add Funds", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        child: const Text("Withdraw", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          const Text("QUICK ACTIONS", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.black, letterSpacing: 2)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ActionItem(icon: Icons.send, label: "Send", color: Colors.blue.shade50),
              _ActionItem(icon: Icons.qr_code_scanner, label: "Scan", color: Colors.green.shade50),
              _ActionItem(icon: Icons.receipt_long, label: "Bills", color: Colors.amber.shade50),
              _ActionItem(icon: Icons.more_horiz, label: "More", color: Colors.grey.shade100),
            ],
          ),
          const SizedBox(height: 48),
          const Text("RECENT ACTIVITY", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.black, letterSpacing: 2)),
          const SizedBox(height: 16),
          ...appState.transactions.map((tx) => _TransactionTile(tx: tx)),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ActionItem({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 65,
          height: 65,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
          child: Icon(icon, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(15)),
            child: Icon(tx.isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: tx.isCredit ? Colors.green : Colors.black),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(tx.type.toString().split('.').last.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Text(
            "${tx.isCredit ? '+' : '-'}₦${tx.amount.toStringAsFixed(0)}",
            style: TextStyle(fontWeight: FontWeight.black, color: tx.isCredit ? Colors.green : Colors.black),
          ),
        ],
      ),
    );
  }
}

class MerchantDashboard extends StatelessWidget {
  const MerchantDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Soft POS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.black)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, py: 6),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Row(
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: Colors.blue),
                    SizedBox(width: 6),
                    Text("Terminal Online", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Sales Grid
          Row(
            children: [
              Expanded(child: _StatCard(label: "TODAY'S SALES", value: "₦42,000", trend: "+12%")),
              const SizedBox(width: 16),
              Expanded(child: _StatCard(label: "TRANSACTIONS", value: "18", trend: "Steady")),
            ],
          ),
          const SizedBox(height: 24),
          // Terminal Trigger
          GestureDetector(
            onTap: () {
              // Open Terminal Input
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)],
              ),
              child: const Column(
                children: [
                  Icon(Icons.smartphone, color: Colors.blueAccent, size: 48),
                  SizedBox(height: 16),
                  Text("Collect Payment", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.black)),
                  Text("Ready for NFC or QR", style: TextStyle(color: Colors.white54, fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48),
          const Text("MANAGEMENT", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.black, letterSpacing: 2)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _ToolItem(icon: Icons.bar_chart, label: "Analytics"),
              _ToolItem(icon: Icons.people, label: "Staff"),
              _ToolItem(icon: Icons.settings, label: "Settings"),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String trend;

  const _StatCard({required this.label, required this.value, required this.trend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.black, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.black)),
          Text(trend, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
        ],
      ),
    );
  }
}

class _ToolItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ToolItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF0F172A)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _mode = "IDLE"; // IDLE, NFC, QR, SUCCESS
  final TextEditingController _amountController = TextEditingController();

  void _processNFC() {
    setState(() => _mode = "NFC");
    Future.delayed(const Duration(seconds: 3), () {
      setState(() => _mode = "SUCCESS");
      appState.addTransaction(Transaction(
        id: "tx_${DateTime.now().millisecondsSinceEpoch}",
        type: TransactionType.payment,
        amount: double.tryParse(_amountController.text) ?? 0,
        description: "Contactless Payment",
        timestamp: DateTime.now(),
        isCredit: false,
      ));
      Future.delayed(const Duration(seconds: 2), () => Navigator.pop(context));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == "NFC") {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(width: 200, height: 200, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue)),
                  Icon(Icons.contactless, size: 80, color: Color(0xFF0F172A)),
                ],
              ),
              const SizedBox(height: 48),
              const Text("Ready to Tap", style: TextStyle(fontSize: 24, fontWeight: FontWeight.black)),
              const Text("Hold your phone near the terminal", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 64),
              Text("₦${_amountController.text}", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.black)),
            ],
          ),
        ),
      );
    }

    if (_mode == "SUCCESS") {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(radius: 50, backgroundColor: Colors.green, child: Icon(Icons.check, size: 60, color: Colors.white)),
              const SizedBox(height: 32),
              const Text("Payment Successful", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.black)),
              Text("₦${_amountController.text}", style: const TextStyle(color: Colors.white70, fontSize: 32)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Make Payment", style: TextStyle(fontWeight: FontWeight.bold)), leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            const Text("ENTER AMOUNT", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.black, letterSpacing: 2)),
            TextField(
              controller: _amountController,
              autofocus: true,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.black),
              decoration: const InputDecoration(border: InputBorder.none, hintText: "0.00", hintStyle: TextStyle(color: Colors.black12)),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _processNFC,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(30)),
                      child: const Column(
                        children: [Icon(Icons.smartphone, color: Colors.white, size: 32), SizedBox(height: 12), Text("NFC Tap", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.grey.shade200)),
                      child: const Column(
                        children: [Icon(Icons.qr_code, color: Colors.black, size: 32), SizedBox(height: 12), Text("Scan QR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Placeholder Screens ---

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text("History Screen")));
}

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text("Wallet Screen")));
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    appState.addListener(_update);
  }

  @override
  void dispose() {
    appState.removeListener(_update);
    super.dispose();
  }

  void _update() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(child: CircleAvatar(radius: 50, backgroundColor: Color(0xFF0F172A), child: Icon(Icons.person, size: 50, color: Colors.white))),
          const SizedBox(height: 16),
          const Center(child: Text("TAPPAY User", style: TextStyle(fontSize: 22, fontWeight: FontWeight.black))),
          const SizedBox(height: 48),
          ListTile(
            title: const Text("Merchant Mode"),
            subtitle: const Text("Switch to Soft POS terminal"),
            leading: const Icon(Icons.store),
            trailing: Switch(
              value: appState.activeRole == UserRole.merchant,
              onChanged: (val) => appState.toggleRole(),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text("Security Center"),
            leading: const Icon(Icons.shield_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            title: const Text("Logout"),
            leading: const Icon(Icons.logout, color: Colors.red),
            onTap: () => appState.logout(),
          ),
        ],
      ),
    );
  }
}
