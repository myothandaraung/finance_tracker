import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/info_row.dart';
import '../../../shared/widgets/section_title.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../business/providers/business_providers.dart';
import '../../orders/providers/order_providers.dart';
import '../../quotations/providers/quotation_providers.dart';
import '../providers/customer_providers.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(customerProvider(customerId));
    final role = ref.watch(currentRoleProvider);
    final orders = ref.watch(ordersProvider).value ?? const [];
    final quotations = ref.watch(quotationsProvider).value ?? const [];

    final customerOrders = orders
        .where((order) => order.customerId == customerId)
        .toList();
    final customerQuotations = quotations
        .where((quotation) => quotation.customerId == customerId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer'),
        actions: [
          if (role.canManageOperations)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/app/customers/$customerId/edit'),
            ),
        ],
      ),
      body: customer.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(customerProvider(customerId)),
        ),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Customer not found'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    InfoRow(
                      label: 'Phone',
                      value: data.phone ?? '—',
                      icon: Icons.phone_outlined,
                    ),
                    InfoRow(
                      label: 'Email',
                      value: data.email ?? '—',
                      icon: Icons.mail_outline,
                    ),
                    InfoRow(
                      label: 'Address',
                      value: data.address ?? '—',
                      icon: Icons.place_outlined,
                    ),
                    if (data.notes != null)
                      InfoRow(
                        label: 'Notes',
                        value: data.notes!,
                        icon: Icons.sticky_note_2_outlined,
                      ),
                    InfoRow(
                      label: 'Status',
                      value: data.isActive ? 'Active' : 'Inactive',
                      icon: Icons.circle_outlined,
                      valueColor: data.isActive
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                    InfoRow(
                      label: 'Customer since',
                      value: AppDate.format(data.createdAt),
                      icon: Icons.event_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    const SectionTitle(
                      'Orders',
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                    ),
                    if (customerOrders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'No orders for this customer yet.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      for (final order in customerOrders)
                        ListTile(
                          dense: true,
                          title: Text(order.orderNo),
                          subtitle: Text(
                            '${order.status.label} · ${MoneyFormatter.format(order.totalAmount)}',
                          ),
                          trailing: StatusChip.order(order.status, dense: true),
                          onTap: () => context.push('/app/orders/${order.id}'),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    const SectionTitle(
                      'Quotations',
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                    ),
                    if (customerQuotations.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'No quotations for this customer yet.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      for (final quotation in customerQuotations)
                        ListTile(
                          dense: true,
                          title: Text(quotation.quotationNo),
                          subtitle: Text(
                            '${quotation.status.label} · ${MoneyFormatter.format(quotation.totalAmount)}',
                          ),
                          trailing: StatusChip.quotation(
                            quotation.status,
                            dense: true,
                          ),
                          onTap: () =>
                              context.push('/app/quotations/${quotation.id}'),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
