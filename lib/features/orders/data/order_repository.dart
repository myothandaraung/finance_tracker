import '../../../core/data/supabase_repository.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/order.dart';

class OrderRepository extends SupabaseRepository {
  const OrderRepository(super.client);

  /// Orders of a business, optionally filtered.
  Future<List<Map<String, dynamic>>> listOrderRows(
    String businessId, {
    String? status,
    DateTime? from,
    DateTime? to,
    String? customerId,
    String? assignedTo,
  }) async {
    try {
      var query = client.from('orders').select().eq('business_id', businessId);

      if (status != null) query = query.eq('status', status);
      if (customerId != null) query = query.eq('customer_id', customerId);
      if (assignedTo != null) query = query.eq('assigned_to', assignedTo);
      if (from != null) query = query.gte('created_at', from.toIso8601String());
      if (to != null) query = query.lte('created_at', to.toIso8601String());

      return await query.order('created_at', ascending: false);
    } catch (error) {
      throw AppException.fromSupabase(error);
    }
  }

  /// Header, items, money, costs and history in one round trip.
  Future<OrderDetail> orderDetail(String orderId) async {
    final result = await callRpc(
      'rpc_order_financials',
      params: {'p_order_id': orderId},
    );
    return OrderDetail.fromJson(result);
  }

  Future<Map<String, dynamic>> saveOrder({
    required String businessId,
    String? orderId,
    required String customerId,
    DateTime? dueDate,
    String? notes,
    required String discountType,
    required num discountValue,
    required List<Map<String, dynamic>> items,
    String? assignedTo,
  }) async {
    return callRpc(
      'rpc_save_order',
      params: {
        'p_business_id': businessId,
        'p_order_id': orderId,
        'p_customer_id': customerId,
        'p_due_date': dueDate?.toIso8601String().split('T').first,
        'p_notes': notes,
        'p_discount_type': discountType,
        'p_discount_value': discountValue,
        'p_items': items,
        'p_assigned_to': assignedTo,
      },
    );
  }

  Future<Map<String, dynamic>> updateStatus({
    required String orderId,
    required String toStatus,
    String? note,
  }) async {
    return callRpc(
      'rpc_update_order_status',
      params: {
        'p_order_id': orderId,
        'p_to_status': toStatus,
        'p_note': note,
      },
    );
  }

  Future<Map<String, dynamic>> convertQuotation({
    required String quotationId,
    DateTime? dueDate,
  }) async {
    return callRpc(
      'rpc_convert_quotation_to_order',
      params: {
        'p_quotation_id': quotationId,
        'p_due_date': dueDate?.toIso8601String().split('T').first,
      },
    );
  }

  Future<Map<String, dynamic>> assignOrder({
    required String orderId,
    String? userId,
  }) async {
    return callRpc(
      'rpc_assign_order',
      params: {
        'p_order_id': orderId,
        'p_user_id': userId,
      },
    );
  }

  Future<Map<String, dynamic>> addCost({
    required String orderId,
    required String costType,
    required String description,
    required double quantity,
    required int unitCostCents,
    String? materialId,
    DateTime? costDate,
  }) async {
    return callRpc(
      'rpc_add_order_cost',
      params: {
        'p_order_id': orderId,
        'p_cost_type': costType,
        'p_description': description,
        'p_quantity': quantity,
        'p_unit_cost_cents': unitCostCents,
        'p_material_id': materialId,
        'p_cost_date': costDate?.toIso8601String().split('T').first,
      },
    );
  }

  Future<void> deleteCost(String costId) async {
    await callRpc(
      'rpc_delete_order_cost',
      params: {'p_cost_id': costId},
    );
  }
}
