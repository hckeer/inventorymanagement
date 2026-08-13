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

  test('retains mixed serialized asset availability counts', () {
    final equipment = Equipment.fromProduct({
      'id': 'product-2',
      'name': 'Wind-Up Stand',
      'tracking_mode': 'serialized',
      'daily_rate': 0,
      'is_active': true,
      'stock_balances': const {},
      'assets': const [
        {'status': 'available'},
        {'status': 'available'},
        {'status': 'rented'},
        {'status': 'maintenance'},
      ],
      'created_at': '2026-08-10T00:00:00Z',
      'updated_at': '2026-08-10T00:00:00Z',
    });

    expect(equipment.status, 'available');
    expect(equipment.availableAssetCount, 2);
    expect(equipment.rentedAssetCount, 1);
    expect(equipment.maintenanceAssetCount, 1);
  });
}
