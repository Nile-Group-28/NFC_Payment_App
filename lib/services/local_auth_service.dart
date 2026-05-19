// lib/services/local_auth_service.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'api_service.dart';

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

class LocalAuthService {
  static Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'tappay_local.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute("""
          CREATE TABLE IF NOT EXISTS offline_registrations (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            name        TEXT NOT NULL,
            phone       TEXT,
            email       TEXT,
            pin_hash    TEXT NOT NULL,
            created_at  TEXT NOT NULL,
            synced      INTEGER NOT NULL DEFAULT 0
          )
        """);
      },
    );
    return _db!;
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  String _makeSalt(String identifier) {
    final bytes = utf8.encode('tappay_local_$identifier');
    return sha256.convert(bytes).toString().substring(0, 16);
  }

  Future<void> cacheCredentials({
    required String identifier,
    required String pin,
    required Map<String, dynamic> user,
  }) async {
    final salt    = _makeSalt(identifier);
    final pinHash = _hashPin(pin, salt);
    await _storage.write(key: 'local_pin_hash_$identifier', value: pinHash);
    await _storage.write(key: 'local_pin_salt_$identifier', value: salt);
    await _storage.write(key: 'cached_user_$identifier',    value: jsonEncode(user));
    await _storage.write(key: 'last_identifier',            value: identifier);
  }

  Future<Map<String, dynamic>?> verifyPinOffline({
    required String identifier,
    required String pin,
  }) async {
    final storedHash = await _storage.read(key: 'local_pin_hash_$identifier');
    final storedSalt = await _storage.read(key: 'local_pin_salt_$identifier');
    final cachedUser = await _storage.read(key: 'cached_user_$identifier');

    if (storedHash == null || storedSalt == null || cachedUser == null) return null;

    final computed = _hashPin(pin, storedSalt);
    if (computed != storedHash) return null;

    return jsonDecode(cachedUser) as Map<String, dynamic>;
  }

  Future<void> queueOfflineRegistration({
    required String name,
    String? phone,
    String? email,
    required String pin,
  }) async {
    final identifier = phone ?? email ?? name;
    final salt    = _makeSalt(identifier);
    final pinHash = _hashPin(pin, salt);

    final db = await _database;
    await db.insert('offline_registrations', {
      'name':       name,
      'phone':      phone,
      'email':      email,
      'pin_hash':   pinHash,
      'created_at': DateTime.now().toIso8601String(),
      'synced':     0,
    });

    await cacheCredentials(
      identifier: identifier,
      pin: pin,
      user: {
        'name':          name,
        'phone':         phone ?? '',
        'email':         email ?? '',
        'kycTier':       0,
        'kycStatus':     'UNVERIFIED',
        'balance':       0,
        'hasPassword':   false,
        'isOfflineOnly': true,
      },
    );
  }

  Future<SyncResult> syncPendingRegistrations() async {
    final db   = await _database;
    final rows = await db.query('offline_registrations', where: 'synced = 0');
    int synced = 0, failed = 0;
    for (final row in rows) {
      try {
        final data = await AuthApi.register(
          name:  row['name'] as String,
          phone: row['phone'] as String?,
          email: row['email'] as String?,
          pin:   '__offline__',
        );
        await db.update(
          'offline_registrations', {'synced': 1},
          where: 'id = ?', whereArgs: [row['id']],
        );
        final id = (row['phone'] ?? row['email'] ?? row['name']) as String;
        await _storage.write(key: 'cached_user_$id', value: jsonEncode(data['user']));
        synced++;
      } catch (_) {
        failed++;
      }
    }
    return SyncResult(synced: synced, failed: failed);
  }

  Future<void> clearSession() async {
    final identifier = await _storage.read(key: 'last_identifier');
    if (identifier != null) {
      await _storage.delete(key: 'local_pin_hash_$identifier');
      await _storage.delete(key: 'local_pin_salt_$identifier');
      await _storage.delete(key: 'cached_user_$identifier');
    }
    await _storage.delete(key: 'last_identifier');
  }
}

class SyncResult {
  final int synced;
  final int failed;
  const SyncResult({required this.synced, required this.failed});
}
