/// Draft line for the rental form (maps to MCP rental `items` array).
class RentalLineInput {
  final String lineType;
  final String itemCode;
  final String itemName;
  final String? serialNo;
  final String? assetId;
  final double qty;
  final double dailyRate;

  const RentalLineInput({
    required this.lineType,
    required this.itemCode,
    required this.itemName,
    this.serialNo,
    this.assetId,
    required this.qty,
    required this.dailyRate,
  });

  Map<String, dynamic> toMcpJson() {
    return {
      'product_id': itemCode,
      'quantity': qty.toInt(),
    };
  }
}
