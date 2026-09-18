class Purchase {
  final int? id;
  final int productId;
  final int quantityWholesaleUnits;
  final int quantityRetailUnits;
  final double totalCost;
  final double unitCost;
  final String wholesaleUnitName;
  final DateTime createdAt;

  const Purchase({
    this.id,
    required this.productId,
    required this.quantityWholesaleUnits,
    required this.quantityRetailUnits,
    required this.totalCost,
    required this.unitCost,
    this.wholesaleUnitName = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'quantity_wholesale_units': quantityWholesaleUnits,
      'quantity_retail_units': quantityRetailUnits,
      'total_cost': totalCost,
      'unit_cost': unitCost,
      'wholesale_unit_name': wholesaleUnitName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Purchase.fromMap(Map<String, dynamic> map) {
    return Purchase(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      quantityWholesaleUnits: map['quantity_wholesale_units'] as int,
      quantityRetailUnits: map['quantity_retail_units'] as int,
      totalCost: (map['total_cost'] as num).toDouble(),
      unitCost: (map['unit_cost'] as num).toDouble(),
      wholesaleUnitName: map['wholesale_unit_name'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
