import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../business/providers/business_providers.dart';
import '../providers/expense_providers.dart';

/// Records an operating expense.
class ExpenseSheet extends ConsumerStatefulWidget {
  const ExpenseSheet({super.key});

  @override
  ConsumerState<ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends ConsumerState<ExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _referenceController = TextEditingController();

  String? _categoryId;
  String _method = 'cash';
  DateTime _expenseDate = DateTime.now();
  bool _isSaving = false;

  static const _methods = [
    ('cash', 'Cash'),
    ('bank', 'Bank transfer'),
    ('gcash', 'GCash'),
    ('card', 'Card'),
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final businessId = ref.read(activeBusinessIdProvider);
    if (businessId == null) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(expenseRepositoryProvider)
          .recordExpense(
            businessId: businessId,
            amount: Money.tryParse(_amountController.text) ?? Money.zero,
            description: _descriptionController.text.trim(),
            categoryId: _categoryId,
            expenseDate: _expenseDate,
            method: _method,
            reference: _referenceController.text.trim(),
          );
      if (!mounted) return;
      showAppSnackBar(context, 'Expense recorded');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final message = error is AppException
          ? error.displayMessage
          : 'Could not record the expense';
      showAppSnackBar(context, message, isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(expenseCategoriesProvider).value ?? const [];
    final role = ref.watch(currentRoleProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Record expense',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              AmountField(
                label: 'Amount',
                controller: _amountController,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Description',
                controller: _descriptionController,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final category in categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: const InputDecoration(labelText: 'Method'),
                items: [
                  for (final method in _methods)
                    DropdownMenuItem(value: method.$1, child: Text(method.$2)),
                ],
                onChanged: (value) => setState(() => _method = value ?? 'cash'),
              ),
              const SizedBox(height: 6),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Date'),
                subtitle: Text(AppDate.format(_expenseDate)),
                trailing: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 730),
                      ),
                      lastDate: DateTime.now(),
                      initialDate: _expenseDate,
                    );
                    if (picked != null) setState(() => _expenseDate = picked);
                  },
                  child: const Text('Change'),
                ),
              ),
              const SizedBox(height: 6),
              AppTextField(
                label: 'Reference',
                controller: _referenceController,
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Save expense',
                icon: Icons.check,
                isLoading: _isSaving,
                onPressed: role.canManageFinance ? _save : null,
              ),
              if (!role.canManageFinance) ...[
                const SizedBox(height: 8),
                const Text(
                  'Only an owner or an accountant can record expenses.',
                  style: TextStyle(color: AppColors.danger, fontSize: 12.5),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
