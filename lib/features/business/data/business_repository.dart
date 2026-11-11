import '../../../core/data/supabase_repository.dart';
import '../domain/business_membership.dart';

/// Business, team and settings operations.
class BusinessRepository extends SupabaseRepository {
  const BusinessRepository(super.client);

  /// Creates a business and makes the caller its owner.
  Future<BusinessMembership> createBusiness({
    required String name,
    String currencyCode = 'MMK',
  }) async {
    final result = await callRpc(
      'rpc_create_business',
      params: {'p_name': name, 'p_currency_code': currencyCode},
    );
    return BusinessMembership.fromJson({
      'business_id': result['business_id'],
      'name': result['name'],
      'currency_code': result['currency_code'],
      'role': 'owner',
    });
  }

  Future<void> updateBusiness({
    required String businessId,
    String? name,
    String? currencyCode,
  }) async {
    await callRpc(
      'rpc_update_business',
      params: {
        'p_business_id': businessId,
        'p_name': name,
        'p_currency_code': currencyCode,
      },
    );
  }

  /// Adds a team member by email. The membership is activated when that
  /// person signs up with the same address.
  Future<BusinessMember> inviteMember({
    required String businessId,
    required String email,
    required String role,
  }) async {
    final result = await callRpc(
      'rpc_invite_member',
      params: {'p_business_id': businessId, 'p_email': email, 'p_role': role},
    );
    return BusinessMember.fromJson(result);
  }

  Future<void> updateMemberRole({
    required String memberId,
    required String role,
  }) async {
    await callRpc(
      'rpc_update_member_role',
      params: {'p_member_id': memberId, 'p_role': role},
    );
  }

  Future<void> removeMember(String memberId) async {
    await callRpc('rpc_remove_member', params: {'p_member_id': memberId});
  }
}
