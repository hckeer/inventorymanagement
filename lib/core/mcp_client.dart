import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';
import 'error_handler.dart';

const _tokenKey = 'mcp_access_token';

class McpApiException implements Exception {
  McpApiException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class McpClient {
  McpClient({http.Client? httpClient, FlutterSecureStorage? storage})
      : _http = httpClient ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  final http.Client _http;
  final FlutterSecureStorage _storage;
  String? _memoryToken;

  String get _baseUrl => '$mcpBaseUrl/api/$mcpApiVersion';

  Future<String?> getToken() async {
    if (_memoryToken != null) return _memoryToken;
    try {
      _memoryToken = await _storage.read(key: _tokenKey);
    } catch (_) {
      // Ignore secure storage read errors
    }
    return _memoryToken;
  }

  Future<void> clearToken() async {
    _memoryToken = null;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      throw McpApiException('VALIDATION_ERROR', 'Supabase is not configured.');
    }
    final response = await _http.post(
      Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password'),
      headers: {'apikey': supabasePublishableKey, 'Content-Type': 'application/json'},
      body: jsonEncode({'email': username, 'password': password}),
    ).timeout(const Duration(seconds: 30));
    final envelope = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorMessage = envelope['msg'] ?? envelope['error_description'] ?? envelope['message'] ?? 'Sign-in failed.';
      throw McpApiException('UNAUTHORIZED', errorMessage as String);
    }
    final token = envelope['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw McpApiException('VALIDATION_ERROR', 'Login did not return a token.');
    }
    _memoryToken = token;
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {
      // Ignore write errors if storage is corrupted
    }
    final user = envelope['user'] as Map<String, dynamic>? ?? {};
    return {'user': {'id': user['id'], 'email': user['email'], 'name': user['email'], 'roles': const <String>[]}};
  }

  Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null && supabaseUrl.isNotEmpty) {
        await _http.post(Uri.parse('$supabaseUrl/auth/v1/logout'), headers: {'apikey': supabasePublishableKey, 'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 30));
      }
    } finally {
      await clearToken();
    }
  }

  Future<Map<String, dynamic>> me() async {
    return _request(method: 'GET', path: '/auth/me');
  }

  Future<Map<String, dynamic>> get(String path) =>
      _request(method: 'GET', path: path);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _request(method: 'POST', path: path, body: body);

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _request(method: 'PATCH', path: path, body: body);

  /// Warehouse routes use X-Api-Key (not JWT). See docs/api-v1.md.
  Future<Map<String, dynamic>> postWarehouse(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _request(
        method: 'POST',
        path: path,
        body: body,
        authenticated: false,
        apiKey: mcpApiKey.isNotEmpty ? mcpApiKey : null,
      );

  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$mcpBaseUrl/health');
      final response = await _http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    bool authenticated = true,
    String? apiKey,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (authenticated) {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw McpApiException(
          'SESSION_EXPIRED',
          'Session expired — please log in again.',
        );
      }
      headers['Authorization'] = 'Bearer $token';
    }

    if (apiKey != null && apiKey.isNotEmpty) {
      headers['X-Api-Key'] = apiKey;
    }

    final response = await _http
        .send(
          http.Request(method, uri)
            ..headers.addAll(headers)
            ..body = body == null ? '' : jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    final text = await response.stream.bytesToString();
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw McpApiException(
        'ERPNEXT_UNAVAILABLE',
        humanizeError('Invalid MCP response (${response.statusCode}) from $uri\nBody: ${text.length > 100 ? text.substring(0, 100) : text}'),
      );
    }

    final ok = payload['ok'] == true;
    if (!ok) {
      final error = payload['error'] as Map<String, dynamic>?;
      final code = error?['code'] as String? ?? 'VALIDATION_ERROR';
      final message = error?['message'] as String? ?? 'Request failed.';
      if (code == 'SESSION_EXPIRED') {
        await clearToken();
      }
      throw McpApiException(code, humanizeError(message));
    }

    return payload['data'] as Map<String, dynamic>? ?? {};
  }
}

final mcpClient = McpClient();
