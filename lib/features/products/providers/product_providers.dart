import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../business/providers/business_providers.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(supabaseClientProvider));
});

final productsProvider = FutureProvider<List<Product>>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  if (businessId == null) return const [];
  return ref.watch(productRepositoryProvider).listProducts(businessId);
});
