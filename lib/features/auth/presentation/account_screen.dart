import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../business/providers/business_providers.dart';
import '../providers/auth_providers.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  late final TextEditingController _nameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: ref.read(currentUserProvider)?.userMetadata?['display_name'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile(
            displayName: _nameController.text.trim(),
          );
      if (!mounted) return;
      showAppSnackBar(context, 'Profile updated');
    } catch (error) {
      if (!mounted) return;
      final message = error is AppException
          ? error.message
          : 'Could not update the profile';
      showAppSnackBar(context, message, isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sign out',
      message: 'You will need to sign in again to continue.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed) return;

    await ref.read(authRepositoryProvider).signOut();
    if (mounted) context.go('/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final membership = ref.watch(activeMembershipProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppTextField(
            label: 'Display name',
            controller: _nameController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveProfile(),
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Email',
            controller: TextEditingController(text: user?.email ?? ''),
            enabled: false,
          ),
          const SizedBox(height: 14),
          AppButton(
            label: 'Save profile',
            icon: Icons.save_outlined,
            isLoading: _isSaving,
            onPressed: _saveProfile,
          ),
          const SizedBox(height: 24),
          if (membership != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.business_outlined),
              title: const Text('Business'),
              subtitle: Text(
                '${membership.name} · ${membership.role.label}',
              ),
            ),
          const SizedBox(height: 18),
          AppButton(
            label: 'Sign out',
            icon: Icons.logout,
            style: AppButtonStyle.outlined,
            onPressed: _signOut,
          ),
        ],
      ),
    );
  }
}
