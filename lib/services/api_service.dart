// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';

class ApiConfig {
  // Precedence (highest → lowest):
  //   1. --dart-define=API_BASE_URL=https://xxxx.ngrok-free.app/api
  //      Start backend: npm run dev:ngrok  (prints the URL)
  //      Run app:       flutter run --dart-define=API_BASE_URL=<url>
  //   2. Real-device local fallback → update the IP below if needed
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://172.20.10.2:3000/api',
  );
}

class Session {
  static String? _token;
  static Map<String, dynamic>? _user;
  static void save(String token, Map<String, dynamic> user) {
    _token = token;
    _user = user;
  }

  static void clear() {
    _token = null;
    _user = null;
  }

  static String? get token => _token;
  static Map<String, dynamic>? get user => _user;
  static bool get isLoggedIn => _token != null;
}

Map<String, String> _headers({bool auth = true}) => {
      'Content-Type': 'application/json',
      if (auth && Session.token != null)
        'Authorization': 'Bearer ${Session.token}',
    };

Future<Map<String, dynamic>> _get(String path) async {
  final res = await http.get(Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers());
  return _parse(res);
}

Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body,
    {bool auth = true}) async {
  final res = await http.post(Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers(auth: auth), body: jsonEncode(body));
  return _parse(res);
}

Future<Map<String, dynamic>> _put(
    String path, Map<String, dynamic> body) async {
  final res = await http.put(Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers(), body: jsonEncode(body));
  return _parse(res);
}

Map<String, dynamic> _parse(http.Response res) {
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode >= 400)
    throw ApiException(data['message'] ?? 'Request failed',
        statusCode: res.statusCode);
  return data;
}

Future<String> getDeviceId() async {
  final info = DeviceInfoPlugin();
  try {
    if (Platform.isAndroid) return (await info.androidInfo).id;
    if (Platform.isIOS)
      return (await info.iosInfo).identifierForVendor ?? 'ios-unknown';
  } catch (_) {}
  return 'unknown-device';
}

// ─── Auth API ─────────────────────────────────────────────────────────────────
class AuthApi {
  static Future<Map<String, dynamic>> register({
    required String name,
    String? email,
    String? phone,
    required String pin,
    String? password,
  }) async {
    final deviceId = await getDeviceId();
    final data = await _post(
        '/auth/register',
        {
          'name': name,
          'pin': pin,
          'deviceId': deviceId,
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
          if (password != null) 'password': password,
        },
        auth: false);
    Session.save(data['token'], data['user']);
    return data;
  }

  static Future<Map<String, dynamic>> login({
    required String identifier,
    String? pin,
    String? password,
  }) async {
    final deviceId = await getDeviceId();
    final data = await _post(
        '/auth/login',
        {
          'identifier': identifier,
          'deviceId': deviceId,
          if (pin != null) 'pin': pin,
          if (password != null) 'password': password,
        },
        auth: false);
    Session.save(data['token'], data['user']);
    return data;
  }

  static Future<Map<String, dynamic>> me() => _get('/auth/me');

  static Future<Map<String, dynamic>> changePin(
          {required String currentPin, required String newPin}) =>
      _post('/auth/change-pin', {'currentPin': currentPin, 'newPin': newPin});

  static Future<Map<String, dynamic>> setPassword(
          {required String password, required String currentPin}) =>
      _post('/auth/set-password',
          {'password': password, 'currentPin': currentPin});

  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? dateOfBirth,
  }) =>
      _put('/auth/profile', {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (address != null) 'address': address,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
      });

  static void logout() => Session.clear();
}

// ─── KYC API ──────────────────────────────────────────────────────────────────
class KycApi {
  static Future<Map<String, dynamic>> submitTier1(
          {String? bvn, String? nin, String? dateOfBirth}) =>
      _post('/kyc/tier1', {
        if (bvn != null) 'bvn': bvn,
        if (nin != null) 'nin': nin,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
      });

  static Future<Map<String, dynamic>> submitTier2({
    required String bvn,
    required String nin,
    required String documentType,
  }) =>
      _post(
          '/kyc/tier2', {'bvn': bvn, 'nin': nin, 'documentType': documentType});

  static Future<Map<String, dynamic>> submitTier3(
          {required String documentType}) =>
      _post('/kyc/tier3', {'documentType': documentType});

  static Future<Map<String, dynamic>> getStatus() => _get('/kyc/status');
}

// ─── Wallet API ───────────────────────────────────────────────────────────────
class WalletApi {
  static Future<Map<String, dynamic>> getWallet() => _get('/wallet');

  static Future<Map<String, dynamic>> getTransactions(
      {String? type, int limit = 30, int offset = 0}) {
    final q = [if (type != null) 'type=$type', 'limit=$limit', 'offset=$offset']
        .join('&');
    return _get('/wallet/transactions?$q');
  }

  static Future<Map<String, dynamic>> initializeTopUp(double amount) =>
      _post('/wallet/topup/initialize', {'amount': amount});

  static Future<Map<String, dynamic>> verifyTopUp(String reference) =>
      _post('/wallet/topup/verify', {'reference': reference});

  static Future<Map<String, dynamic>> transfer({
    required String recipientIdentifier,
    required double amount,
    String? description,
  }) =>
      _post('/wallet/transfer', {
        'recipientIdentifier': recipientIdentifier,
        'amount': amount,
        if (description != null) 'description': description,
      });

  static Future<Map<String, dynamic>> nfcSettle({
    required String senderId,
    required double amount,
    String? tokenId,
  }) =>
      _post('/wallet/nfc-settle', {
        'senderId': senderId,
        'amount': amount,
        if (tokenId != null) 'tokenId': tokenId,
      });

  static Future<Map<String, dynamic>> withdraw(
          {required double amount, required String bankAccountId}) =>
      _post('/wallet/withdraw',
          {'amount': amount, 'bankAccountId': bankAccountId});

  static Future<Map<String, dynamic>> linkBankAccount({
    required String bankName,
    required String accountNumber,
    required String bankCode,
    String? accountName,
  }) =>
      _post('/wallet/bank-account', {
        'bankName': bankName,
        'accountNumber': accountNumber,
        'bankCode': bankCode,
        if (accountName != null) 'accountName': accountName,
      });
}

// ─── Exception ────────────────────────────────────────────────────────────────
class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, {this.statusCode = 500});
  @override
  String toString() => 'ApiException($statusCode): $message';
}
