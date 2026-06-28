/// Draft line for the rental form (maps to MCP rental `items` array).
class RentalLineInput {
  final String lineType;
  final String itemCode;
  final String itemName;
  final String? serialNo;
  final double qty;
  final double dailyRate;

  const RentalLineInput({
    required this.lineType,
    required this.itemCode,
    required this.itemName,
    this.serialNo,
    required this.qty,
    required this.dailyRate,
  });

  Map<String, dynamic> toMcpJson() {
    return {
      'line_type': lineType,
      'item_code': itemCode,
      if (serialNo != null) 'serial_no': serialNo,
      'qty': qty,
      'daily_rate_snapshot': dailyRate,
    };
  }
}
