import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_title.dart';
import '../../auth/providers/auth_providers.dart';
import '../../business/providers/business_providers.dart';

/// Everything that does not belong to the daily sales flow.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    final membership = ref.watch(activeMembershipProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: const Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (user?.userMetadata?['display_name'] as String?) ??
                            user?.email ??
                            'Signed in',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        membership == null
                            ? ''
                            : '${membership.name} · ${membership.role.label}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => context.push('/app/account'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (role.canManageOperations) ...[
            Card(
              child: Column(
                children: [
                  const SectionTitle('Catalog'),
                  ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: const Text('Products'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/app/products'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.construction_outlined),
                    title: const Text('Materials'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/app/materials'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (role.canManageFinance) ...[
            Card(
              child: Column(
                children: [
                  const SectionTitle('Money'),
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: const Text('Cash ledger'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/app/finance/payments'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.receipt_outlined),
                    title: const Text('Expenses'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/app/finance/expenses'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.insights_outlined),
                    title: const Text('Reports'),
                    subtitle: const Text('Sales, profitability, receivables'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/app/finance'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (role.canManageMembers || role.canManageSettings) ...[
            Card(
              child: Column(
                children: [
                  const SectionTitle('Business'),
                  if (role.canManageMembers)
                    ListTile(
                      leading: const Icon(Icons.group_outlined),
                      title: const Text('Team'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/app/team'),
                    ),
                  if (role.canManageSettings)
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('Business settings'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/app/settings'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Card(
            child: Column(
              children: [
                const SectionTitle('Account'),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Profile'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/app/account'),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  onTap: () => _signOut(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authRepositoryProvider).signOut();
    if (context.mounted) context.go('/sign-in');
  }
}
