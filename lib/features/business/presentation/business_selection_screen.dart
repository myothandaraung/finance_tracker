import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/error_view.dart';
import '../providers/business_providers.dart';

/// Lets the user pick the business they want to work in. A user with a single
/// membership is taken straight to the dashboard.
class BusinessSelectionScreen extends ConsumerWidget {
  const BusinessSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberships = ref.watch(membershipsProvider);
    final activeBusinessId = ref.watch(activeBusinessIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your businesses')),
      body: memberships.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.read(membershipsProvider.notifier).refresh(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.business_outlined, size: 46),
                    const SizedBox(height: 16),
                    const Text(
                      'You are not a member of a business yet.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'Create a business',
                      icon: Icons.add_business_outlined,
                      expand: false,
                      onPressed: () => _createBusiness(context, ref),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Choose the business you want to work in.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              for (final membership in items)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.business_outlined),
                    title: Text(
                      membership.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(membership.role.label),
                    trailing: membership.businessId == activeBusinessId
                        ? const Icon(Icons.check_circle, color: AppColors.success)
                        : const Icon(Icons.chevron_right),
                    onTap: () async {
                      await ref
                          .read(activeBusinessIdProvider.notifier)
                          .select(membership.businessId);
                      if (context.mounted) context.go('/app/dashboard');
                    },
                  ),
                ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Create another business',
                icon: Icons.add_business_outlined,
                style: AppButtonStyle.outlined,
                onPressed: () => _createBusiness(context, ref),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createBusiness(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New business'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: 'Business name',
              controller: nameController,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    final name = nameController.text.trim();
    nameController.dispose();

    if (created != true || name.isEmpty || !context.mounted) return;

    try {
      final membership = await ref.read(businessRepositoryProvider).createBusiness(
            name: name,
          );
      await ref
          .read(activeBusinessIdProvider.notifier)
          .select(membership.businessId);
      await ref.read(membershipsProvider.notifier).refresh();
      if (context.mounted) context.go('/app/dashboard');
    } catch (error) {
      if (!context.mounted) return;
      final message = error is AppException
          ? error.message
          : 'Could not create the business';
      showAppSnackBar(context, message, isError: true);
    }
  }
}
