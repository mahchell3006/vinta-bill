/// A reusable bulk-unit definition for a product.
/// Example: product "Oeuf" has a preset { name: "Plateau", conversionFactor: 30 }
/// meaning 1 Plateau = 30 eggs.
class BulkPreset {
  final int? id;
  final int productId;
  final String name;
  final int conversionFactor;

  const BulkPreset({
    this.id,
    required this.productId,
    required this.name,
    required this.conversionFactor,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'name': name,
      'conversion_factor': conversionFactor,
    };
  }

  factory BulkPreset.fromMap(Map<String, dynamic> map) {
    return BulkPreset(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      name: map['name'] as String? ?? '',
      conversionFactor: map['conversion_factor'] as int? ?? 1,
    );
  }

  BulkPreset copyWith({
    int? id,
    int? productId,
    String? name,
    int? conversionFactor,
  }) {
    return BulkPreset(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      conversionFactor: conversionFactor ?? this.conversionFactor,
    );
  }
}
