import '../models/equipment.dart';

class EquipmentSerial {
  final String id;
  final String name;
  final String? warehouse;
  final String? status;

  const EquipmentSerial({
    required this.id, required this.name,
    this.warehouse,
    this.status,
  });

  factory EquipmentSerial.fromJson(Map<String, dynamic> json) {
    return EquipmentSerial(
      id: json['id'] as String,
      name: json['asset_id'] as String,
      warehouse: null,
      status: json['status'] as String?,
    );
  }
}

class EquipmentDetail {
  final Equipment equipment;
  final List<EquipmentSerial> serials;
  final double qtyOnHand;
  final String rentalWarehouse;

  const EquipmentDetail({
    required this.equipment,
    required this.serials,
    required this.qtyOnHand,
    required this.rentalWarehouse,
  });
}
