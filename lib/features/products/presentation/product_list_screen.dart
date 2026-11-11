import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../business/providers/business_providers.dart';
import '../domain/product.dart';
import '../providers/product_providers.dart';

class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    final role = ref.watch(currentRoleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      floatingActionButton: role.canManageOperations
          ? FloatingActionButton(
              onPressed: () => _openForm(context, ref, null),
              child: const Icon(Icons.add),
            )
          : null,
      body: products.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(productsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              title: 'No products yet',
              message: 'Add the items you quote to reuse them in quotations.',
              icon: Icons.inventory_2_outlined,
              action: role.canManageOperations
                  ? FilledButton.icon(
                      onPressed: () => _openForm(context, ref, null),
                      icon: const Icon(Icons.add),
                      label: const Text('Add product'),
                    )
                  : null,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final product = items[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [
                      MoneyFormatter.format(product.basePrice),
                      if (product.unit != null) 'per ${product.unit}',
                      'cost ${MoneyFormatter.format(product.productionCost)}',
                      '${product.marginPercent.toStringAsFixed(0)}% margin',
                      if (!product.isActive) 'inactive',
                    ].join(' · '),
                  ),
                  trailing: role.canManageOperations
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openForm(context, ref, product),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref,
    Product? product,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ProductForm(product: product),
    );
    ref.invalidate(productsProvider);
  }
}

class _ProductForm extends ConsumerStatefulWidget {
  const _ProductForm({this.product});

  final Product? product;

  @override
  ConsumerState<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _unitController;
  late final TextEditingController _costController;

  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.product?.description ?? '',
    );
    _priceController = TextEditingController(
      text: widget.product?.basePrice.plain ?? '',
    );
    _unitController = TextEditingController(text: widget.product?.unit ?? '');
    _costController = TextEditingController(
      text: widget.product?.productionCost.plain ?? '',
    );
    _isActive = widget.product?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final businessId = ref.read(activeBusinessIdProvider);
    if (businessId == null) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(productRepositoryProvider)
          .saveProduct(
            businessId: businessId,
            productId: widget.product?.id,
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            basePrice: Money.tryParse(_priceController.text) ?? Money.zero,
            unit: _unitController.text.trim(),
            isActive: _isActive,
            productionCost: Money.tryParse(_costController.text) ?? Money.zero,
          );
      if (!mounted) return;
      showAppSnackBar(context, 'Product saved');
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      final message = error is AppException
          ? error.displayMessage
          : 'Could not save the product';
      showAppSnackBar(context, message, isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Text(
                widget.product == null ? 'New product' : 'Edit product',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              AppTextField(
                label: 'Name',
                controller: _nameController,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter the product name'
                    : null,
              ),
              const SizedBox(height: 12),
              AmountField(label: 'Base price', controller: _priceController),
              const SizedBox(height: 12),
              AmountField(
                label: 'Production cost / unit',
                controller: _costController,
                hint: 'Cost to produce one unit',
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Unit',
                controller: _unitController,
                hint: 'pcs, kg, metre ...',
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Description',
                controller: _descriptionController,
                maxLines: 2,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Save product',
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
