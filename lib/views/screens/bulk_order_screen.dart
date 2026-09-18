import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../models/purchase.dart';
import '../../services/database_service.dart';
import '../../l10n/app_localizations.dart';

class BulkOrderScreen extends ConsumerStatefulWidget {
  const BulkOrderScreen({super.key});

  @override
  ConsumerState<BulkOrderScreen> createState() => _BulkOrderScreenState();
}

class _BulkOrderScreenState extends ConsumerState<BulkOrderScreen> {
  // Search
  final _searchController = TextEditingController();
  List<Product> _searchResults = [];
  bool _isScannerActive = false;
  MobileScannerController? _scannerController;

  // Selected product for viewing history
  Product? _selectedProduct;
  List<Purchase> _purchaseHistory = [];

  @override
  void initState() {
    super.initState();
  }

  // ───────── Scanner ─────────

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
      _searchByBarcode(code);
    }
  }

  Future<void> _searchByBarcode(String barcode) async {
    final product = await DatabaseService.instance.getProductByBarcode(barcode);
    if (product != null) {
      _selectProduct(product);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Produit non trouvé: $barcode'),
        backgroundColor: Colors.orange[600],
      ));
    }
  }

  // ───────── Search ─────────

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results = await DatabaseService.instance.searchProducts(query);
    if (!mounted) return;
    setState(() => _searchResults = results);
  }

  Future<void> _selectProduct(Product product) async {
    _searchController.clear();
    final history = await DatabaseService.instance.getPurchasesByProduct(product.id!);
    if (!mounted) return;
    setState(() {
      _selectedProduct = product;
      _searchResults = [];
      _purchaseHistory = history;
    });
  }

  // ───────── Bulk Order Dialog ─────────

  Future<void> _showBulkOrderDialog() async {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // State for the dialog
    String orderName = '';
    int? selectedProductId;
    List<Product> allProducts = [];
    bool isPriceTotal = true;
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController();
    final convFactorController = TextEditingController(text: '6');
    final formKey = GlobalKey<FormState>();

    // Load all products for the dropdown
    allProducts = await DatabaseService.instance.getProducts();

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.add_shopping_cart, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(loc.tr('bulk_order'), style: const TextStyle(fontSize: 18)),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Name of the bulk order
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: loc.tr('bulk_order_name'),
                      hintText: loc.tr('bulk_order_name_hint'),
                      border: const OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (v) => orderName = v.trim(),
                    validator: (v) => v == null || v.trim().isEmpty ? loc.tr('name_required') : null,
                  ),
                  const SizedBox(height: 14),

                  // 2. Link to product (dropdown)
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      labelText: loc.tr('linked_product'),
                      hintText: loc.tr('linked_product_hint'),
                      border: const OutlineInputBorder(),
                    ),
                    initialValue: selectedProductId,
                    items: allProducts.map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Text('${p.name} (${p.price.toStringAsFixed(0)} ${loc.tr('currency')})',
                          style: const TextStyle(fontSize: 13)),
                    )).toList(),
                    onChanged: (v) {
                      setDialogState(() {
                        selectedProductId = v;
                        // Auto-fill conversion factor from product config
                        final p = allProducts.firstWhere((p) => p.id == v);
                        if (p.conversionFactor > 1) {
                          convFactorController.text = p.conversionFactor.toString();
                        }
                      });
                    },
                    validator: (v) => v == null ? loc.tr('linked_product_required') : null,
                  ),
                  const SizedBox(height: 14),

                  // 3. Total / Each toggle
                  Text(loc.tr('price'), style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700], fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => isPriceTotal = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isPriceTotal ? theme.colorScheme.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(loc.tr('price_mode_total'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 12,
                                    color: isPriceTotal ? Colors.white : Colors.grey[600],
                                  )),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => isPriceTotal = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isPriceTotal ? theme.colorScheme.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(loc.tr('price_mode_each'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 12,
                                    color: !isPriceTotal ? Colors.white : Colors.grey[600],
                                  )),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 4. Price input
                  TextFormField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                    decoration: InputDecoration(
                      hintText: isPriceTotal
                          ? loc.tr('bulk_order_price_total_hint')
                          : loc.tr('bulk_order_price_each_hint'),
                      suffixText: loc.tr('currency'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return loc.tr('price_required');
                      if ((double.tryParse(v.replaceAll(',', '.')) ?? 0) <= 0) return loc.tr('amount_invalid');
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // 5. How many packs + How many in each
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: loc.tr('how_many'),
                            hintText: '50',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n <= 0) return loc.tr('amount_invalid');
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: convFactorController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: loc.tr('how_many_in_name'),
                            hintText: '6',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n <= 0) return loc.tr('amount_invalid');
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  // Live preview
                  const SizedBox(height: 14),
                  _buildLivePreview(
                    qtyController, convFactorController, priceController,
                    isPriceTotal, theme, loc,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.tr('cancel')),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, {
                    'name': orderName,
                    'productId': selectedProductId,
                    'isPriceTotal': isPriceTotal,
                    'quantity': int.tryParse(qtyController.text) ?? 0,
                    'conversionFactor': int.tryParse(convFactorController.text) ?? 1,
                    'price': double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0,
                  });
                }
              },
              icon: const Icon(Icons.check),
              label: Text(loc.tr('confirm')),
            ),
          ],
        ),
      ),
    ).then((result) async {
      if (result != null && result is Map<String, dynamic>) {
        await _executeBulkOrder(result);
      }
    });
  }

  Widget _buildLivePreview(
    TextEditingController qtyCtrl,
    TextEditingController convCtrl,
    TextEditingController priceCtrl,
    bool isPriceTotal,
    ThemeData theme,
    AppLocalizations loc,
  ) {
    final qty = int.tryParse(qtyCtrl.text) ?? 0;
    final conv = int.tryParse(convCtrl.text) ?? 1;
    final price = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
    final totalUnits = qty * conv;
    final batchCost = isPriceTotal ? price : price * qty;
    final unitCost = totalUnits > 0 ? batchCost / totalUnits : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withAlpha(50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withAlpha(100)),
      ),
      child: Column(
        children: [
          Text(loc.tr('you_will_add').toUpperCase(), style: TextStyle(
              fontWeight: FontWeight.w800, color: theme.colorScheme.primary, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$qty', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: theme.colorScheme.primary)),
              Text(' packs = ', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              Text('$totalUnits', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: theme.colorScheme.primary)),
              Text(' u', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
          ),
          if (batchCost > 0) ...[
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(loc.tr('batch_cost'), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                Text('${batchCost.toStringAsFixed(0)} ${loc.tr('currency')}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(loc.tr('unit_cost'), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                Text('${unitCost.toStringAsFixed(1)} ${loc.tr('currency')}',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.green[700])),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _executeBulkOrder(Map<String, dynamic> data) async {
    final loc = AppLocalizations.of(context);
    try {
      await DatabaseService.instance.bulkOrder(
        productId: data['productId'],
        quantity: data['quantity'],
        totalCost: data['price'],
        conversionFactor: data['conversionFactor'],
        name: data['name'],
        isPriceTotal: data['isPriceTotal'],
      );

      // Reload product + history
      final updated = await DatabaseService.instance.getProductById(data['productId']);
      final history = await DatabaseService.instance.getPurchasesByProduct(data['productId']);

      if (!mounted) return;
      setState(() {
        _selectedProduct = updated;
        _purchaseHistory = history;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(loc.tr('bulk_order_success')),
        backgroundColor: Colors.green[600],
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${loc.tr('error')}: $e'),
        backgroundColor: Colors.red[600],
      ));
    }
  }

  // ───────── Build ─────────

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) context.go('/'); },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/')),
          title: Text(loc.tr('bulk_order')),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showBulkOrderDialog,
          tooltip: loc.tr('bulk_order_add'),
          child: const Icon(Icons.add),
        ),
        body: Column(
          children: [
            // Scanner
            if (_isScannerActive) _buildScanner(),

            // Product search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _searchProducts,
                decoration: InputDecoration(
                  hintText: loc.tr('search_product_hint'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(icon: const Icon(Icons.clear, size: 18),
                            onPressed: () { _searchController.clear(); _searchProducts(''); }),
                      IconButton(icon: const Icon(Icons.qr_code_scanner, size: 20),
                          onPressed: _startScanner),
                    ],
                  ),
                ),
              ),
            ),

            // Search results
            if (_searchResults.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (_, i) {
                    final p = _searchResults[i];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withAlpha(20),
                        child: Icon(Icons.inventory_2, size: 16, color: theme.colorScheme.primary),
                      ),
                      title: Text(p.name, style: const TextStyle(fontSize: 14)),
                      subtitle: Text(
                        '${p.price.toStringAsFixed(0)} ${loc.tr('currency')} · '
                        '${loc.tr('stock')}: ${p.stock} · '
                        '${p.packs} ${p.wholesaleUnitName.isNotEmpty ? p.wholesaleUnitName : loc.tr('packs_short')}',
                      ),
                      onTap: () => _selectProduct(p),
                    );
                  },
                ),
              ),

            // Selected product
            if (_selectedProduct != null) _buildSelectedProduct(loc, theme),

            // Purchase history
            if (_selectedProduct != null && _purchaseHistory.isNotEmpty)
              Expanded(
                child: _buildOrderHistory(loc, theme),
              ),

            // Empty state
            if (_selectedProduct == null && _searchResults.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(loc.tr('bulk_order'), style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(
                        loc.tr('bulk_order_empty_hint'),
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanner() {
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

  Widget _buildSelectedProduct(AppLocalizations loc, ThemeData theme) {
    final p = _selectedProduct!;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withAlpha(50),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withAlpha(20),
                child: Icon(Icons.inventory_2, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('${p.price.toStringAsFixed(0)} ${loc.tr('currency')}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() { _selectedProduct = null; _purchaseHistory = []; }),
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Stock breakdown
          Row(
            children: [
              _stockChip(
                '${p.packs}',
                p.wholesaleUnitName.isNotEmpty ? p.wholesaleUnitName : loc.tr('packs_short'),
                Colors.blue,
                theme,
              ),
              const SizedBox(width: 8),
              _stockChip(
                '${p.stock - (p.packs * (p.conversionFactor > 1 ? p.conversionFactor : 1))}',
                loc.tr('loose_units'),
                Colors.orange,
                theme,
              ),
              const SizedBox(width: 8),
              _stockChip(
                '${p.stock}',
                loc.tr('total_units'),
                Colors.green,
                theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stockChip(String value, String label, Color color, ThemeData theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHistory(AppLocalizations loc, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(loc.tr('bulk_order_history'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _purchaseHistory.length,
            itemBuilder: (_, i) {
              final p = _purchaseHistory[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[100],
                    child: Icon(Icons.local_shipping, size: 16, color: Colors.green[700]),
                  ),
                  title: Text(
                    '${p.quantityWholesaleUnits} ${loc.tr('packs_short')} · '
                    '${p.quantityRetailUnits} ${loc.tr('unit_short')} · '
                    '${p.totalCost.toStringAsFixed(0)} ${loc.tr('currency')}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${p.unitCost.toStringAsFixed(1)} ${loc.tr('currency')}/${loc.tr('unit_short')}'
                    '${p.wholesaleUnitName.isNotEmpty ? ' · ${p.wholesaleUnitName}' : ''}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  trailing: Text(
                    DateFormat('dd/MM').format(p.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }
}
