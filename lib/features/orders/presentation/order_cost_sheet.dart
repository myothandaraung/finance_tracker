import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../materials/providers/material_providers.dart';
import '../../orders/providers/order_providers.dart';

/// Adds a production cost (material, labour, overhead) to an order.
class OrderCostSheet extends ConsumerStatefulWidget {
  const OrderCostSheet({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderCostSheet> createState() => _OrderCostSheetState();
}

class _OrderCostSheetState extends ConsumerState<OrderCostSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitCostController = TextEditingController();

  String _costType = 'material';
  String? _materialId;
  DateTime _costDate = DateTime.now();
  bool _isSaving = false;

  static const _types = [
    ('material', 'Material'),
    ('labor', 'Labour'),
    ('overhead', 'Overhead'),
    ('other', 'Other'),
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _unitCostController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final unitCost = Money.tryParse(_unitCostController.text) ?? Money.zero;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(orderRepositoryProvider)
          .addCost(
            orderId: widget.orderId,
            costType: _costType,
            description: _descriptionController.text.trim(),
            quantity: quantity,
            unitCostCents: unitCost.cents,
            materialId: _materialId,
            costDate: _costDate,
          );
      if (!mounted) return;
      showAppSnackBar(context, 'Cost added');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final message = error is AppException
          ? error.displayMessage
          : 'Could not add the cost';
      showAppSnackBar(context, message, isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final materials = ref.watch(materialsProvider).value ?? const [];

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
                'Add production cost',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _costType,
                decoration: const InputDecoration(labelText: 'Cost type'),
                items: [
                  for (final type in _types)
                    DropdownMenuItem(value: type.$1, child: Text(type.$2)),
                ],
                onChanged: (value) => setState(() {
                  _costType = value ?? 'other';
                  if (_costType != 'material') _materialId = null;
                }),
              ),
              if (_costType == 'material' && materials.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _materialId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Material'),
                  items: [
                    for (final material in materials)
                      DropdownMenuItem(
                        value: material.id,
                        child: Text(material.name),
                      ),
                  ],
                  onChanged: (value) {
                    final matches = materials.where((item) => item.id == value);
                    final material = matches.isEmpty ? null : matches.first;
                    setState(() {
                      _materialId = value;
                      if (material != null) {
                        _descriptionController.text = material.name;
                        _unitCostController.text =
                            material.defaultUnitCost.plain;
                      }
                    });
                  },
                ),
              ],
              const SizedBox(height: 12),
              AppTextField(
                label: 'Description',
                controller: _descriptionController,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Describe the cost'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: QuantityField(
                      label: 'Quantity',
                      controller: _quantityController,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AmountField(
                      label: 'Unit cost',
                      controller: _unitCostController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Cost date'),
                subtitle: Text(AppDate.format(_costDate)),
                trailing: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now(),
                      initialDate: _costDate,
                    );
                    if (picked != null) setState(() => _costDate = picked);
                  },
                  child: const Text('Change'),
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Save cost',
                icon: Icons.check,
                isLoading: _isSaving,
                onPressed: _save,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
