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
  });

  final String id;
  final String name;
  final String? description;
  final Money basePrice;
  final String? unit;
  final String? imagePath;
  final bool isActive;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Product',
      description: json['description'] as String?,
      basePrice: Money(json['base_price_cents'] as int? ?? 0),
      unit: json['unit'] as String?,
      imagePath: json['image_path'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }
}
