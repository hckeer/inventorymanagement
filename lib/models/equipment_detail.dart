import '../models/equipment.dart';

class EquipmentSerial {
  final String name;
  final String? warehouse;
  final String? status;

  const EquipmentSerial({
    required this.name,
    this.warehouse,
    this.status,
  });

  factory EquipmentSerial.fromJson(Map<String, dynamic> json) {
    return EquipmentSerial(
      name: json['name'] as String,
      warehouse: json['warehouse'] as String?,
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
