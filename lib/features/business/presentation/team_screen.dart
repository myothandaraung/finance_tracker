import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/member_role.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/error_view.dart';
import '../domain/business_membership.dart';
import '../providers/business_providers.dart';

/// Team of the active business. Only an owner can change it.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(businessMembersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _invite(context, ref),
        child: const Icon(Icons.person_add_alt),
      ),
      body: members.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(businessMembersProvider),
        ),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final member = items[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    member.displayName.isEmpty
                        ? '?'
                        : member.displayName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(
                  member.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('${member.email} · ${member.status}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) => _onAction(context, ref, value, member),
                  itemBuilder: (context) => [
                    for (final role in MemberRole.values)
                      PopupMenuItem(value: role.name, child: Text(role.label)),
                    const PopupMenuItem(value: 'remove', child: Text('Remove')),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final emailController = TextEditingController();
    var role = MemberRole.staff;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Invite a team member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: 'Email',
                controller: emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role.name,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  for (final item in MemberRole.values)
                    DropdownMenuItem(value: item.name, child: Text(item.label)),
                ],
                onChanged: (value) => setState(() {
                  role = MemberRole.values.firstWhere(
                    (item) => item.name == value,
                    orElse: () => MemberRole.staff,
                  );
                }),
              ),
              const SizedBox(height: 10),
              Text(
                role.description,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
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
              child: const Text('Invite'),
            ),
          ],
        ),
      ),
    );

    final email = emailController.text.trim();
    emailController.dispose();
    if (confirmed != true || email.isEmpty || !context.mounted) return;

    final businessId = ref.read(activeBusinessIdProvider);
    if (businessId == null) return;

    try {
      await ref
          .read(businessRepositoryProvider)
          .inviteMember(businessId: businessId, email: email, role: role.name);
      ref.invalidate(businessMembersProvider);
      if (!context.mounted) return;
      showAppSnackBar(context, 'Invitation created for $email');
    } catch (error) {
      if (!context.mounted) return;
      final message = error is AppException
          ? error.displayMessage
          : 'Could not invite the member';
      showAppSnackBar(context, message, isError: true);
    }
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    BusinessMember member,
  ) async {
    if (action == 'remove') {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Remove member',
        message: 'Remove ${member.displayName} from the business?',
        confirmLabel: 'Remove',
        isDestructive: true,
      );
      if (!confirmed) return;

      try {
        await ref.read(businessRepositoryProvider).removeMember(member.id);
        ref.invalidate(businessMembersProvider);
      } catch (error) {
        if (!context.mounted) return;
        showAppSnackBar(context, errorDisplayMessage(error), isError: true);
      }
      return;
    }

    try {
      await ref
          .read(businessRepositoryProvider)
          .updateMemberRole(memberId: member.id, role: action);
      ref.invalidate(businessMembersProvider);
    } catch (error) {
      if (!context.mounted) return;
      final message = error is AppException
          ? error.displayMessage
          : 'Could not change the role';
      showAppSnackBar(context, message, isError: true);
    }
  }
}
