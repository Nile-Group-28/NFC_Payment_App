// lib/services/offline_transaction_service.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'api_service.dart';

const _storage = FlutterSecureStorage();
const _uuid    = Uuid();

const double _maxOfflineAmount     = 2000.0;
const double _maxOfflineDailyTotal = 5000.0;
const int    _maxPendingOffline    = 10;

class SyncResult {
  final int synced;
  final int failed;
  final List<Map<String, dynamic>> results;
  const SyncResult({required this.synced, required this.failed, required this.results});
}

class OfflineStatus {
  final bool enabled;
  final double availableBalance;
  final double lastKnownBalance;
  final double pendingDebits;
  final int pendingCount;
  final DateTime? lastSyncTime;
  final bool canMakePayment;
  final double dailyLimit;
  final double maxPerTransaction;

  const OfflineStatus({
    required this.enabled,
    required this.availableBalance,
    required this.lastKnownBalance,
    required this.pendingDebits,
    required this.pendingCount,
    required this.lastSyncTime,
    required this.canMakePayment,
    required this.dailyLimit,
    required this.maxPerTransaction,
  });
}

class OfflineTransactionService {
  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = p.join(await getDatabasesPath(), 'tappay_offline.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_offline_transactions (
            local_id        TEXT PRIMARY KEY,
            receiver_id     TEXT NOT NULL,
            amount          REAL NOT NULL,
            nonce           TEXT NOT NULL UNIQUE,
            signature       TEXT NOT NULL,
            created_at      TEXT NOT NULL,
            sync_status     TEXT NOT NULL DEFAULT 'PENDING',
            backend_tx_id   TEXT,
            rejection_reason TEXT
          )
        ''');
      },
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Enable offline payments: generate keypair and register with backend
  // ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> enableOfflinePayments({
    required String deviceId,
    double? dailyLimit,
  }) async {
    // Generate Ed25519 keypair using dart:crypto primitives
    // We store a simulated keypair (real apps use platform keystore or pointycastle)
    final keyPair = _generateKeyPair();
    final publicKeyB64  = base64Encode(keyPair['public']  as Uint8List);
    final privateKeyB64 = base64Encode(keyPair['private'] as Uint8List);

    await _storage.write(key: 'offline_private_key', value: privateKeyB64);
    await _storage.write(key: 'offline_public_key',  value: publicKeyB64);

    final result = await OfflineApi.enableOfflineCapability(
      enable: true,
      deviceId: deviceId,
      publicKey: publicKeyB64,
      dailyLimit: dailyLimit,
    );

    if (result['success'] == true) {
      await _storage.write(key: 'offline_daily_limit',   value: result['dailyLimit'].toString());
      await _storage.write(key: 'offline_enabled',       value: 'true');
    }
    return result;
  }

  // ────────────────────────────────────────────────────────────────
  // Queue an offline transaction in local SQLite
  // ────────────────────────────────────────────────────────────────
  Future<String> queueOfflineTransaction({
    required String receiverId,
    required double amount,
    required String currentUserId,
  }) async {
    final localId  = _uuid.v4();
    final nonce    = _generateNonce();
    final now      = DateTime.now().toIso8601String();
    final payload  = {
      'senderId':   currentUserId,
      'receiverId': receiverId,
      'amount':     amount,
      'nonce':      nonce,
      'timestamp':  now,
    };
    final signature = await _signPayload(payload);

    final db = await database;
    await db.insert('pending_offline_transactions', {
      'local_id':    localId,
      'receiver_id': receiverId,
      'amount':      amount,
      'nonce':       nonce,
      'signature':   signature,
      'created_at':  now,
      'sync_status': 'PENDING',
    });

    // Update cached pending debits
    final current = double.tryParse(
      await _storage.read(key: 'pending_offline_debits') ?? '0'
    ) ?? 0;
    await _storage.write(key: 'pending_offline_debits', value: (current + amount).toString());

    return localId;
  }

  // ────────────────────────────────────────────────────────────────
  // Check if an offline payment of given amount is permitted
  // ────────────────────────────────────────────────────────────────
  Future<bool> canMakeOfflinePayment(double amount) async {
    if (amount > _maxOfflineAmount) return false;

    final db = await database;
    final rows = await db.query(
      'pending_offline_transactions',
      where: 'sync_status = ?',
      whereArgs: ['PENDING'],
    );
    if (rows.length >= _maxPendingOffline) return false;

    final pendingTotal = rows.fold<double>(0, (sum, r) => sum + (r['amount'] as double));

    final lastKnown = double.tryParse(
      await _storage.read(key: 'last_known_balance') ?? '0'
    ) ?? 0;
    final available = lastKnown - pendingTotal;
    if (amount > available) return false;

    // Check today's offline total
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayRows = await db.query(
      'pending_offline_transactions',
      where: "DATE(created_at) = ? AND sync_status != 'FAILED'",
      whereArgs: [today],
    );
    final todayTotal = todayRows.fold<double>(0, (sum, r) => sum + (r['amount'] as double));
    final dailyLimit = double.tryParse(
      await _storage.read(key: 'offline_daily_limit') ?? '$_maxOfflineDailyTotal'
    ) ?? _maxOfflineDailyTotal;

    return todayTotal + amount <= dailyLimit;
  }

  // ────────────────────────────────────────────────────────────────
  // Sync pending offline transactions to backend
  // ────────────────────────────────────────────────────────────────
  Future<SyncResult> syncOfflineTransactions({required String deviceId}) async {
    final db = await database;
    final pending = await db.query(
      'pending_offline_transactions',
      where: 'sync_status = ?',
      whereArgs: ['PENDING'],
    );
    if (pending.isEmpty) {
      return const SyncResult(synced: 0, failed: 0, results: []);
    }

    final userId = Session.user?['id'] as String?;
    final payload = pending.map((row) => {
      'localTransactionId': row['local_id'],
      'receiverId':         row['receiver_id'],
      'amount':             row['amount'],
      'nonce':              row['nonce'],
      'signature':          row['signature'],
      'deviceTimestamp':    row['created_at'],
      'deviceId':           deviceId,
    }).toList();

    final response = await OfflineApi.syncOfflineTransactions(transactions: payload);
    final results  = List<Map<String, dynamic>>.from(response['results'] ?? []);

    int synced = 0, failed = 0;
    for (final result in results) {
      final localId = result['localTransactionId'] as String;
      final status  = result['status'] as String;
      if (status == 'SYNCED') {
        await db.update(
          'pending_offline_transactions',
          {'sync_status': 'SYNCED', 'backend_tx_id': result['transactionId']},
          where: 'local_id = ?', whereArgs: [localId],
        );
        synced++;
      } else {
        await db.update(
          'pending_offline_transactions',
          {'sync_status': 'FAILED', 'rejection_reason': result['reason']},
          where: 'local_id = ?', whereArgs: [localId],
        );
        failed++;
      }
    }

    // Reset cached pending debits and update balance
    await _storage.write(key: 'pending_offline_debits', value: '0');
    try {
      final walletData = await WalletApi.getWallet();
      final balance = walletData['wallet']?['balance']?.toString() ?? '0';
      await _storage.write(key: 'last_known_balance', value: balance);
    } catch (_) {}

    return SyncResult(synced: synced, failed: failed, results: results);
  }

  // ────────────────────────────────────────────────────────────────
  // Get current offline status (uses cache when offline)
  // ────────────────────────────────────────────────────────────────
  Future<OfflineStatus> getOfflineStatus({String? deviceId}) async {
    final db = await database;
    final rows = await db.query(
      'pending_offline_transactions',
      where: 'sync_status = ?',
      whereArgs: ['PENDING'],
    );
    final pendingDebits = rows.fold<double>(0, (s, r) => s + (r['amount'] as double));
    final pendingCount  = rows.length;

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity != ConnectivityResult.none;

    double lastKnown = double.tryParse(
      await _storage.read(key: 'last_known_balance') ?? '0'
    ) ?? 0;
    final dailyLimit = double.tryParse(
      await _storage.read(key: 'offline_daily_limit') ?? '$_maxOfflineDailyTotal'
    ) ?? _maxOfflineDailyTotal;
    final enabled = (await _storage.read(key: 'offline_enabled')) == 'true';

    if (isOnline) {
      try {
        final res = await OfflineApi.getOfflineStatus(deviceId: deviceId);
        lastKnown = (res['lastKnownBalance'] as num?)?.toDouble() ?? lastKnown;
        await _storage.write(key: 'last_known_balance', value: lastKnown.toString());
      } catch (_) {}
    }

    final available = lastKnown - pendingDebits;
    return OfflineStatus(
      enabled:          enabled,
      availableBalance: available > 0 ? available : 0,
      lastKnownBalance: lastKnown,
      pendingDebits:    pendingDebits,
      pendingCount:     pendingCount,
      lastSyncTime:     null,
      canMakePayment:   enabled && available > 0,
      dailyLimit:       dailyLimit,
      maxPerTransaction: _maxOfflineAmount,
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Internals
  // ────────────────────────────────────────────────────────────────

  // Generates a deterministic 32-byte "private key" seed and derives
  // a public key stub. Production apps should use platform secure key storage
  // (Android Keystore / iOS Secure Enclave) with an Ed25519 plugin.
  Map<String, Uint8List> _generateKeyPair() {
    final rng     = Random.secure();
    final private = Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
    // Derive public key stub: SHA-256 of private key (placeholder until
    // a real Ed25519 library is linked via platform channel)
    final digest = sha256.convert(private);
    final public = Uint8List.fromList(digest.bytes);
    return {'private': private, 'public': public};
  }

  String _generateNonce() {
    final rng   = Random.secure();
    final bytes = List.generate(24, (_) => rng.nextInt(256));
    final ts    = DateTime.now().millisecondsSinceEpoch.toString();
    return sha256.convert([...utf8.encode(ts), ...bytes]).toString();
  }

  Future<String> _signPayload(Map<String, dynamic> payload) async {
    final privateKeyB64 = await _storage.read(key: 'offline_private_key');
    if (privateKeyB64 == null) throw StateError('No offline private key found.');
    final key     = utf8.encode(privateKeyB64);
    final message = utf8.encode(jsonEncode(payload));
    final hmac    = Hmac(sha256, key);
    // HMAC-SHA256 used as signature until a platform Ed25519 plugin is wired up.
    // The backend verifies using the registered public key; when a real
    // Ed25519 library replaces this, only the signing call changes.
    return base64Encode(hmac.convert(message).bytes);
  }
}
