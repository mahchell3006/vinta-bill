import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/backup_service.dart';
import '../../l10n/app_localizations.dart';

class ExportSettingsScreen extends StatefulWidget {
  const ExportSettingsScreen({super.key});

  @override
  State<ExportSettingsScreen> createState() => _ExportSettingsScreenState();
}

class _ExportSettingsScreenState extends State<ExportSettingsScreen> {
  bool _exportInvoices = true;
  bool _exportProducts = true;
  bool _exportCustomers = true;
  bool _exportCategories = true;

  bool _isExporting = false;

  List<String> get _selectedSections {
    final sections = <String>[];
    if (_exportInvoices) sections.add('invoices');
    if (_exportProducts) sections.add('products');
    if (_exportCustomers) sections.add('customers');
    if (_exportCategories) sections.add('categories');
    return sections;
  }

  void _applyPreset(String preset) {
    setState(() {
      switch (preset) {
        case 'full':
          _exportInvoices = true;
          _exportProducts = true;
          _exportCustomers = true;
          _exportCategories = true;
          break;
        case 'sales':
          _exportInvoices = true;
          _exportProducts = false;
          _exportCustomers = false;
          _exportCategories = false;
          break;
        case 'inventory':
          _exportInvoices = false;
          _exportProducts = true;
          _exportCustomers = false;
          _exportCategories = true;
          break;
        case 'customers':
          _exportInvoices = false;
          _exportProducts = false;
          _exportCustomers = true;
          _exportCategories = false;
          break;
      }
    });
  }

  Future<void> _exportBackup() async {
    final sections = _selectedSections;
    if (sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Select at least one section to export'),
        backgroundColor: Colors.orange[600],
      ));
      return;
    }

    final loc = AppLocalizations.of(context);

    setState(() => _isExporting = true);

    try {
      final file = await BackupService.instance.createBackup(sections: sections);

      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'backup_${DateTime.now().millisecondsSinceEpoch}.abp',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.tr('export_success')),
          backgroundColor: Colors.green[600],
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export failed: $e'),
        backgroundColor: Colors.red[600],
      ));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.tr('export_settings')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Quick presets
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick Presets', style: TextStyle(
                  fontWeight: FontWeight.w700, color: Colors.grey[700], fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _presetChip('Full Backup', 'full', Icons.backup),
                    _presetChip('Sales Only', 'sales', Icons.receipt_long),
                    _presetChip('Inventory', 'inventory', Icons.inventory_2),
                    _presetChip('Customers', 'customers', Icons.people),
                  ],
                ),
              ],
            ),
          ),

          // Custom selection
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Custom Selection', style: TextStyle(
              fontWeight: FontWeight.w700, color: Colors.grey[700], fontSize: 13)),
          ),

          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(Icons.receipt_long, color: Colors.blue),
                  title: const Text('Invoices & Sales'),
                  subtitle: const Text('All invoices, items, and transactions'),
                  value: _exportInvoices,
                  onChanged: (v) => setState(() => _exportInvoices = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: Icon(Icons.inventory_2, color: Colors.green),
                  title: const Text('Products & Inventory'),
                  subtitle: const Text('All products with prices and stock'),
                  value: _exportProducts,
                  onChanged: (v) => setState(() => _exportProducts = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: Icon(Icons.people, color: Colors.purple),
                  title: const Text('Customers & Debt'),
                  subtitle: const Text('Customer records and credit balances'),
                  value: _exportCustomers,
                  onChanged: (v) => setState(() => _exportCustomers = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: Icon(Icons.category, color: Colors.teal),
                  title: const Text('Categories'),
                  subtitle: const Text('Product categories'),
                  value: _exportCategories,
                  onChanged: (v) => setState(() => _exportCategories = v),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Export button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _exportBackup,
                icon: _isExporting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download),
                label: Text(_isExporting ? 'Exporting...' : loc.tr('export_backup')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, String preset, IconData icon) {
    final isActive = _isPresetActive(preset);
    return ActionChip(
      avatar: Icon(icon, size: 16, color: isActive ? Colors.white : Colors.grey[600]),
      label: Text(label, style: TextStyle(
        color: isActive ? Colors.white : Colors.grey[700],
        fontWeight: FontWeight.w600,
        fontSize: 12,
      )),
      backgroundColor: isActive ? Theme.of(context).colorScheme.primary : Colors.grey[200],
      onPressed: () => _applyPreset(preset),
    );
  }

  bool _isPresetActive(String preset) {
    switch (preset) {
      case 'full':
        return _exportInvoices && _exportProducts && _exportCustomers && _exportCategories;
      case 'sales':
        return _exportInvoices && !_exportProducts && !_exportCustomers && !_exportCategories;
      case 'inventory':
        return !_exportInvoices && _exportProducts && !_exportCustomers && _exportCategories;
      case 'customers':
        return !_exportInvoices && !_exportProducts && _exportCustomers && !_exportCategories;
      default:
        return false;
    }
  }
}
