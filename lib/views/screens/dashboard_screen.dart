import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/locale_provider.dart';
import '../../services/database_service.dart';
import '../../l10n/app_localizations.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Map<String, dynamic> _dailySales = {'revenue': 0.0, 'transactionCount': 0, 'totalPieces': 0};
  List _lowStockProducts = [];
  double _dailyCOGS = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final sales = await DatabaseService.instance.getDailySales();
    final lowStock = await DatabaseService.instance.getLowStockProducts();
    final cogs = await DatabaseService.instance.getDailyCOGS();
    if (!mounted) return;
    setState(() {
      _dailySales = sales;
      _lowStockProducts = lowStock;
      _dailyCOGS = cogs;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final revenue = _dailySales['revenue'] as double;
    final netProfit = revenue - _dailyCOGS;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.tr('dashboard')),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () => ref.read(localeProvider.notifier).toggle(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Daily Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.tr('daily_summary'),
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statItem(loc.tr('sold_pieces'), '${_dailySales['totalPieces']}', Icons.shopping_bag),
                      const SizedBox(width: 16),
                      _statItem(loc.tr('revenue'), '${revenue.toStringAsFixed(0)} ${loc.tr('currency')}', Icons.attach_money),
                      const SizedBox(width: 16),
                      _statItem(loc.tr('transactions'), '${_dailySales['transactionCount']}', Icons.receipt),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // COGS + Net Profit row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.tr('cogs'), style: TextStyle(color: Colors.orange[700], fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('${_dailyCOGS.toStringAsFixed(0)} ${loc.tr('currency')}',
                            style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.w800, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: netProfit >= 0 ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: netProfit >= 0 ? Colors.green[200]! : Colors.red[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.tr('net_profit'), style: TextStyle(
                            color: netProfit >= 0 ? Colors.green[700] : Colors.red[700],
                            fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('${netProfit.toStringAsFixed(0)} ${loc.tr('currency')}',
                            style: TextStyle(
                                color: netProfit >= 0 ? Colors.green[800] : Colors.red[800],
                                fontWeight: FontWeight.w800, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Low Stock Alert
            if (_lowStockProducts.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Text('${_lowStockProducts.length} ${loc.tr('low_stock')}',
                        style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Navigation cards
            Text(loc.tr('quick_actions'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _navCard(loc.tr('pos'), Icons.point_of_sale, () => context.go('/pos')),
            const SizedBox(height: 8),
            _navCard(loc.tr('inventory'), Icons.inventory_2_outlined, () => context.go('/inventory')),
            const SizedBox(height: 8),
            _navCard(loc.tr('bulk_order'), Icons.local_shipping_outlined, () => context.go('/bulk-order')),
            const SizedBox(height: 8),
            _navCard(loc.tr('credit_clients'), Icons.account_balance_wallet_outlined, () => context.go('/credit-clients')),
            const SizedBox(height: 8),
            _navCard(loc.tr('invoices'), Icons.receipt_long_outlined, () => context.go('/invoices')),
            const SizedBox(height: 8),
            _navCard(loc.tr('network_sync'), Icons.sync_alt, () => context.go('/sync')),
            const SizedBox(height: 8),
            _navCard(loc.tr('settings'), Icons.settings_outlined, () => context.go('/settings')),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _navCard(String title, IconData icon, VoidCallback onTap) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
