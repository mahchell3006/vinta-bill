import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/backup_models.dart';
import '../../services/backup_service.dart';
import '../../providers/cart_provider.dart';
import '../../l10n/app_localizations.dart';

class ImportPreviewScreen extends ConsumerStatefulWidget {
  final String backupFilePath;

  const ImportPreviewScreen({super.key, required this.backupFilePath});

  @override
  ConsumerState<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends ConsumerState<ImportPreviewScreen> {
  ImportDiff? _diff;
  BackupManifest? _manifest;
  bool _isLoading = true;
  String? _error;

  // Toggle states
  bool _mergeInvoices = true;
  bool _mergeProducts = true;
  bool _mergeCustomers = true;
  bool _mergeCategories = true;
  bool _updatePrices = false;
  bool _updateStock = true;

  // Merge progress
  bool _isMerging = false;
  double _mergeProgress = 0;
  String _mergeStatus = '';

  String? _stagingDbPath;

  @override
  void initState() {
    super.initState();
    _analyzeBackup();
  }

  Future<void> _analyzeBackup() async {
    try {
      setState(() => _isLoading = true);

      // Extract backup
      final result = await BackupService.instance.extractBackup(widget.backupFilePath);
      _manifest = result.manifest;
      _stagingDbPath = result.dbPath;

      // Compute diff
      final diff = await BackupService.instance.computeDiff(incomingDbPath: result.dbPath);

      if (!mounted) return;
      setState(() {
        _diff = diff;
        _isLoading = false;
        // Auto-toggle based on what has data
        _mergeInvoices = diff.newInvoiceCount > 0;
        _mergeProducts = diff.productChanges.isNotEmpty;
        _mergeCustomers = diff.customerChanges.isNotEmpty;
        _mergeCategories = diff.newCategoryCount > 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleAll() {
    final allOn = _mergeInvoices && _mergeProducts && _mergeCustomers && _mergeCategories;
    setState(() {
      _mergeInvoices = !allOn;
      _mergeProducts = !allOn;
      _mergeCustomers = !allOn;
      _mergeCategories = !allOn;
    });
  }

  bool get _allSelected => _mergeInvoices && _mergeProducts && _mergeCustomers && _mergeCategories;

  bool get _anySelected => _mergeInvoices || _mergeProducts || _mergeCustomers || _mergeCategories;

  Future<void> _executeMerge() async {
    if (!_anySelected || _stagingDbPath == null || _diff == null) return;

    final loc = AppLocalizations.of(context);

    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.tr('merge_selected')),
        content: Text('This will merge the selected data into your local database. A safety backup will be created first.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.tr('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.tr('merge_selected')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isMerging = true;
      _mergeProgress = 0.1;
      _mergeStatus = 'Creating safety backup...';
    });

    try {
      // Safety backup
      await BackupService.instance.createSafetyBackup();
      setState(() { _mergeProgress = 0.3; _mergeStatus = 'Merging data...'; });

      // Execute merge
      final result = await BackupService.instance.executeMerge(
        incomingDbPath: _stagingDbPath!,
        diff: _diff!,
        mergeInvoices: _mergeInvoices,
        mergeProducts: _mergeProducts,
        mergeCustomers: _mergeCustomers,
        mergeCategories: _mergeCategories,
        updatePrices: _updatePrices,
        updateStock: _updateStock,
      );

      setState(() { _mergeProgress = 0.9; _mergeStatus = 'Refreshing data...'; });

      // Cleanup staging
      await BackupService.instance.cleanupStaging(_stagingDbPath!);

      setState(() { _mergeProgress = 1.0; });

      if (!mounted) return;

      if (result.success) {
        // Invalidate providers to refresh data
        ref.invalidate(cartProvider);

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Merge complete: ${result.invoicesAdded} invoices, '
            '${result.productsAdded} products added, '
            '${result.productsUpdated} updated, '
            '${result.customersAdded} customers',
          ),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 3),
        ));
        context.go('/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Merge failed: ${result.error}'),
          backgroundColor: Colors.red[600],
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _isMerging = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red[600],
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.tr('import_preview')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_stagingDbPath != null) {
              BackupService.instance.cleanupStaging(_stagingDbPath!);
            }
            context.go('/inventory');
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(loc)
              : _diff == null
                  ? const Center(child: Text('No data'))
                  : _isMerging
                      ? _buildProgress(loc)
                      : _buildPreview(loc, theme),
    );
  }

  Widget _buildError(AppLocalizations loc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Import Failed', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/inventory'),
              child: Text(loc.tr('cancel')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(AppLocalizations loc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 80, height: 80,
              child: CircularProgressIndicator(
                value: _mergeProgress,
                strokeWidth: 6,
              ),
            ),
            const SizedBox(height: 24),
            Text(_mergeStatus, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('${(_mergeProgress * 100).toInt()}%', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(AppLocalizations loc, ThemeData theme) {
    final diff = _diff!;

    return Column(
      children: [
        // Header info
        if (_manifest != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.primaryContainer.withAlpha(50),
            child: Row(
              children: [
                Icon(Icons.backup, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_manifest!.shopName.isNotEmpty ? _manifest!.shopName : 'Unknown Shop',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${_manifest!.sections.length} sections · ${_formatDate(_manifest!.createdAt)}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Master toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Checkbox(
                value: _allSelected,
                tristate: true,
                onChanged: (_) => _toggleAll(),
              ),
              GestureDetector(
                onTap: _toggleAll,
                child: Text(loc.tr('select_all'), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              if (diff.isEmpty)
                Text('Nothing to import', style: TextStyle(color: Colors.orange[600], fontWeight: FontWeight.w600))
              else
                Text('${_selectedCount(diff)} items selected',
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),

        const Divider(height: 1),

        // Expandable sections
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              // Invoices section
              if (diff.totalIncomingInvoices > 0)
                _buildSection(
                  title: loc.tr('new_invoices'),
                  count: diff.newInvoiceCount,
                  total: diff.totalIncomingInvoices,
                  value: _mergeInvoices,
                  onChanged: (v) => setState(() => _mergeInvoices = v ?? false),
                  icon: Icons.receipt_long,
                  color: Colors.blue,
                  children: diff.newInvoices
                      .where((d) => !d.alreadyExists)
                      .take(20) // Show first 20
                      .map((inv) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.receipt, size: 16),
                            title: Text('#${inv.invoice.invoiceNumber}',
                                style: const TextStyle(fontSize: 13)),
                            subtitle: Text(
                              '${inv.items.length} items · ${inv.invoice.totalAmount.toStringAsFixed(0)} DZD',
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                            ),
                            trailing: Text(
                              '${inv.invoice.date.day}/${inv.invoice.date.month}/${inv.invoice.date.year}',
                              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                            ),
                          ))
                      .toList(),
                ),

              // Products section
              if (diff.productChanges.isNotEmpty)
                _buildSection(
                  title: loc.tr('product_changes'),
                  count: diff.productChanges.length,
                  total: diff.totalIncomingProducts,
                  value: _mergeProducts,
                  onChanged: (v) => setState(() => _mergeProducts = v ?? false),
                  icon: Icons.inventory_2,
                  color: Colors.green,
                  children: [
                    // Sub-toggles for prices and stock
                    if (diff.modifiedProductCount > 0) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _updatePrices,
                              onChanged: (v) => setState(() => _updatePrices = v ?? false),
                            ),
                            const Text('Update Prices', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 8),
                            Checkbox(
                              value: _updateStock,
                              onChanged: (v) => setState(() => _updateStock = v ?? false),
                            ),
                            const Text('Update Stock', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                    // Product list
                    ...diff.productChanges.take(20).map((pd) {
                      final isNew = pd.isNew;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isNew ? Icons.add_circle : Icons.edit,
                          size: 16,
                          color: isNew ? Colors.green : Colors.orange,
                        ),
                        title: Text(pd.incoming.name, style: const TextStyle(fontSize: 13)),
                        subtitle: isNew
                            ? Text('${pd.incoming.price.toStringAsFixed(0)} DZD · Stock: ${pd.incoming.stock}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]))
                            : _buildPriceChangeRow(pd),
                      );
                    }),
                    if (diff.productChanges.length > 20)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('... and ${diff.productChanges.length - 20} more',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ),
                  ],
                ),

              // Customers section
              if (diff.customerChanges.isNotEmpty)
                _buildSection(
                  title: loc.tr('customer_changes'),
                  count: diff.customerChanges.length,
                  total: diff.totalIncomingCustomers,
                  value: _mergeCustomers,
                  onChanged: (v) => setState(() => _mergeCustomers = v ?? false),
                  icon: Icons.people,
                  color: Colors.purple,
                  children: diff.customerChanges.take(20).map((cd) {
                    final isNew = cd.existing == null;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isNew ? Icons.person_add : Icons.person,
                        size: 16,
                        color: isNew ? Colors.green : Colors.purple,
                      ),
                      title: Text(cd.incoming.name, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        isNew ? 'New customer' : 'Already exists',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    );
                  }).toList(),
                ),

              // Categories section
              if (diff.newCategories.isNotEmpty)
                _buildSection(
                  title: loc.tr('new_categories'),
                  count: diff.newCategoryCount,
                  total: diff.newCategoryCount,
                  value: _mergeCategories,
                  onChanged: (v) => setState(() => _mergeCategories = v ?? false),
                  icon: Icons.category,
                  color: Colors.teal,
                  children: diff.newCategories.map((cat) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.label, size: 16),
                        title: Text(cat.name, style: const TextStyle(fontSize: 13)),
                      )).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required int count,
    required int total,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        leading: Icon(icon, color: color, size: 20),
        title: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$count/$total', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        children: children,
      ),
    );
  }

  Widget _buildPriceChangeRow(ProductDiff pd) {
    if (pd.existing == null) return const SizedBox();
    final priceUp = pd.incoming.price > pd.existing!.price;
    return Row(
      children: [
        Text('${pd.existing!.price.toStringAsFixed(0)}', style: TextStyle(
          fontSize: 11, color: Colors.grey[500],
          decoration: TextDecoration.lineThrough,
        )),
        const SizedBox(width: 4),
        Icon(priceUp ? Icons.arrow_upward : Icons.arrow_downward, size: 12,
            color: priceUp ? Colors.red : Colors.green),
        Text('${pd.incoming.price.toStringAsFixed(0)} DZD', style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: priceUp ? Colors.red : Colors.green,
        )),
        if (pd.type == DiffType.bothChanged || pd.type == DiffType.stockChanged) ...[
          const SizedBox(width: 8),
          Text('Stock: ${pd.existing!.stock}→${pd.incoming.stock}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ],
    );
  }

  int _selectedCount(ImportDiff diff) {
    int count = 0;
    if (_mergeInvoices) count += diff.newInvoiceCount;
    if (_mergeProducts) count += diff.productChanges.length;
    if (_mergeCustomers) count += diff.customerChanges.length;
    if (_mergeCategories) count += diff.newCategoryCount;
    return count;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    if (_stagingDbPath != null) {
      BackupService.instance.cleanupStaging(_stagingDbPath!);
    }
    super.dispose();
  }
}
