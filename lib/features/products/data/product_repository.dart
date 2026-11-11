import '../../../core/data/supabase_repository.dart';
import '../../../core/money/money.dart';
import '../domain/product.dart';

class ProductRepository extends SupabaseRepository {
  const ProductRepository(super.client);

  Future<List<Product>> listProducts(String businessId) async {
    final rows = await selectRows(
      'products',
      filters: {'business_id': businessId},
      orderBy: 'name',
      ascending: true,
    );
    return rows.map(Product.fromJson).toList(growable: false);
  }

  Future<Product> saveProduct({
    required String businessId,
    String? productId,
    required String name,
    String? description,
    required Money basePrice,
    String? unit,
    String? imagePath,
    bool isActive = true,
    Money productionCost = Money.zero,
    String? note,
  }) async {
    final result = await callRpc(
      'rpc_save_product',
      params: {
        'p_business_id': businessId,
        'p_product_id': productId,
        'p_name': name,
        'p_description': description,
        'p_base_price_cents': basePrice.cents,
        'p_unit': unit,
        'p_image_path': imagePath,
        'p_is_active': isActive,
        'p_production_cost_cents': productionCost.cents,
        'p_note': note,
      },
    );
    return Product.fromJson(result);
  }
}
