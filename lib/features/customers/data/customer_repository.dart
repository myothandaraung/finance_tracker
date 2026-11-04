import '../../../core/data/supabase_repository.dart';
import '../domain/customer.dart';

class CustomerRepository extends SupabaseRepository {
  const CustomerRepository(super.client);

  Future<List<Customer>> listCustomers(String businessId) async {
    final rows = await selectRows(
      'customers',
      filters: {'business_id': businessId},
      orderBy: 'name',
      ascending: true,
    );
    return rows.map(Customer.fromJson).toList(growable: false);
  }

  Future<Customer?> findCustomer(String businessId, String customerId) async {
    final row = await selectRow(
      'customers',
      filters: {'id': customerId, 'business_id': businessId},
    );
    return row == null ? null : Customer.fromJson(row);
  }

  /// Creates or updates a customer and returns the stored row.
  Future<Customer> saveCustomer({
    required String businessId,
    String? customerId,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    String? assignedTo,
    bool isActive = true,
  }) async {
    final result = await callRpc(
      'rpc_save_customer',
      params: {
        'p_business_id': businessId,
        'p_customer_id': customerId,
        'p_name': name,
        'p_phone': phone,
        'p_email': email,
        'p_address': address,
        'p_notes': notes,
        'p_assigned_to': assignedTo,
        'p_is_active': isActive,
      },
    );
    return Customer.fromJson(result);
  }
}
