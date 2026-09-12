import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../services/database_service.dart';
import '../../l10n/app_localizations.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  MobileScannerController? _scannerController;
  bool _isScannerActive = false;
  Product? _editingProduct;
  String? _barcode;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final products = await DatabaseService.instance.getProducts();
    if (!mounted) return;
    setState(() {
      _products = products;
      _filteredProducts = products;
      _isLoading = false;
    });
  }

  void _filterProducts(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filteredProducts = q.isEmpty
          ? _products
          : _products.where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.barcode.toLowerCase().contains(q)).toList();
    });
  }

  void _startScanner() {
    _scannerController?.dispose();
    _scannerController = MobileScannerController(facing: CameraFacing.back);
    setState(() => _isScannerActive = true);
  }

  void _stopScanner() {
    _scannerController?.dispose();
    _scannerController = null;
    setState(() => _isScannerActive = false);
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code == null) continue;
      _stopScanner();
      final existing = _products.where((p) => p.barcode == code).firstOrNull;
      if (existing != null) {
        _showEditDialog(product: existing);
      } else {
        _showAddDialog(barcode: code);
      }
    }
  }

  // CSV Export - uses manual CSV string
  Future<void> _exportCSV() async {
    final loc = AppLocalizations.of(context);
    try {
      // Build CSV manually without csv package
      final sb = StringBuffer();
      sb.writeln('name,price,stock,barcode,tvaRate,description');
      for (var p in _products) {
        sb.writeln('${p.name},${p.price},${p.stock},${p.barcode},${p.tvaRate},${p.description}');
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/products.csv');
      await file.writeAsString(sb.toString());
      await Share.shareXFiles([XFile(file.path)], text: 'products.csv');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.tr('export_success')),
          backgroundColor: Colors.green[600],
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.tr('export_error')),
          backgroundColor: Colors.red[600],
        ));
      }
    }
  }

  // CSV Import - uses file picker
  Future<void> _importCSV() async {
    final loc = AppLocalizations.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(loc.tr('import_error')),
            backgroundColor: Colors.orange[600],
          ));
        }
        return;
      }

      final csvContent = await File(file.path!).readAsString();

      // Parse CSV manually
      final lines = csvContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length < 2) return;
      // Skip header
      final maps = <Map<String, dynamic>>[];
      for (var i = 1; i < lines.length; i++) {
        final cols = lines[i].split(',');
        if (cols.length < 4) continue;
        maps.add({
          'name': cols[0].trim(),
          'price': double.tryParse(cols[1].trim()) ?? 0,
          'stock': int.tryParse(cols[2].trim()) ?? 0,
          'barcode': cols[3].trim(),
          'tvaRate': cols.length > 4 ? double.tryParse(cols[4].trim()) ?? 0.0 : 0.0,
          'description': cols.length > 5 ? cols[5].trim() : '',
        });
      }

      await DatabaseService.instance.importProductsFromMaps(maps);
      await _loadProducts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.tr('import_success')),
          backgroundColor: Colors.green[600],
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.tr('import_error')),
          backgroundColor: Colors.red[600],
        ));
      }
    }
  }

  // Import .abp backup file
  Future<void> _importBackup() async {
    final loc = AppLocalizations.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['abp', 'zip'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(loc.tr('import_error')),
            backgroundColor: Colors.orange[600],
          ));
        }
        return;
      }

      // Navigate to import preview screen
      if (mounted) {
        context.push('/import-preview', extra: file.path!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.tr('import_error')),
          backgroundColor: Colors.red[600],
        ));
      }
    }
  }

  Future<void> _showAddDialog({String? barcode}) async {
    _editingProduct = null;
    _barcode = barcode;
    await _showProductDialog();
  }

  Future<void> _showEditDialog({Product? product}) async {
    _editingProduct = product;
    _barcode = product?.barcode;
    await _showProductDialog();
  }

  Future<void> _showProductDialog() async {
    final loc = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: _editingProduct?.name ?? '');
    final priceCtrl = TextEditingController(text: _editingProduct?.price.toString() ?? '');
    final stockCtrl = TextEditingController(text: _editingProduct?.stock.toString() ?? '');
    final codeCtrl = TextEditingController(text: _barcode ?? _editingProduct?.barcode ?? '');
    final formKey = GlobalKey<FormState>();
    final isEdit = _editingProduct != null;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? loc.tr('edit_product') : loc.tr('add_product')),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: loc.tr('product_name')),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => v == null || v.trim().isEmpty ? loc.tr('name_required') : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: priceCtrl,
                  decoration: InputDecoration(labelText: loc.tr('product_price'), suffixText: loc.tr('currency')),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                  validator: (v) => v == null || v.trim().isEmpty ? loc.tr('price_required') : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: stockCtrl,
                  decoration: InputDecoration(labelText: loc.tr('stock')),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => v == null || v.trim().isEmpty ? loc.tr('stock_required') : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: codeCtrl,
                        decoration: InputDecoration(labelText: loc.tr('product_barcode')),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        enabled: !isEdit,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () { Navigator.pop(ctx); _startScanner(); },
                      icon: const Icon(Icons.qr_code_scanner),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.tr('cancel'))),
          ElevatedButton(
            onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); },
            child: Text(isEdit ? loc.tr('save') : loc.tr('add')),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final name = nameCtrl.text.trim();
      final price = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
      final stock = int.tryParse(stockCtrl.text) ?? 0;
      final barcode = codeCtrl.text.trim();

      if (isEdit && _editingProduct != null) {
        final updated = Product(
          id: _editingProduct!.id, name: name, price: price,
          barcode: barcode, stock: stock, tvaRate: _editingProduct!.tvaRate,
        );
        await DatabaseService.instance.updateProduct(updated);
      } else {
        final product = Product(name: name, price: price, barcode: barcode, stock: stock);
        await DatabaseService.instance.insertProduct(product);
      }
      await _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) context.go('/'); },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/')),
          title: Text(loc.tr('inventory')),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                if (v == 'export') _exportCSV();
                if (v == 'import') _importCSV();
                if (v == 'scan') _startScanner();
                if (v == 'export_backup') context.push('/export-settings');
                if (v == 'import_backup') _importBackup();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'export', child: Text(loc.tr('export_csv'))),
                PopupMenuItem(value: 'import', child: Text(loc.tr('import_csv'))),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'export_backup', child: Text(loc.tr('export_backup'))),
                PopupMenuItem(value: 'import_backup', child: Text(loc.tr('import_backup'))),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'scan', child: Text(loc.tr('add_product_by_scan'))),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            if (_isScannerActive) _buildScanner(loc),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _filterProducts,
                decoration: InputDecoration(
                  hintText: loc.tr('search'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 18),
                          onPressed: () { _searchController.clear(); _filterProducts(''); })
                      : null,
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredProducts.isEmpty
                      ? Center(child: Text(loc.tr('no_products')))
                      : RefreshIndicator(
                          onRefresh: _loadProducts,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredProducts.length,
                            itemBuilder: (_, i) => _buildTile(_filteredProducts[i], loc),
                          ),
                        ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddDialog(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildScanner(AppLocalizations loc) {
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          if (_scannerController != null)
            MobileScanner(controller: _scannerController!, onDetect: _onBarcodeDetected),
          Center(
            child: Container(
              width: 260, height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            top: 8, right: 8,
            child: IconButton(
              onPressed: _stopScanner,
              icon: const Icon(Icons.close, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(Product product, AppLocalizations loc) {
    final isLow = product.stock > 0 && product.stock <= 5;
    final isOut = product.stock == 0;
    final stockColor = isOut ? Colors.red : isLow ? Colors.orange : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(20),
          child: Icon(Icons.inventory_2_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            Text('${product.price.toStringAsFixed(0)} ${loc.tr('currency')}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            if (product.barcode.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(product.barcode, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: stockColor.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isOut ? loc.tr('out_of_stock') : '${product.stock}',
                style: TextStyle(color: stockColor, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _showEditDialog(product: product);
                if (v == 'delete') _confirmDelete(product, loc);
                if (v == 'cart') {
                  ref.read(cartProvider.notifier).addItem(product);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${product.name} ✓'), backgroundColor: Colors.green[600],
                  ));
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'cart', child: Text(loc.tr('add_to_cart'))),
                PopupMenuItem(value: 'edit', child: Text(loc.tr('edit'))),
                PopupMenuItem(value: 'delete', child: Text(loc.tr('delete'), style: TextStyle(color: Colors.red[600]))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Product product, AppLocalizations loc) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.tr('delete')),
        content: Text('${loc.tr('delete')} "${product.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.tr('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600]),
            child: Text(loc.tr('delete')),
          ),
        ],
      ),
    );
    if (result == true && product.id != null) {
      await DatabaseService.instance.deleteProduct(product.id!);
      await _loadProducts();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }
}
