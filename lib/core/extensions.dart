import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// DateTime extensions
// ---------------------------------------------------------------------------

extension DateTimeDisplay on DateTime {
  /// Returns a formatted date string, e.g. 'Jun 13, 2026'.
  String toDisplayDate() => DateFormat('MMM d, y').format(this);

  /// Returns a formatted date-time string, e.g. 'Jun 13, 2026  3:14 PM'.
  String toDisplayDateTime() => DateFormat('MMM d, y  h:mm a').format(this);

  /// Returns a compact date string suitable for table cells, e.g. '13/06/2026'.
  String toShortDate() => DateFormat('dd/MM/yyyy').format(this);

  /// True if this date falls before today (date-only comparison).
  bool get isOverdue {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final thisDate = DateTime(year, month, day);
    return thisDate.isBefore(todayDate);
  }
}

// ---------------------------------------------------------------------------
// double extensions
// ---------------------------------------------------------------------------

extension CurrencyFormat on double {
  /// Returns a USD-formatted currency string, e.g. '$1,200.00'.
  String toCurrency() => NumberFormat.currency(
        locale: 'en_US',
        symbol: '\$',
        decimalDigits: 2,
      ).format(this);
}

// ---------------------------------------------------------------------------
// String extensions
// ---------------------------------------------------------------------------

extension StringHelpers on String {
  /// Capitalizes the first letter of the string, leaving the rest unchanged.
  ///
  /// Example: `'active'.capitalize()` → `'Active'`
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }

  /// Converts a snake_case string to Title Case.
  ///
  /// Example: `'daily_rate'.toTitleCase()` → `'Daily Rate'`
  String toTitleCase() => split('_')
      .map((word) => word.isEmpty ? word : word.capitalize())
      .join(' ');

  /// Returns true if this string is a valid email address (basic check).
  bool get isValidEmail {
    return RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
        .hasMatch(this);
  }

  /// Returns null if the string is empty after trimming, otherwise returns
  /// the trimmed string. Useful for optional form fields.
  String? get nullIfEmpty {
    final trimmed = trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
