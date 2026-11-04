import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      appBar: AppBar(title: const Text('Finance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            onTap: () => context.push('/app/reports/receivables'),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.account_balance_wallet_outlined),
              title: Text('Receivables'),
              subtitle: Text('Outstanding balance and ageing'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
          AppCard(
            onTap: () => context.push('/app/reports/sales'),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.insights_outlined),
              title: Text('Sales report'),
              subtitle: Text('Revenue, cash collected and order mix'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
          AppCard(
            onTap: () => context.push('/app/reports/profitability'),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.pie_chart_outline),
              title: Text('Profitability'),
              subtitle: Text('Margin per delivered order'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                const SectionTitle('Cash and costs'),
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Cash ledger'),
                  subtitle: const Text('Payments and refunds'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/app/finance/payments'),
                ),
                ListTile(
                  leading: const Icon(Icons.receipt_outlined),
                  title: const Text('Expenses'),
                  subtitle: const Text('Operating expenses'),
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
