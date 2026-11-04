import '../../../core/data/supabase_repository.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/money/money.dart';

/// An operating expense.
class Expense {
  const Expense({
    required this.id,
    required this.amount,
    this.description,
    this.categoryId,
    this.categoryName,
    this.orderId,
    required this.expenseDate,
    required this.method,
  });

  final String id;
  final Money amount;
  final String? description;
  final String? categoryId;
  final String? categoryName;
  final String? orderId;
  final DateTime? expenseDate;
  final String method;

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      amount: Money(json['amount_cents'] as int? ?? 0),
      description: json['description'] as String?,
      categoryId: json['category_id'] as String?,
      categoryName: json['category_name'] as String?,
      orderId: json['order_id'] as String?,
      expenseDate: DateTime.tryParse('${json['expense_date']}'),
      method: (json['method'] as String?) ?? 'cash',
    );
  }
}

/// A category used to group expenses.
class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.type,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String type;
  final bool isActive;

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Category',
      type: (json['type'] as String?) ?? 'operating',
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }
}

/// A payment method offered to the finance team.
class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.name,
    this.isActive = true,
  });

  final String id;
  final String name;
  final bool isActive;

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }
}

class ExpenseRepository extends SupabaseRepository {
  const ExpenseRepository(super.client);

  Future<List<Map<String, dynamic>>> listExpenseRows(
    String businessId, {
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      var query = client.from('expenses').select().eq('business_id', businessId);
      if (from != null) query = query.gte('expense_date', _date(from));
      if (to != null) query = query.lte('expense_date', _date(to));
      return await query.order('expense_date', ascending: false);
    } catch (error) {
      throw AppException.fromSupabase(error);
    }
  }

  Future<List<ExpenseCategory>> listCategories(String businessId) async {
    final rows = await selectRows(
      'expense_categories',
      filters: {'business_id': businessId},
      orderBy: 'name',
      ascending: true,
    );
    return rows.map(ExpenseCategory.fromJson).toList(growable: false);
  }

  Future<ExpenseCategory> saveCategory({
    required String businessId,
    String? categoryId,
    required String name,
    required String type,
    bool isActive = true,
  }) async {
    final result = await callRpc(
      'rpc_save_expense_category',
      params: {
        'p_business_id': businessId,
        'p_category_id': categoryId,
        'p_name': name,
        'p_type': type,
        'p_is_active': isActive,
      },
    );
    return ExpenseCategory.fromJson(result);
  }

  Future<List<PaymentMethod>> listPaymentMethods(String businessId) async {
    final rows = await selectRows(
      'payment_methods',
      filters: {'business_id': businessId},
      orderBy: 'name',
      ascending: true,
    );
    return rows.map(PaymentMethod.fromJson).toList(growable: false);
  }

  Future<PaymentMethod> savePaymentMethod({
    required String businessId,
    String? methodId,
    required String name,
    bool isActive = true,
  }) async {
    final result = await callRpc(
      'rpc_save_payment_method',
      params: {
        'p_business_id': businessId,
        'p_method_id': methodId,
        'p_name': name,
        'p_is_active': isActive,
      },
    );
    return PaymentMethod.fromJson(result);
  }

  Future<Map<String, dynamic>> recordExpense({
    required String businessId,
    required Money amount,
    String? description,
    String? categoryId,
    DateTime? expenseDate,
    String method = 'cash',
    String? reference,
    String? receiptPath,
    String? orderId,
  }) async {
    return callRpc(
      'rpc_record_expense',
      params: {
        'p_business_id': businessId,
        'p_amount_cents': amount.cents,
        'p_description': description,
        'p_category_id': categoryId,
        'p_expense_date': _date(expenseDate ?? DateTime.now()),
        'p_method': method,
        'p_reference': reference,
        'p_receipt_path': receiptPath,
        'p_order_id': orderId,
      },
    );
  }

  Future<void> deleteExpense(String expenseId) async {
    await callRpc(
      'rpc_delete_expense',
      params: {'p_expense_id': expenseId},
    );
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
