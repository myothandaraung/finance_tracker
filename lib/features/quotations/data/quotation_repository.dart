import '../../../core/data/supabase_repository.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/quotation.dart';

class QuotationRepository extends SupabaseRepository {
  const QuotationRepository(super.client);

  Future<List<Map<String, dynamic>>> listQuotationRows(
    String businessId, {
    String? status,
  }) async {
    try {
      var query = client
          .from('quotations')
          .select()
          .eq('business_id', businessId);
      if (status != null) query = query.eq('status', status);
      return await query.order('created_at', ascending: false);
    } catch (error) {
      throw AppException.fromSupabase(error);
    }
  }

  Future<List<QuotationItem>> listItems(String quotationId) async {
    final rows = await selectRows(
      'quotation_items',
      filters: {'quotation_id': quotationId},
      orderBy: 'position',
      ascending: true,
    );
    return rows.map(QuotationItem.fromJson).toList(growable: false);
  }

  Future<Map<String, dynamic>> saveQuotation({
    required String businessId,
    String? quotationId,
    required String customerId,
    DateTime? validUntil,
    String? notes,
    required String discountType,
    required num discountValue,
    required List<Map<String, dynamic>> items,
    String? assignedTo,
  }) async {
    return callRpc(
      'rpc_save_quotation',
      params: {
        'p_business_id': businessId,
        'p_quotation_id': quotationId,
        'p_customer_id': customerId,
        'p_valid_until': validUntil?.toIso8601String().split('T').first,
        'p_notes': notes,
        'p_discount_type': discountType,
        'p_discount_value': discountValue,
        'p_items': items,
        'p_assigned_to': assignedTo,
      },
    );
  }

  Future<Map<String, dynamic>> setStatus({
    required String quotationId,
    required String status,
  }) async {
    return callRpc(
      'rpc_set_quotation_status',
      params: {'p_quotation_id': quotationId, 'p_status': status},
    );
  }
}
