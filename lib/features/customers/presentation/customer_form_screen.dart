import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../business/providers/business_providers.dart';
import '../providers/customer_providers.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.customerId});

  final String? customerId;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final customerId = widget.customerId;
    if (customerId == null) return;

    // Pre-fill the form once the customer is loaded.
    Future<void>(() async {
      final customer = await ref.read(customerProvider(customerId).future);
      if (customer == null || !mounted) return;
      _nameController.text = customer.name;
      _phoneController.text = customer.phone ?? '';
      _emailController.text = customer.email ?? '';
      _addressController.text = customer.address ?? '';
      _notesController.text = customer.notes ?? '';
      setState(() => _isActive = customer.isActive);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final businessId = ref.read(activeBusinessIdProvider);
    if (businessId == null) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(customerRepositoryProvider)
          .saveCustomer(
            businessId: businessId,
            customerId: widget.customerId,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            email: _emailController.text.trim(),
            address: _addressController.text.trim(),
            notes: _notesController.text.trim(),
            isActive: _isActive,
          );

      ref.invalidate(customersProvider);
      if (widget.customerId != null) {
        ref.invalidate(customerProvider(widget.customerId!));
      }

      if (!mounted) return;
      showAppSnackBar(context, 'Customer saved');
      context.pop();
    } catch (error) {
      if (!mounted) return;
      final message = error is AppException
          ? error.displayMessage
          : 'Could not save the customer';
      showAppSnackBar(context, message, isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.translate(
            widget.customerId == null ? 'New customer' : 'Edit customer',
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
              label: 'Name',
              controller: _nameController,
              autofocus: widget.customerId == null,
              textInputAction: TextInputAction.next,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter the customer name'
                  : null,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Phone',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                if (!text.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Address',
              controller: _addressController,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Notes',
              controller: _notesController,
              maxLines: 3,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.translate('Active customer')),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            const SizedBox(height: 18),
            AppButton(
              label: 'Save customer',
              icon: Icons.save_outlined,
              isLoading: _isSaving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
