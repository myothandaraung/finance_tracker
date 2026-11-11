import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/order_status.dart';
import '../../../core/money/money_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../business/providers/business_providers.dart';
import '../providers/order_providers.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);
    final filter = ref.watch(orderFilterProvider);
    final role = ref.watch(currentRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          if (role.canManageOperations)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.push('/app/orders/new'),
            ),
        ],
      ),
      floatingActionButton: role.canManageOperations
          ? FloatingActionButton(
              onPressed: () => context.push('/app/orders/new'),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: ref.read(orderFilterProvider.notifier).setSearch,
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
                      ref.read(orderFilterProvider.notifier).setStatus(null),
                ),
                for (final status in OrderStatus.values)
                  _FilterChip(
                    label: status.label,
                    selected: filter.status == status.dbValue,
                    onTap: () => ref
                        .read(orderFilterProvider.notifier)
                        .setStatus(status.dbValue),
                  ),
              ],
            ),
          ),
          Expanded(
            child: orders.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(ordersProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    title: 'No orders yet',
                    message: 'Create an order or convert a quotation.',
                    icon: Icons.receipt_long_outlined,
                    action: role.canManageOperations
                        ? FilledButton.icon(
                            onPressed: () => context.push('/app/orders/new'),
                            icon: const Icon(Icons.add),
                            label: const Text('New order'),
                          )
                        : null,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final order = items[index];
                    final isOverdue =
                        order.dueDate != null &&
                        order.dueDate!.isBefore(DateTime.now()) &&
                        !order.status.isTerminal &&
                        order.status != OrderStatus.delivered;

                    return Card(
                      child: InkWell(
                        onTap: () => context.push('/app/orders/${order.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      order.orderNo,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  StatusChip.order(order.status, dense: true),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                order.customerName,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      MoneyFormatter.format(order.totalAmount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  if (order.dueDate != null)
                                    Text(
                                      'Due ${AppDate.formatShort(order.dueDate)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isOverdue
                                            ? AppColors.danger
                                            : AppColors.textSecondary,
                                        fontWeight: isOverdue
                                            ? FontWeight.w700
                                            : FontWeight.w400,
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
