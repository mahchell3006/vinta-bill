class Product {
  final int? id;
  final String name;
  final String description;
  final double price;
  final int stock;
  final int? categoryId;
  final String barcode;
  final double tvaRate;
  final bool isBulkConvertible;
  final String wholesaleUnitName;
  final int conversionFactor;
  final double wholesaleCostPrice;
  final double costPrice;
  final int packs;

  const Product({
    this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.stock = 0,
    this.categoryId,
    this.barcode = '',
    this.tvaRate = 0.0,
    this.isBulkConvertible = false,
    this.wholesaleUnitName = '',
    this.conversionFactor = 1,
    this.wholesaleCostPrice = 0.0,
    this.costPrice = 0.0,
    this.packs = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'stock': stock,
      'categoryId': categoryId,
      'barcode': barcode,
      'tvaRate': tvaRate,
      'is_bulk_convertible': isBulkConvertible ? 1 : 0,
      'wholesale_unit_name': wholesaleUnitName,
      'conversion_factor': conversionFactor,
      'wholesale_cost_price': wholesaleCostPrice,
      'cost_price': costPrice,
      'packs': packs,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      price: (map['price'] as num).toDouble(),
      stock: map['stock'] as int? ?? 0,
      categoryId: map['categoryId'] as int?,
      barcode: map['barcode'] as String? ?? '',
      tvaRate: (map['tvaRate'] as num?)?.toDouble() ?? 0.0,
      isBulkConvertible: (map['is_bulk_convertible'] as int? ?? 0) == 1,
      wholesaleUnitName: map['wholesale_unit_name'] as String? ?? '',
      conversionFactor: map['conversion_factor'] as int? ?? 1,
      wholesaleCostPrice: (map['wholesale_cost_price'] as num?)?.toDouble() ?? 0.0,
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
      packs: map['packs'] as int? ?? 0,
    );
  }

  Product copyWith({
    int? id,
    String? name,
    String? description,
    double? price,
    int? stock,
    int? categoryId,
    String? barcode,
    double? tvaRate,
    bool? isBulkConvertible,
    String? wholesaleUnitName,
    int? conversionFactor,
    double? wholesaleCostPrice,
    double? costPrice,
    int? packs,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      categoryId: categoryId ?? this.categoryId,
      barcode: barcode ?? this.barcode,
      tvaRate: tvaRate ?? this.tvaRate,
      isBulkConvertible: isBulkConvertible ?? this.isBulkConvertible,
      wholesaleUnitName: wholesaleUnitName ?? this.wholesaleUnitName,
      conversionFactor: conversionFactor ?? this.conversionFactor,
      wholesaleCostPrice: wholesaleCostPrice ?? this.wholesaleCostPrice,
      costPrice: costPrice ?? this.costPrice,
      packs: packs ?? this.packs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
