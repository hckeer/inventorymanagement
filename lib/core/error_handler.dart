import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts Supabase / PostgREST exceptions into human-readable messages.
///
/// Usage:
/// ```dart
/// try {
///   await supabase.from('equipment').insert(data);
/// } catch (e) {
///   final msg = handleSupabaseError(e);
///   showSnackBar(msg);
/// }
/// ```
String handleSupabaseError(Object e) {
  if (e is PostgrestException) {
    return _handlePostgrestException(e);
  }

  if (e is AuthException) {
    return _handleAuthException(e);
  }

  // Generic network or unknown error
  final msg = e.toString();
  if (msg.contains('SocketException') || msg.contains('Connection refused')) {
    return 'Network error — please check your internet connection.';
  }
  if (msg.contains('TimeoutException')) {
    return 'Request timed out — please try again.';
  }

  return msg;
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

String _handlePostgrestException(PostgrestException e) {
  final code = e.code ?? '';
  final message = e.message.toLowerCase();

  switch (code) {
    // Unique violation
    case '23505':
      if (message.contains('serial_no')) {
        return 'A piece of equipment with that serial number already exists.';
      }
      if (message.contains('email')) {
        return 'A client with that email address already exists.';
      }
      if (message.contains('phone')) {
        return 'A client with that phone number already exists.';
      }
      return 'A record with those details already exists. '
          'Please check for duplicates.';

    // Foreign-key violation
    case '23503':
      if (message.contains('category_id')) {
        return 'The selected category no longer exists. '
            'Please refresh and try again.';
      }
      if (message.contains('equipment_id')) {
        return 'One or more selected items no longer exist. '
            'Please refresh and try again.';
      }
      if (message.contains('client_id')) {
        return 'The selected client no longer exists. '
            'Please refresh and try again.';
      }
      return 'A related record is missing — please refresh and try again.';

    // Not-null violation
    case '23502':
      return 'A required field is missing. Please fill in all required fields.';

    // Check constraint violation
    case '23514':
      if (message.contains('status')) {
        return 'Invalid status value. Please select a valid status.';
      }
      if (message.contains('daily_rate')) {
        return 'Daily rate must be a positive value.';
      }
      if (message.contains('deposit_amount')) {
        return 'Deposit amount must be zero or greater.';
      }
      return 'A value constraint was violated — please review your inputs.';

    // Row-level security violation (PostgREST surfaces this as 42501)
    case '42501':
      return 'You do not have permission to perform this action.';

    // Undefined table / column (development guard)
    case '42P01':
      return 'Database configuration error — please contact support.';
    case '42703':
      return 'Database configuration error — please contact support.';

    default:
      // Equipment availability — returned as a custom error from a DB trigger
      if (message.contains('equipment') && message.contains('unavailabl')) {
        return 'One or more items are not available for the selected dates.';
      }
      if (message.contains('not available')) {
        return 'One or more items are not available for the selected dates.';
      }

      // PGRST (PostgREST) range / request errors
      if (code.startsWith('PGRST')) {
        return 'API error (${e.code}): ${e.message}';
      }

      return e.message.isNotEmpty ? e.message : e.toString();
  }
}

String _handleAuthException(AuthException e) {
  final message = e.message.toLowerCase();

  if (message.contains('invalid login credentials') ||
      message.contains('invalid email or password')) {
    return 'Incorrect email or password. Please try again.';
  }
  if (message.contains('email not confirmed')) {
    return 'Please verify your email address before signing in.';
  }
  if (message.contains('user already registered')) {
    return 'An account with this email already exists.';
  }
  if (message.contains('password should be at least')) {
    return 'Password is too short — please use at least 6 characters.';
  }
  if (message.contains('token') && message.contains('expired')) {
    return 'Your session has expired — please sign in again.';
  }
  if (message.contains('jwt expired') || message.contains('token expired')) {
    return 'Your session has expired — please sign in again.';
  }
  if (message.contains('rate limit') || message.contains('too many requests')) {
    return 'Too many attempts. Please wait a moment and try again.';
  }

  return e.message.isNotEmpty ? e.message : e.toString();
}
