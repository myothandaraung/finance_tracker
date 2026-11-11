import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
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
    final locale = ref.watch(appLocaleProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.text('more'))),
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
                            l10n.text('signed_in'),
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
                  SectionTitle(l10n.text('catalog')),
                  ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(l10n.text('products')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/app/products'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.construction_outlined),
                    title: Text(l10n.text('materials')),
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
                  SectionTitle(l10n.text('money')),
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: Text(l10n.text('cash_ledger')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/app/finance/payments'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.receipt_outlined),
                    title: Text(l10n.text('expenses')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/app/finance/expenses'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.insights_outlined),
                    title: Text(l10n.text('reports')),
                    subtitle: Text(l10n.text('reports_subtitle')),
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
                  SectionTitle(l10n.text('business')),
                  if (role.canManageMembers)
                    ListTile(
                      leading: const Icon(Icons.group_outlined),
                      title: Text(l10n.text('team')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/app/team'),
                    ),
                  if (role.canManageSettings)
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: Text(l10n.text('business_settings')),
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
                SectionTitle(l10n.text('preferences')),
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: Text(l10n.text('language')),
                  subtitle: Text(
                    locale.languageCode == 'my'
                        ? l10n.text('myanmar')
                        : l10n.text('english'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _chooseLanguage(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SectionTitle(l10n.text('account')),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(l10n.text('profile')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/app/account'),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(l10n.text('sign_out')),
                  onTap: () => _signOut(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseLanguage(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final current = ref.read(appLocaleProvider).languageCode;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.text('choose_language')),
        children: [
          RadioListTile<String>(
            value: 'en',
            groupValue: current,
            title: Text(l10n.text('english')),
            onChanged: (value) => Navigator.pop(dialogContext, value),
          ),
          RadioListTile<String>(
            value: 'my',
            groupValue: current,
            title: Text(l10n.text('myanmar')),
            onChanged: (value) => Navigator.pop(dialogContext, value),
          ),
        ],
      ),
    );
    if (selected != null) {
      await ref.read(appLocaleProvider.notifier).select(selected);
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authRepositoryProvider).signOut();
    if (context.mounted) context.go('/sign-in');
  }
}
