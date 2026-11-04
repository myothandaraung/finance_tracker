import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../business/providers/business_providers.dart';
import '../data/expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(supabaseClientProvider));
});

/// Expenses of the active business, newest first.
final expensesProvider = FutureProvider<List<Expense>>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  if (businessId == null) return const [];

  final repository = ref.watch(expenseRepositoryProvider);
  final rows = await repository.listExpenseRows(businessId);
  final categories = await repository.listCategories(businessId);
  final names = {for (final category in categories) category.id: category.name};

  return rows
      .map(
        (row) => Expense.fromJson({
          ...row,
          'category_name': names[row['category_id']],
        }),
      )
      .toList(growable: false);
});

final expenseCategoriesProvider =
    FutureProvider<List<ExpenseCategory>>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  if (businessId == null) return const [];
  return ref.watch(expenseRepositoryProvider).listCategories(businessId);
});

final paymentMethodsProvider = FutureProvider<List<PaymentMethod>>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  if (businessId == null) return const [];
  return ref.watch(expenseRepositoryProvider).listPaymentMethods(businessId);
});
