import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../business/providers/business_providers.dart';
import '../../customers/providers/customer_providers.dart';
import '../data/order_repository.dart';
import '../domain/order.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(supabaseClientProvider));
});

/// Filters applied to the order list.
class OrderFilter {
  const OrderFilter({this.status, this.search = '', this.assignedTo});

  final String? status;
  final String search;
  final String? assignedTo;

  OrderFilter copyWith({
    String? status,
    bool clearStatus = false,
    String? search,
    String? assignedTo,
    bool clearAssignedTo = false,
  }) {
    return OrderFilter(
      status: clearStatus ? null : (status ?? this.status),
      search: search ?? this.search,
      assignedTo: clearAssignedTo ? null : (assignedTo ?? this.assignedTo),
    );
  }
}

class OrderFilterNotifier extends Notifier<OrderFilter> {
  @override
  OrderFilter build() => const OrderFilter();

  void setStatus(String? status) {
    state = status == null
        ? state.copyWith(clearStatus: true)
        : state.copyWith(status: status);
  }

  void setSearch(String search) => state = state.copyWith(search: search);

  void setAssignedTo(String? userId) {
    state = userId == null
        ? state.copyWith(clearAssignedTo: true)
        : state.copyWith(assignedTo: userId);
  }
}

final orderFilterProvider = NotifierProvider<OrderFilterNotifier, OrderFilter>(
  OrderFilterNotifier.new,
);

/// Orders of the active business, filtered.
final ordersProvider = FutureProvider<List<Order>>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  if (businessId == null) return const [];

  final filter = ref.watch(orderFilterProvider);
  final repository = ref.watch(orderRepositoryProvider);
  final rows = await repository.listOrderRows(
    businessId,
    status: filter.status,
    assignedTo: filter.assignedTo,
  );

  final customers = await ref.watch(customerRepositoryProvider).listCustomers(businessId);
  final names = {for (final customer in customers) customer.id: customer.name};

  final orders = rows
      .map(
        (row) => Order.fromJson(
          row,
          customerName: names[row['customer_id']] ?? 'Unknown customer',
        ),
      )
      .toList();

  final search = filter.search.trim().toLowerCase();
  if (search.isEmpty) return orders;

  return orders
      .where(
        (order) =>
            order.orderNo.toLowerCase().contains(search) ||
            order.customerName.toLowerCase().contains(search),
      )
      .toList();
});
/// Full detail of one order: items, money, costs and history.
final orderDetailProvider =
    FutureProvider.family<OrderDetail, String>((ref, orderId) async {
  return ref.watch(orderRepositoryProvider).orderDetail(orderId);
});
