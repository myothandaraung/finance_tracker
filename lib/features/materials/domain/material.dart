import '../../../core/money/money.dart';

/// A material used in production.
class Material {
  const Material({
    required this.id,
    required this.name,
    this.unit,
    required this.defaultUnitCost,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? unit;
  final Money defaultUnitCost;
  final bool isActive;

  factory Material.fromJson(Map<String, dynamic> json) {
    return Material(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Material',
      unit: json['unit'] as String?,
      defaultUnitCost: Money(json['default_unit_cost_cents'] as int? ?? 0),
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }
}
