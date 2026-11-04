import '../../../core/data/supabase_repository.dart';
import '../../../core/money/money.dart';
import '../domain/material.dart';

class MaterialRepository extends SupabaseRepository {
  const MaterialRepository(super.client);

  Future<List<Material>> listMaterials(String businessId) async {
    final rows = await selectRows(
      'materials',
      filters: {'business_id': businessId},
      orderBy: 'name',
      ascending: true,
    );
    return rows.map(Material.fromJson).toList(growable: false);
  }

  Future<Material> saveMaterial({
    required String businessId,
    String? materialId,
    required String name,
    String? unit,
    required Money defaultUnitCost,
    bool isActive = true,
  }) async {
    final result = await callRpc(
      'rpc_save_material',
      params: {
        'p_business_id': businessId,
        'p_material_id': materialId,
        'p_name': name,
        'p_unit': unit,
        'p_default_unit_cost_cents': defaultUnitCost.cents,
        'p_is_active': isActive,
      },
    );
    return Material.fromJson(result);
  }
}
