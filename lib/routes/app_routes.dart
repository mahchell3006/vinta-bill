import 'package:go_router/go_router.dart';
import '../views/screens/dashboard_screen.dart';
import '../views/screens/pos_screen.dart';
import '../views/screens/inventory_screen.dart';
import '../views/screens/checkout_screen.dart';
import '../views/screens/settings_screen.dart';
import '../views/screens/invoices_screen.dart';
import '../views/screens/credit_clients_screen.dart';

final goRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/pos',
      builder: (context, state) => const PosScreen(),
    ),
    GoRoute(
      path: '/inventory',
      builder: (context, state) => const InventoryScreen(),
    ),
    GoRoute(
      path: '/checkout',
      builder: (context, state) => const CheckoutScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/invoices',
      builder: (context, state) => const InvoicesScreen(),
    ),
    GoRoute(
      path: '/credit-clients',
      builder: (context, state) => const CreditClientsScreen(),
    ),
  ],
);
