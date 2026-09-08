class Product {
  final int? id;
  final String name;
  final String description;
  final double price;
  final int stock;
  final int? categoryId;
  final String barcode;
  final double tvaRate;

  const Product({
    this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.stock = 0,
    this.categoryId,
    this.barcode = '',
    this.tvaRate = 0.0,
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
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
