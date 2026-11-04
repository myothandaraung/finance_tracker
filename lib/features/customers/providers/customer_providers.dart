import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../business/providers/business_providers.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.watch(supabaseClientProvider));
});

/// All customers of the active business.
final customersProvider = FutureProvider<List<Customer>>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  if (businessId == null) return const [];
  return ref.watch(customerRepositoryProvider).listCustomers(businessId);
});

/// A single customer.
final customerProvider = FutureProvider.family<Customer?, String>((ref, id) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  if (businessId == null) return null;
  return ref.watch(customerRepositoryProvider).findCustomer(businessId, id);
});
