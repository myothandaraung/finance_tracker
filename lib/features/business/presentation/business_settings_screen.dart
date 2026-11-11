import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialogs.dart';
import '../providers/business_providers.dart';

/// Name and currency of the business.
class BusinessSettingsScreen extends ConsumerStatefulWidget {
  const BusinessSettingsScreen({super.key});

  @override
  ConsumerState<BusinessSettingsScreen> createState() =>
      _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState
    extends ConsumerState<BusinessSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _currencyController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final membership = ref.read(activeMembershipProvider);
    _nameController = TextEditingController(text: membership?.name ?? '');
    _currencyController = TextEditingController(
      text: membership?.currencyCode ?? 'MMK',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final businessId = ref.read(activeBusinessIdProvider);
    if (businessId == null) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(businessRepositoryProvider)
          .updateBusiness(
            businessId: businessId,
            name: _nameController.text.trim(),
            currencyCode: _currencyController.text.trim().toUpperCase(),
          );

      await ref.read(membershipsProvider.notifier).refresh();
      if (!mounted) return;
      showAppSnackBar(context, 'Business settings saved');
    } catch (error) {
      if (!mounted) return;
      final message = error is AppException
          ? error.displayMessage
          : 'Could not save the settings';
      showAppSnackBar(context, message, isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.translate('Business settings'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
              label: 'Business name',
              controller: _nameController,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter the business name'
                  : null,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Currency code',
              controller: _currencyController,
              hint: 'PHP, USD, EUR',
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Save settings',
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
