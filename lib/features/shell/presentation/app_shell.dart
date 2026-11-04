import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';

/// One entry of the bottom navigation bar.
class ShellDestination {
  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
}

const List<ShellDestination> shellDestinations = [
  ShellDestination(
    label: 'Dashboard',
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard,
    path: '/app/dashboard',
  ),
  ShellDestination(
    label: 'Quotes',
    icon: Icons.request_quote_outlined,
    selectedIcon: Icons.request_quote,
    path: '/app/quotations',
  ),
  ShellDestination(
    label: 'Orders',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    path: '/app/orders',
  ),
  ShellDestination(
    label: 'Customers',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    path: '/app/customers',
  ),
  ShellDestination(
    label: 'More',
    icon: Icons.more_horiz,
    selectedIcon: Icons.more_horiz,
    path: '/app/more',
  ),
];

/// Bottom navigation shell. Every main screen lives inside this shell.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  int get _selectedIndex {
    final index = shellDestinations.indexWhere(
      (destination) => location == destination.path,
    );
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            final destination = shellDestinations[index];
            if (destination.path != location) {
              context.go(destination.path);
            }
          },
          destinations: [
            for (final destination in shellDestinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
          ],
        ),
      ),
    );
  }
}
