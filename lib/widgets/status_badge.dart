import 'package:flutter/material.dart';
import '../core/constants.dart';

/// A compact coloured chip reflecting equipment or rental status.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final _Config cfg = _configFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        cfg.label,
        style: TextStyle(
          color: cfg.fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  static _Config _configFor(String status) {
    switch (status.toLowerCase()) {
      case kStatusAvailable:
      case kRentalStatusReturned:
        return _Config(
          label: _toLabel(status),
          bg: const Color(0xFF4CAF50).withValues(alpha: 0.18),
          fg: const Color(0xFF66BB6A),
        );
      case kStatusRented:
      case kRentalStatusActive:
        return _Config(
          label: _toLabel(status),
          bg: const Color(0xFFE8A838).withValues(alpha: 0.18),
          fg: const Color(0xFFE8A838),
        );
      case kStatusMaintenance:
      case kRentalStatusOverdue:
        return _Config(
          label: _toLabel(status),
          bg: const Color(0xFFFF9800).withValues(alpha: 0.16),
          fg: const Color(0xFFFF9800),
        );
      case kRentalStatusCancelled:
      case kStatusRetired:
      default:
        return _Config(
          label: _toLabel(status),
          bg: const Color(0xFF9999AA).withValues(alpha: 0.14),
          fg: const Color(0xFF9999AA),
        );
    }
  }

  static String _toLabel(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _Config {
  const _Config({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;
}
