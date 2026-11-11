import '../../../core/money/money.dart';

/// A product or service in the catalog.
class Product {
  const Product({
    required this.id,
    required this.name,
    this.description,
    required this.basePrice,
    this.unit,
    this.imagePath,
    this.isActive = true,
    this.productionCost = Money.zero,
  });

  final String id;
  final String name;
  final String? description;
  final Money basePrice;
  final String? unit;
  final String? imagePath;
  final bool isActive;
  final Money productionCost;

  /// Margin of one unit: (base price - production cost) / base price.
  double get marginPercent {
    if (basePrice.cents == 0) return 0;
    return (basePrice - productionCost).cents / basePrice.cents * 100;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Product',
      description: json['description'] as String?,
      basePrice: Money(json['base_price_cents'] as int? ?? 0),
      unit: json['unit'] as String?,
      imagePath: json['image_path'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      productionCost: Money(json['production_cost_cents'] as int? ?? 0),
    );
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    Money? basePrice,
    String? unit,
    String? imagePath,
    bool? isActive,
    Money? productionCost,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      basePrice: basePrice ?? this.basePrice,
      unit: unit ?? this.unit,
      imagePath: imagePath ?? this.imagePath,
      isActive: isActive ?? this.isActive,
      productionCost: productionCost ?? this.productionCost,
    );
  }
}
