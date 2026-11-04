/// Membership role inside a business.
///
/// The role is stored as text in `business_members.role` and is enforced by
/// Row Level Security in the database. The helpers below mirror those rules
/// so the UI can hide actions the database would reject anyway.
enum MemberRole {
  owner,
  staff,
  accountant;

  static MemberRole fromDb(String? value) {
    return MemberRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => MemberRole.staff,
    );
  }

  String get label => switch (this) {
        MemberRole.owner => 'Owner',
        MemberRole.staff => 'Staff',
        MemberRole.accountant => 'Accountant',
      };

  String get description => switch (this) {
        MemberRole.owner =>
          'Full access: records, finances, settings and team members.',
        MemberRole.staff =>
          'Customers, quotations, orders and production costs. Cannot record '
              'payments or expenses.',
        MemberRole.accountant =>
          'Records payments, refunds and expenses and reviews reports. '
              'Read-only on quotations and orders.',
      };

  /// Customers, products, materials, quotations, orders, production costs.
  bool get canManageOperations =>
      this == MemberRole.owner || this == MemberRole.staff;

  /// Payments, refunds, expenses.
  bool get canManageFinance =>
      this == MemberRole.owner || this == MemberRole.accountant;

  bool get canCancelOrders => this == MemberRole.owner;

  bool get canDeleteRecords => this == MemberRole.owner;

  bool get canManageSettings => this == MemberRole.owner;

  bool get canManageMembers => this == MemberRole.owner;

  bool get canAssignWork =>
      this == MemberRole.owner || this == MemberRole.staff;
}
