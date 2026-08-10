import 'package:flutter_test/flutter_test.dart';
import 'package:inventorymanagement/models/equipment.dart';

void main() {
  test('parses a one-to-one stock balance returned as an object', () {
    final equipment = Equipment.fromProduct({
      'id': 'product-1',
      'name': 'XLR Cable',
      'tracking_mode': 'quantity',
      'daily_rate': 0,
      'is_active': true,
      'stock_balances': {
        'on_hand_quantity': 10,
        'reserved_quantity': 2,
        'rented_quantity': 3,
      },
      'assets': const [],
      'created_at': '2026-08-10T00:00:00Z',
      'updated_at': '2026-08-10T00:00:00Z',
    });

    expect(equipment.status, 'available');
  });
}
