import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../business/providers/business_providers.dart';
import '../domain/material.dart' as domain;
import '../providers/material_providers.dart';

class MaterialListScreen extends ConsumerWidget {
  const MaterialListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materials = ref.watch(materialsProvider);
    final role = ref.watch(currentRoleProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.translate('Materials'))),
      floatingActionButton: role.canManageOperations
          ? FloatingActionButton(
              onPressed: () => _openForm(context, ref, null),
              child: const Icon(Icons.add),
            )
          : null,
      body: materials.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(materialsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              title: 'No materials yet',
              message:
                  'Add the materials you use in production to cost an order.',
              icon: Icons.construction_outlined,
              action: role.canManageOperations
                  ? FilledButton.icon(
                      onPressed: () => _openForm(context, ref, null),
                      icon: const Icon(Icons.add),
                      label: Text(context.l10n.translate('Add material')),
                    )
                  : null,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final material = items[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.construction_outlined),
                  title: Text(
                    material.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [
                      '${MoneyFormatter.format(material.defaultUnitCost)}'
                          '${material.unit == null ? '' : ' per ${material.unit}'}',
                      if (!material.isActive) 'inactive',
                    ].join(' · '),
                  ),
                  trailing: role.canManageOperations
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openForm(context, ref, material),
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
    domain.Material? material,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _MaterialForm(material: material),
    );
    ref.invalidate(materialsProvider);
  }
}

class _MaterialForm extends ConsumerStatefulWidget {
  const _MaterialForm({this.material});

  final domain.Material? material;

  @override
  ConsumerState<_MaterialForm> createState() => _MaterialFormState();
}

class _MaterialFormState extends ConsumerState<_MaterialForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _costController;

  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.material?.name ?? '');
    _unitController = TextEditingController(text: widget.material?.unit ?? '');
    _costController = TextEditingController(
      text: widget.material?.defaultUnitCost.plain ?? '',
    );
    _isActive = widget.material?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
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
          .read(materialRepositoryProvider)
          .saveMaterial(
            businessId: businessId,
            materialId: widget.material?.id,
            name: _nameController.text.trim(),
            unit: _unitController.text.trim(),
            defaultUnitCost: Money.tryParse(_costController.text) ?? Money.zero,
            isActive: _isActive,
          );
      if (!mounted) return;
      showAppSnackBar(context, 'Material saved');
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      final message = error is AppException
          ? error.displayMessage
          : 'Could not save the material';
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
                context.l10n.translate(
                  widget.material == null ? 'New material' : 'Edit material',
                ),
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
                    ? 'Enter the material name'
                    : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Unit',
                controller: _unitController,
                hint: 'pcs, kg, metre ...',
              ),
              const SizedBox(height: 12),
              AmountField(
                label: 'Default unit cost',
                controller: _costController,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.translate('Active')),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Save material',
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
