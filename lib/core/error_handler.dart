import 'mcp_client.dart';

/// Converts app exceptions into human-readable messages for UI display.
String handleAppError(Object e) {
  if (e is McpApiException) {
    return humanizeError(e.message);
  }

  if (e is Exception) {
    final msg = e.toString();
    if (msg.startsWith('Exception: ')) {
      return humanizeError(msg.substring('Exception: '.length));
    }
    return humanizeError(msg);
  }

  final msg = e.toString();
  if (msg.contains('SocketException') || msg.contains('Connection refused')) {
    return 'Network error — please check your internet connection.';
  }
  if (msg.contains('TimeoutException')) {
    return 'Request timed out — please try again.';
  }

  return humanizeError(msg);
}

/// Maps MCP stable error codes to user-facing strings (flutter_erpnextmcp.md).
String humanizeError(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('session expired')) {
    return 'Your session has expired — please sign in again.';
  }
  if (lower.contains('invalid login') ||
      lower.contains('incorrect') && lower.contains('password')) {
    return 'Incorrect username or password. Please try again.';
  }
  if (lower.contains('serial') && lower.contains('rent')) {
    return message;
  }
  if (lower.contains('insufficient stock') || lower.contains('insufficient qty')) {
    return message;
  }
  if (lower.contains('network') || lower.contains('connection refused')) {
    return 'Network error — please check your connection.';
  }
  return message.isNotEmpty ? message : 'Something went wrong — please try again.';
}
