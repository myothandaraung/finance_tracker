import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/domain/member_role.dart';
import '../../../core/money/currency.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/business_repository.dart'
    show BusinessRepository;
import '../domain/business_membership.dart';

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return BusinessRepository(ref.watch(supabaseClientProvider));
});

/// Every business the signed in user is an active member of.
class MembershipsNotifier extends AsyncNotifier<List<BusinessMembership>> {
  @override
  Future<List<BusinessMembership>> build() async {
    final session = ref.watch(authStateProvider).value?.session;
    if (session == null) return const [];
    final repository = ref.watch(businessRepositoryProvider);
    final rows = await repository.callRpcList('rpc_my_memberships');
    return rows.map(BusinessMembership.fromJson).toList(growable: false);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

final membershipsProvider =
    AsyncNotifierProvider<MembershipsNotifier, List<BusinessMembership>>(
      MembershipsNotifier.new,
    );

/// The business the app is currently working in.
class ActiveBusinessNotifier extends Notifier<String?> {
  static const _preferenceKey = 'active_business_id';

  @override
  String? build() => null;

  /// Reads the persisted selection. Called once during start up.
  Future<void> restore() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_preferenceKey);
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> select(String businessId) async {
    state = businessId;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, businessId);
  }
}

final activeBusinessIdProvider =
    NotifierProvider<ActiveBusinessNotifier, String?>(
      ActiveBusinessNotifier.new,
    );

/// Membership of the active business, `null` while it is still loading.
final activeMembershipProvider = Provider<BusinessMembership?>((ref) {
  final businessId = ref.watch(activeBusinessIdProvider);
  final memberships = ref.watch(membershipsProvider).value;
  if (businessId == null || memberships == null) return null;

  for (final membership in memberships) {
    if (membership.businessId == businessId) return membership;
  }
  return null;
});

/// Role of the signed in user in the active business.
final currentRoleProvider = Provider<MemberRole>((ref) {
  return ref.watch(activeMembershipProvider)?.role ?? MemberRole.staff;
});

/// Team members of the active business.
final businessMembersProvider = FutureProvider<List<BusinessMember>>((
  ref,
) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  if (businessId == null) return const [];

  final repository = ref.watch(businessRepositoryProvider);
  final rows = await repository.callRpcList(
    'rpc_business_members',
    params: {'p_business_id': businessId},
  );
  return rows.map(BusinessMember.fromJson).toList(growable: false);
});

/// Currency symbol of the active business (e.g., 'Ks', '₱', '\$', '€').
final activeCurrencySymbolProvider = Provider<String>((ref) {
  final membership = ref.watch(activeMembershipProvider);
  return currencySymbol(membership?.currencyCode);
});
