import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';
import 'error_handler.dart';

const _accessTokenKey = 'mcp_access_token';
const _refreshTokenKey = 'mcp_refresh_token';
const _expiresAtKey = 'mcp_access_token_expires_at';
const _refreshWindow = Duration(minutes: 1);
const _requestTimeout = Duration(seconds: 15);

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
  String? _memoryRefreshToken;
  DateTime? _memoryTokenExpiry;
  Future<String?>? _refreshInFlight;

  String get _baseUrl => '$mcpBaseUrl/api/$mcpApiVersion';

  Future<String?> getToken() async {
    if (_memoryToken == null) {
      try {
        _memoryToken = await _storage.read(key: _accessTokenKey);
        _memoryRefreshToken = await _storage.read(key: _refreshTokenKey);
        final expiry = await _storage.read(key: _expiresAtKey);
        _memoryTokenExpiry = expiry == null ? null : DateTime.tryParse(expiry);
        _memoryTokenExpiry ??= _jwtExpiry(_memoryToken);
      } catch (_) {
        // Ignore secure storage read errors; the caller will handle no session.
      }
    }

    if (_memoryToken == null || _memoryToken!.isEmpty) return null;
    final expiry = _memoryTokenExpiry;
    final now = DateTime.now();
    if (expiry != null && !expiry.isAfter(now)) {
      return _refreshSession();
    }
    if (expiry != null && !expiry.isAfter(now.add(_refreshWindow))) {
      try {
        return await _refreshSession();
      } on McpApiException {
        // The current access token is still valid. Keep the warehouse signed in
        // during a temporary network failure and retry refresh on the next call.
        return _memoryToken;
      }
    }

    return _memoryToken;
  }

  DateTime? _jwtExpiry(String? token) {
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
              utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
          as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearToken() async {
    _memoryToken = null;
    _memoryRefreshToken = null;
    _memoryTokenExpiry = null;
    try {
      await Future.wait([
        _storage.delete(key: _accessTokenKey),
        _storage.delete(key: _refreshTokenKey),
        _storage.delete(key: _expiresAtKey),
      ]);
    } catch (_) {}
  }

  Future<void> _saveSession(Map<String, dynamic> envelope) async {
    final accessToken = envelope['access_token'] as String?;
    final refreshToken =
        envelope['refresh_token'] as String? ?? _memoryRefreshToken;
    final expiresIn = envelope['expires_in'];
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      throw McpApiException(
          'SESSION_EXPIRED', 'Session expired — please log in again.');
    }
    final expiry = expiresIn is num
        ? DateTime.now().add(Duration(seconds: expiresIn.toInt()))
        : _jwtExpiry(accessToken);
    _memoryToken = accessToken;
    _memoryRefreshToken = refreshToken;
    _memoryTokenExpiry = expiry;
    try {
      await Future.wait([
        _storage.write(key: _accessTokenKey, value: accessToken),
        _storage.write(key: _refreshTokenKey, value: refreshToken),
        if (expiry != null)
          _storage.write(key: _expiresAtKey, value: expiry.toIso8601String()),
      ]);
    } catch (_) {
      // The in-memory session remains valid for this app run.
    }
  }

  Future<String?> _refreshSession() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final refresh = _refreshSessionImpl();
    _refreshInFlight = refresh;
    return refresh.whenComplete(() => _refreshInFlight = null);
  }

  Future<String?> _refreshSessionImpl() async {
    final refreshToken = _memoryRefreshToken;
    if (refreshToken == null ||
        refreshToken.isEmpty ||
        supabaseUrl.isEmpty ||
        supabasePublishableKey.isEmpty) {
      await clearToken();
      return null;
    }
    try {
      final response = await _http
          .post(
            Uri.parse('$supabaseUrl/auth/v1/token?grant_type=refresh_token'),
            headers: {
              'apikey': supabasePublishableKey,
              'Content-Type': 'application/json'
            },
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 400 || response.statusCode == 401) {
          await clearToken();
          return null;
        }
        throw McpApiException('ERPNEXT_UNAVAILABLE',
            'Unable to refresh your session. Check your connection and try again.');
      }
      await _saveSession(jsonDecode(response.body) as Map<String, dynamic>);
      return _memoryToken;
    } on McpApiException {
      await clearToken();
      return null;
    } on FormatException {
      await clearToken();
      return null;
    } on TimeoutException {
      throw McpApiException('NETWORK_TIMEOUT',
          'The server is taking too long to respond. Please try again.');
    } on http.ClientException {
      throw McpApiException('ERPNEXT_UNAVAILABLE',
          'Unable to refresh your session. Check your connection and try again.');
    }
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      throw McpApiException('VALIDATION_ERROR', 'Supabase is not configured.');
    }
    final response = await _http
        .post(
          Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password'),
          headers: {
            'apikey': supabasePublishableKey,
            'Content-Type': 'application/json'
          },
          body: jsonEncode({'email': username, 'password': password}),
        )
        .timeout(_requestTimeout);
    final envelope = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorMessage = envelope['msg'] ??
          envelope['error_description'] ??
          envelope['message'] ??
          'Sign-in failed.';
      throw McpApiException('UNAUTHORIZED', errorMessage as String);
    }
    await _saveSession(envelope);
    final user = envelope['user'] as Map<String, dynamic>? ?? {};
    return {
      'user': {
        'id': user['id'],
        'email': user['email'],
        'name': user['email'],
        'roles': const <String>[]
      }
    };
  }

  Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null && supabaseUrl.isNotEmpty) {
        await _http.post(Uri.parse('$supabaseUrl/auth/v1/logout'), headers: {
          'apikey': supabasePublishableKey,
          'Authorization': 'Bearer $token'
        }).timeout(const Duration(seconds: 30));
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
    Map<String, String>? headers,
  }) =>
      _request(method: 'POST', path: path, body: body, extraHeaders: headers);

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
    Map<String, String>? extraHeaders,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    for (var attempt = 0; attempt < 2; attempt++) {
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (authenticated) {
        final token = await getToken();
        if (token == null || token.isEmpty) {
          throw McpApiException(
              'SESSION_EXPIRED', 'Session expired — please log in again.');
        }
        headers['Authorization'] = 'Bearer $token';
      }
      if (apiKey != null && apiKey.isNotEmpty) headers['X-Api-Key'] = apiKey;
      if (extraHeaders != null) headers.addAll(extraHeaders);

      late http.Response response;
      try {
        response = await (() async {
          final streamed = await _http.send(
            http.Request(method, uri)
              ..headers.addAll(headers)
              ..body = body == null ? '' : jsonEncode(body),
          );
          return http.Response.fromStream(streamed);
        })()
            .timeout(_requestTimeout);
      } on TimeoutException {
        throw McpApiException('NETWORK_TIMEOUT',
            'The server is taking too long to respond. Please try again.');
      } on http.ClientException {
        throw McpApiException('NETWORK_UNAVAILABLE',
            'Cannot reach the server. Check your connection and try again.');
      }
      final text = response.body;
      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {
        throw McpApiException(
            'ERPNEXT_UNAVAILABLE',
            humanizeError(
                'Invalid MCP response (${response.statusCode}) from $uri\nBody: ${text.length > 100 ? text.substring(0, 100) : text}'));
      }

      if (payload['ok'] == true) {
        return payload['data'] as Map<String, dynamic>? ?? {};
      }
      final error = payload['error'] as Map<String, dynamic>?;
      final code = error?['code'] as String? ?? 'VALIDATION_ERROR';
      final message = error?['message'] as String? ?? 'Request failed.';
      if (authenticated &&
          code == 'SESSION_EXPIRED' &&
          attempt == 0 &&
          await _refreshSession() != null) {
        continue;
      }
      if (code == 'SESSION_EXPIRED') await clearToken();
      throw McpApiException(code, humanizeError(message));
    }
    throw McpApiException(
        'SESSION_EXPIRED', 'Session expired — please log in again.');
  }
}

final mcpClient = McpClient();
