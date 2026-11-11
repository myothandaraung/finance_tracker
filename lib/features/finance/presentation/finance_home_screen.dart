import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_title.dart';
import '../../business/providers/business_providers.dart';

/// Entry point of everything that is not part of the daily sales flow.
class FinanceHomeScreen extends ConsumerWidget {
  const FinanceHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.translate('Finance'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            onTap: () => context.push('/app/reports/receivables'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(context.l10n.translate('Receivables')),
              subtitle: Text(
                context.l10n.translate('Outstanding balance and ageing'),
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          AppCard(
            onTap: () => context.push('/app/reports/sales'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.insights_outlined),
              title: Text(context.l10n.translate('Sales report')),
              subtitle: Text(
                context.l10n.translate('Revenue, cash collected and order mix'),
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          AppCard(
            onTap: () => context.push('/app/reports/profitability'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.pie_chart_outline),
              title: Text(context.l10n.translate('Profitability')),
              subtitle: Text(
                context.l10n.translate('Margin per delivered order'),
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                const SectionTitle('Cash and costs'),
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: Text(context.l10n.translate('Cash ledger')),
                  subtitle: Text(
                    context.l10n.translate('Payments and refunds'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/app/finance/payments'),
                ),
                ListTile(
                  leading: const Icon(Icons.receipt_outlined),
                  title: Text(context.l10n.translate('Expenses')),
                  subtitle: Text(context.l10n.translate('Operating expenses')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/app/finance/expenses'),
                ),
              ],
            ),
          ),
          if (!role.canManageFinance)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text(
                'Your role can read the financial data but not change it.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}
