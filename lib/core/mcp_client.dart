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

  String get _baseUrl => '$mcpBaseUrl/api/$mcpApiVersion';

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final envelope = await _request(
      method: 'POST',
      path: '/auth/login',
      body: {'username': username, 'password': password},
      authenticated: false,
    );
    final token = envelope['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw McpApiException('VALIDATION_ERROR', 'Login did not return a token.');
    }
    await _storage.write(key: _tokenKey, value: token);
    return envelope;
  }

  Future<void> logout() async {
    try {
      await _request(method: 'POST', path: '/auth/logout');
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
        humanizeError('Invalid MCP response (${response.statusCode})'),
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
