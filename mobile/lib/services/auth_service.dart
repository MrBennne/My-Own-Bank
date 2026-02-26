import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const String _kBaseUrl = 'http://locserv.tail18bcbb.ts.net:8091';
const String _kIdentity = 'banking@mybank.local';
const String _kPassword = 'Banking#Q-CsEdIGYdvDxx0X';
const String _kTokenKey = 'pb_token';

class AuthService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Authenticate with PocketBase and persist the token.
  Future<String> login() async {
    final uri = Uri.parse(
      '$_kBaseUrl/api/collections/users/auth-with-password',
    );
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'identity': _kIdentity,
            'password': _kPassword,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['token'] as String;
      await _storage.write(key: _kTokenKey, value: token);
      return token;
    } else {
      throw Exception(
        'Login failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// Returns the stored token or null if not present.
  Future<String?> getToken() async {
    return _storage.read(key: _kTokenKey);
  }

  /// Validates the stored token by making a lightweight API request.
  Future<bool> hasValidToken() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;

    try {
      final uri = Uri.parse(
        '$_kBaseUrl/api/collections/transactions/records?perPage=1',
      );
      final response = await http
          .get(
            uri,
            headers: {'Authorization': token},
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: _kTokenKey);
  }
}
