import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/presentation/account_screen.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/auth/presentation/sign_in_screen.dart';
import 'features/auth/presentation/sign_up_screen.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/business/presentation/business_selection_screen.dart';
import 'features/business/presentation/business_settings_screen.dart';
import 'features/business/presentation/team_screen.dart';
import 'features/business/providers/business_providers.dart';
import 'features/customers/presentation/customer_detail_screen.dart';
import 'features/customers/presentation/customer_form_screen.dart';
import 'features/customers/presentation/customer_list_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/expenses/presentation/expenses_screen.dart';
import 'features/finance/presentation/finance_home_screen.dart';
import 'features/materials/presentation/material_list_screen.dart';
import 'features/more/presentation/more_screen.dart';
import 'features/orders/presentation/order_detail_screen.dart';
import 'features/orders/presentation/order_form_screen.dart';
import 'features/orders/presentation/order_list_screen.dart';
import 'features/payments/presentation/payments_screen.dart';
import 'features/products/presentation/product_list_screen.dart';
import 'features/quotations/presentation/quotation_detail_screen.dart';
import 'features/quotations/presentation/quotation_form_screen.dart';
import 'features/quotations/presentation/quotation_list_screen.dart';
import 'features/reports/presentation/profitability_report_screen.dart';
import 'features/reports/presentation/receivables_report_screen.dart';
import 'features/reports/presentation/sales_report_screen.dart';
import 'features/shell/presentation/app_shell.dart';

/// Notifies the router whenever the session or the selected business change.
class RouterRefresh extends ChangeNotifier {
  RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(activeBusinessIdProvider, (_, _) => notifyListeners());
    ref.listen(membershipsProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefresh(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(authStateProvider).value?.session;
      final businessId = ref.read(activeBusinessIdProvider);
      final memberships = ref.read(membershipsProvider).value ?? const [];
      final location = state.matchedLocation;

      final isSignedIn = session != null;
      final hasBusiness = businessId != null &&
          memberships.any((membership) => membership.businessId == businessId);

      if (!isSignedIn) {
        const publicRoutes = {
          '/splash',
          '/sign-in',
          '/sign-up',
          '/forgot-password',
        };
        if (!publicRoutes.contains(location)) return '/sign-in';
        if (location == '/splash') return '/sign-in';
        return null;
      }

      if (!hasBusiness) {
        if (location != '/businesses') return '/businesses';
        return null;
      }

      if (location == '/splash' || location == '/businesses' || location == '/sign-in') {
        return '/app/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/sign-up', builder: (_, _) => const SignUpScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/businesses',
        builder: (_, _) => const BusinessSelectionScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(
          location: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/app/dashboard',
            builder: (_, _) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/app/quotations',
            builder: (_, _) => const QuotationListScreen(),
          ),
          GoRoute(
            path: '/app/orders',
            builder: (_, _) => const OrderListScreen(),
          ),
          GoRoute(
            path: '/app/customers',
            builder: (_, _) => const CustomerListScreen(),
          ),
          GoRoute(
            path: '/app/finance',
            builder: (_, _) => const FinanceHomeScreen(),
          ),
          GoRoute(
            path: '/app/finance/payments',
            builder: (_, _) => const PaymentsScreen(),
          ),
          GoRoute(
            path: '/app/finance/expenses',
            builder: (_, _) => const ExpensesScreen(),
          ),
          GoRoute(
            path: '/app/more',
            builder: (_, _) => const MoreScreen(),
          ),
          GoRoute(
            path: '/app/products',
            builder: (_, _) => const ProductListScreen(),
          ),
          GoRoute(
            path: '/app/materials',
            builder: (_, _) => const MaterialListScreen(),
          ),
          GoRoute(
            path: '/app/team',
            builder: (_, _) => const TeamScreen(),
          ),
          GoRoute(
            path: '/app/settings',
            builder: (_, _) => const BusinessSettingsScreen(),
          ),
          GoRoute(
            path: '/app/account',
            builder: (_, _) => const AccountScreen(),
          ),
          GoRoute(
            path: '/app/reports/sales',
            builder: (_, _) => const SalesReportScreen(),
          ),
          GoRoute(
            path: '/app/reports/profitability',
            builder: (_, _) => const ProfitabilityReportScreen(),
          ),
          GoRoute(
            path: '/app/reports/receivables',
            builder: (_, _) => const ReceivablesReportScreen(),
          ),
          GoRoute(
            path: '/app/quotations/new',
            builder: (_, _) => const QuotationFormScreen(),
          ),
          GoRoute(
            path: '/app/quotations/:id',
            builder: (_, state) =>
                QuotationDetailScreen(quotationId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/quotations/:id/edit',
            builder: (_, state) =>
                QuotationFormScreen(quotationId: state.pathParameters['id']),
          ),
          GoRoute(
            path: '/app/orders/new',
            builder: (_, _) => const OrderFormScreen(),
          ),
          GoRoute(
            path: '/app/orders/:id',
            builder: (_, state) =>
                OrderDetailScreen(orderId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/orders/:id/edit',
            builder: (_, state) =>
                OrderFormScreen(orderId: state.pathParameters['id']),
          ),
          GoRoute(
            path: '/app/customers/new',
            builder: (_, _) => const CustomerFormScreen(),
          ),
          GoRoute(
            path: '/app/customers/:id',
            builder: (_, state) =>
                CustomerDetailScreen(customerId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/customers/:id/edit',
            builder: (_, state) =>
                CustomerFormScreen(customerId: state.pathParameters['id']),
          ),
        ],
      ),
    ],
  );
});
