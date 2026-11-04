import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../business/providers/business_providers.dart';
import '../providers/expense_providers.dart';
import 'expense_sheet.dart';

/// The list of operating expenses of the business.
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider);
    final role = ref.watch(currentRoleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: role.canManageFinance
          ? FloatingActionButton(
              onPressed: () => _addExpense(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: expenses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(expensesProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              title: 'No expenses recorded',
              message: 'Operating expenses keep the profit figure honest.',
              icon: Icons.receipt_outlined,
              action: role.canManageFinance
                  ? FilledButton.icon(
                      onPressed: () => _addExpense(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Record expense'),
                    )
                  : null,
            );
          }

          final total = items.fold<int>(
            0,
            (sum, expense) => sum + expense.amount.cents,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              MetricCard(
                label: 'Total expenses',
                value: MoneyFormatter.format(Money(total)),
                icon: Icons.payments_outlined,
                color: AppColors.warning,
                hint: '${items.length} entries',
              ),
              const SizedBox(height: 12),
              for (final expense in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_outlined),
                      title: Text(
                        expense.description ?? 'Expense',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        [
                          if (expense.categoryName != null) expense.categoryName!,
                          AppDate.format(expense.expenseDate),
                          expense.method,
                        ].join(' · '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            MoneyFormatter.format(expense.amount),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (role.canDeleteRecords)
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: AppColors.danger,
                              onPressed: () => _delete(context, ref, expense.id),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addExpense(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => const ExpenseSheet(),
    );
    if (saved == true) ref.invalidate(expensesProvider);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String expenseId,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete expense',
      message: 'This expense is removed from the reports.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

    try {
      await ref.read(expenseRepositoryProvider).deleteExpense(expenseId);
      ref.invalidate(expensesProvider);
    } catch (error) {
      if (!context.mounted) return;
      showAppSnackBar(context, 'Could not delete the expense', isError: true);
    }
  }
}
