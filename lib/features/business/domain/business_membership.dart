import '../../../core/domain/member_role.dart';

/// A business the signed in user belongs to.
class BusinessMembership {
  const BusinessMembership({
    required this.businessId,
    required this.name,
    required this.currencyCode,
    required this.role,
  });

  final String businessId;
  final String name;
  final String currencyCode;
  final MemberRole role;

  factory BusinessMembership.fromJson(Map<String, dynamic> json) {
    return BusinessMembership(
      businessId: json['business_id'] as String,
      name: (json['name'] as String?) ?? 'Business',
      currencyCode: (json['currency_code'] as String?) ?? 'MMK',
      role: MemberRole.fromDb(json['role'] as String?),
    );
  }
}

/// A team member of the active business.
class BusinessMember {
  const BusinessMember({
    required this.id,
    required this.userId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.status,
  });

  final String id;
  final String? userId;
  final String email;
  final String displayName;
  final MemberRole role;
  final String status;

  bool get isActive => status == 'active';

  factory BusinessMember.fromJson(Map<String, dynamic> json) {
    return BusinessMember(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      email: (json['email'] as String?) ?? '',
      displayName:
          (json['display_name'] as String?) ?? (json['email'] as String? ?? ''),
      role: MemberRole.fromDb(json['role'] as String?),
      status: (json['status'] as String?) ?? 'invited',
    );
  }
}
