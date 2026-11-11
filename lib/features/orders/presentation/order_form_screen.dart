import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/money/document_totals.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/document_editor.dart';
import '../../business/providers/business_providers.dart';
import '../../customers/providers/customer_providers.dart';
import '../../products/providers/product_providers.dart';
import '../providers/order_providers.dart';

class OrderFormScreen extends ConsumerStatefulWidget {
  const OrderFormScreen({super.key, this.orderId});

  final String? orderId;

  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends ConsumerState<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _discountController = TextEditingController(text: '0');

  List<LineInput> _lines = const [
    LineInput(description: '', quantity: 1, unitPrice: Money.zero),
  ];

  String? _customerId;
  String? _assignedTo;
  DateTime? _dueDate;
  String _discountType = 'none';
  bool _isSaving = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final orderId = widget.orderId;
    if (orderId == null) return;

    setState(() => _loading = true);
    try {
      final detail = await ref.read(orderDetailProvider(orderId).future);
      if (!mounted) return;

      final order = detail.order;
      setState(() {
        _customerId = order.customerId;
        _assignedTo = order.assignedTo;
        _dueDate = order.dueDate;
        _notesController.text = order.notes ?? '';
        _discountType = order.discountType;
        _discountController.text = _trim(order.discountValue);
        _lines = detail.items.isEmpty
            ? _lines
            : [
                for (var index = 0; index < detail.items.length; index++)
                  LineInput(
                    productId: detail.items[index].productId,
                    description: detail.items[index].description,
                    quantity: detail.items[index].quantity,
                    unitPrice: detail.items[index].unitPrice,
                    estimatedUnitCost: detail.items[index].estimatedUnitCost,
                    position: index,
                  ),
              ];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      final message = error is AppException
          ? error.displayMessage
          : 'Could not load the order';
      showAppSnackBar(context, message, isError: true);
    }
  }

  String _trim(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }

  DocumentTotals get _totals => DocumentTotals.calculate(
    lines: _lines,
    discountType: _discountType,
    discountValue: _discountType == 'percent'
        ? double.tryParse(_discountController.text) ?? 0
        : (Money.tryParse(_discountController.text)?.cents ?? 0),
  );

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final businessId = ref.read(activeBusinessIdProvider);
    if (businessId == null) return;
    if (_customerId == null) {
      showAppSnackBar(context, 'Select a customer', isError: true);
      return;
    }
    if (_lines.every((line) => line.description.trim().isEmpty)) {
      showAppSnackBar(context, 'Add at least one line item', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(orderRepositoryProvider)
          .saveOrder(
            businessId: businessId,
            orderId: widget.orderId,
            customerId: _customerId!,
            dueDate: _dueDate,
            notes: _notesController.text.trim(),
            discountType: _discountType,
            discountValue: _discountType == 'percent'
                ? double.tryParse(_discountController.text) ?? 0
                : (Money.tryParse(_discountController.text)?.cents ?? 0),
            items: [
              for (var index = 0; index < _lines.length; index++)
                _lines[index].copyWith(position: index).toRpcPayload(),
            ],
            assignedTo: _assignedTo,
          );

      ref.invalidate(ordersProvider);
      if (widget.orderId != null) {
        ref.invalidate(orderDetailProvider(widget.orderId!));
      }

      if (!mounted) return;
      showAppSnackBar(context, 'Order saved');
      context.pop();
    } catch (error) {
      if (!mounted) return;
      final message = error is AppException
          ? error.displayMessage
          : 'Could not save the order';
      showAppSnackBar(context, message, isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider).value ?? const [];
    final products = ref.watch(productsProvider).value ?? const [];
    final members = ref.watch(businessMembersProvider).value ?? const [];

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.orderId == null ? 'New order' : 'Edit order'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _customerId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Customer'),
              items: [
                for (final customer in customers)
                  DropdownMenuItem(
                    value: customer.id,
                    child: Text(customer.name),
                  ),
              ],
              onChanged: (value) => setState(() => _customerId = value),
              validator: (value) => value == null ? 'Select a customer' : null,
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _assignedTo ?? '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Assigned to'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Nobody')),
                for (final member in members)
                  DropdownMenuItem(
                    value: member.userId,
                    child: Text(member.displayName),
                  ),
              ],
              onChanged: (value) => setState(
                () => _assignedTo = (value == null || value.isEmpty)
                    ? null
                    : value,
              ),
            ),
            const SizedBox(height: 6),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Due date'),
              subtitle: Text(
                _dueDate == null ? 'No due date' : AppDate.format(_dueDate),
              ),
              trailing: TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                    initialDate: _dueDate ?? DateTime.now(),
                  );
                  if (picked != null) setState(() => _dueDate = picked);
                },
                child: const Text('Pick'),
              ),
            ),
            const Divider(height: 24),
            const Text(
              'Items',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 10),
            LineEditor(
              lines: _lines,
              onChanged: (lines) => setState(() => _lines = lines),
              products: [
                for (final product in products)
                  (
                    id: product.id,
                    name: product.name,
                    price: product.basePrice,
                    productionCost: product.productionCost,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _discountType,
                    decoration: const InputDecoration(
                      labelText: 'Discount type',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('None')),
                      DropdownMenuItem(
                        value: 'percent',
                        child: Text('Percent'),
                      ),
                      DropdownMenuItem(value: 'amount', child: Text('Amount')),
                    ],
                    onChanged: (value) => setState(() {
                      _discountType = value ?? 'none';
                      _discountController.text = '0';
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppTextField(
                    label: _discountType == 'percent'
                        ? 'Discount (%)'
                        : 'Discount amount',
                    controller: _discountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Notes',
              controller: _notesController,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TotalsPanel(
              totals: _totals,
              discountType: _discountType,
              discountValue: _discountType == 'percent'
                  ? double.tryParse(_discountController.text) ?? 0
                  : (Money.tryParse(_discountController.text)?.cents ?? 0),
            ),
            const SizedBox(height: 18),
            AppButton(
              label: 'Save order',
              icon: Icons.save_outlined,
              isLoading: _isSaving,
              onPressed: _save,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
