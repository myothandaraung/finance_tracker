import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../business/providers/business_providers.dart';
import '../data/material_repository.dart';
import '../domain/material.dart';

final materialRepositoryProvider = Provider<MaterialRepository>((ref) {
  return MaterialRepository(ref.watch(supabaseClientProvider));
});

final materialsProvider = FutureProvider<List<Material>>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  if (businessId == null) return const [];
  return ref.watch(materialRepositoryProvider).listMaterials(businessId);
});
