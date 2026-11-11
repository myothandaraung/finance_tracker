import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../business/providers/business_providers.dart';
import '../providers/customer_providers.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    final role = ref.watch(currentRoleProvider);

    final filtered =
        customers.value
            ?.where(
              (customer) => customer.name.toLowerCase().contains(
                _search.trim().toLowerCase(),
              ),
            )
            .toList() ??
        const [];

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.translate('Customers'))),
      floatingActionButton: role.canManageOperations
          ? FloatingActionButton(
              onPressed: () => context.push('/app/customers/new'),
              child: const Icon(Icons.person_add_alt),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                hintText: context.l10n.translate('Search customers'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: customers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(customersProvider),
              ),
              data: (_) {
                if (filtered.isEmpty) {
                  return EmptyState(
                    title: _search.isEmpty
                        ? 'No customers yet'
                        : 'No customer matches "$_search"',
                    message: _search.isEmpty
                        ? 'Add your first customer to start quoting.'
                        : null,
                    icon: Icons.people_outline,
                    action: role.canManageOperations && _search.isEmpty
                        ? FilledButton.icon(
                            onPressed: () => context.push('/app/customers/new'),
                            icon: const Icon(Icons.person_add_alt),
                            label: Text(context.l10n.translate('Add customer')),
                          )
                        : null,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final customer = filtered[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.12,
                          ),
                          child: Text(
                            customer.name.isEmpty
                                ? '?'
                                : customer.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          customer.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          [
                            if (customer.phone != null) customer.phone!,
                            if (customer.email != null) customer.email!,
                          ].join(' · '),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            context.push('/app/customers/${customer.id}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
