import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/quotation_status.dart';
import '../../../core/money/money_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../business/providers/business_providers.dart';
import '../providers/quotation_providers.dart';

class QuotationListScreen extends ConsumerStatefulWidget {
  const QuotationListScreen({super.key});

  @override
  ConsumerState<QuotationListScreen> createState() => _QuotationListScreenState();
}

class _QuotationListScreenState extends ConsumerState<QuotationListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quotations = ref.watch(quotationsProvider);
    final filter = ref.watch(quotationFilterProvider);
    final role = ref.watch(currentRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotations'),
        actions: [
          if (role.canManageOperations)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.push('/app/quotations/new'),
            ),
        ],
      ),
      floatingActionButton: role.canManageOperations
          ? FloatingActionButton(
              onPressed: () => context.push('/app/quotations/new'),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: ref.read(quotationFilterProvider.notifier).setSearch,
              decoration: const InputDecoration(
                hintText: 'Search by number or customer',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _FilterChip(
                  label: 'All',
                  selected: filter.status == null,
                  onTap: () =>
                      ref.read(quotationFilterProvider.notifier).setStatus(null),
                ),
                for (final status in QuotationStatus.values)
                  _FilterChip(
                    label: status.label,
                    selected: filter.status == status.dbValue,
                    onTap: () => ref
                        .read(quotationFilterProvider.notifier)
                        .setStatus(status.dbValue),
                  ),
              ],
            ),
          ),
          Expanded(
            child: quotations.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(quotationsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    title: 'No quotations yet',
                    message: 'Create a quotation to send a price to a customer.',
                    icon: Icons.request_quote_outlined,
                    action: role.canManageOperations
                        ? FilledButton.icon(
                            onPressed: () => context.push('/app/quotations/new'),
                            icon: const Icon(Icons.add),
                            label: const Text('New quotation'),
                          )
                        : null,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final quotation = items[index];
                    return Card(
                      child: InkWell(
                        onTap: () =>
                            context.push('/app/quotations/${quotation.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      quotation.quotationNo,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  StatusChip.quotation(
                                    quotation.status,
                                    dense: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                quotation.customerName,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      MoneyFormatter.format(quotation.totalAmount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    AppDate.formatShort(quotation.createdAt),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
