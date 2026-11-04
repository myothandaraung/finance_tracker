/// A customer of the business.
class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.assignedTo,
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final String? assignedTo;
  final bool isActive;
  final DateTime? createdAt;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Customer',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      assignedTo: json['assigned_to'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: _date(json['created_at']),
    );
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
