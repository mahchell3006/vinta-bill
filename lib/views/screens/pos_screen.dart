import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/product.dart';
import '../../models/cart_item.dart';
import '../../providers/cart_provider.dart';
import '../../services/database_service.dart';
import '../../l10n/app_localizations.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  bool _isScannerActive = false;
  MobileScannerController? _scannerController;
  final Set<String> _scannedBarcodes = {};

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
    _scannedBarcodes.clear();
    _scannerController?.dispose();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
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
      if (code == null || _scannedBarcodes.contains(code)) continue;
      _scannedBarcodes.add(code);

      final product = _products.where((p) => p.barcode == code).firstOrNull;
      if (product != null) {
        ref.read(cartProvider.notifier).addItem(product);
        _showSnack('${product.name} ✓', isError: false);
      } else {
        _showUnknownProductDialog(code);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red[600] : Colors.green[600],
      duration: const Duration(seconds: 1),
    ));
  }

  Future<void> _showUnknownProductDialog(String barcode) async {
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(loc.tr('product_not_found')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${loc.tr('product_barcode')}: $barcode',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: loc.tr('product_name')),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => v == null || v.trim().isEmpty ? loc.tr('name_required') : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceCtrl,
                decoration: InputDecoration(
                  labelText: loc.tr('product_price'),
                  suffixText: loc.tr('currency'),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                validator: (v) => v == null || v.trim().isEmpty ? loc.tr('price_required') : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.tr('cancel'))),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: Text(loc.tr('add_to_cart')),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final price = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
      final product = Product(name: nameCtrl.text.trim(), price: price, barcode: barcode, stock: 0);
      ref.read(cartProvider.notifier).addItem(product);
      _showSnack('${loc.tr('add_to_cart')}: ${product.name}', isError: false);

      final save = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(loc.tr('add_product')),
          content: Text('${loc.tr('save')} "${product.name}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.tr('cancel'))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(loc.tr('yes'))),
          ],
        ),
      );
      if (save == true) {
        await DatabaseService.instance.insertProduct(product);
        await _loadProducts();
      }
    }
  }

  void _showCartSheet() {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollCtrl) => Consumer(
          builder: (_, ref, __) {
            final cart = ref.watch(cartProvider);
            final cn = ref.read(cartProvider.notifier);
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      children: [
                        Text(loc.tr('cart'), style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${cn.totalItems}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const Spacer(),
                        Text(
                          '${cn.grandTotal.toStringAsFixed(0)} ${loc.tr('currency')}',
                          style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: cart.isEmpty
                        ? Center(child: Text(loc.tr('empty_cart'), style: TextStyle(color: Colors.grey[400])))
                        : ListView.separated(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: cart.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 4),
                            itemBuilder: (_, i) {
                              final item = cart[i];
                              return _CartItemTile(
                                item: item,
                                onIncrement: () => cn.updateQuantity(item.product.id ?? -1, item.quantity + 1),
                                onDecrement: () => cn.updateQuantity(item.product.id ?? -1, item.quantity - 1),
                                onRemove: () => cn.removeItem(item.product.id ?? -1),
                              );
                            },
                          ),
                  ),
                  if (cart.isNotEmpty)
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity, height: 52,
                          child: ElevatedButton(
                            onPressed: () { Navigator.pop(ctx); context.go('/checkout'); },
                            child: Text('${loc.tr('checkout')} · ${cn.grandTotal.toStringAsFixed(0)} ${loc.tr('currency')}'),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cart = ref.watch(cartProvider);
    final cn = ref.read(cartProvider.notifier);
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 700;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) context.go('/'); },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/')),
          title: Text(loc.tr('pos')),
          actions: [
            IconButton(
              onPressed: _isScannerActive ? _stopScanner : _startScanner,
              icon: Icon(_isScannerActive ? Icons.stop_circle : Icons.qr_code_scanner,
                  color: _isScannerActive ? Colors.red : null),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_isScannerActive) _buildScanner(loc),
            Expanded(child: isWide ? _wideLayout(loc, cart, cn) : _narrowLayout(loc)),
          ],
        ),
        bottomNavigationBar: isWide ? null : _mobileBar(loc, cart, cn),
      ),
    );
  }

  Widget _buildScanner(AppLocalizations loc) {
    return SizedBox(
      height: 180,
      child: Stack(
        children: [
          if (_scannerController != null)
            MobileScanner(controller: _scannerController!, onDetect: _onBarcodeDetected),
          Center(
            child: Container(
              width: 240, height: 100,
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

  Widget _wideLayout(AppLocalizations loc, List<CartItem> cart, CartNotifier cn) {
    return Row(
      children: [
        Expanded(flex: 3, child: _productGrid(loc)),
        const VerticalDivider(width: 1),
        Expanded(flex: 2, child: _sideCart(loc, cart, cn)),
      ],
    );
  }

  Widget _narrowLayout(AppLocalizations loc) => _productGrid(loc);

  Widget _mobileBar(AppLocalizations loc, List<CartItem> cart, CartNotifier cn) {
    if (cart.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE8EAED))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _showCartSheet,
            icon: Icon(Icons.shopping_cart, color: theme.colorScheme.primary),
          ),
          Text('${cn.totalItems}', style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(loc.tr('total'), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                Text('${cn.grandTotal.toStringAsFixed(0)} ${loc.tr('currency')}',
                    style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => context.go('/checkout'),
            child: Text(loc.tr('checkout')),
          ),
        ],
      ),
    );
  }

  Widget _productGrid(AppLocalizations loc) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: _filterProducts,
            decoration: InputDecoration(
              hintText: loc.tr('search'),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () { _searchController.clear(); _filterProducts(''); },
                    )
                  : null,
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(loc.tr('no_products'), style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.of(context).size.width > 800
                            ? 4
                            : MediaQuery.of(context).size.width > 500 ? 3 : 2,
                        childAspectRatio: 1.2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (_, i) => _ProductCard(
                        product: _filteredProducts[i],
                        onTap: () {
                          ref.read(cartProvider.notifier).addItem(_filteredProducts[i]);
                          _showSnack(_filteredProducts[i].name, isError: false);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _sideCart(AppLocalizations loc, List<CartItem> cart, CartNotifier cn) {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(loc.tr('cart'), style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${cn.totalItems}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: cart.isEmpty
                ? Center(child: Text(loc.tr('empty_cart'), style: TextStyle(color: Colors.grey[400])))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: cart.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final item = cart[i];
                      return _CartItemTile(
                        item: item,
                        onIncrement: () => cn.updateQuantity(item.product.id ?? -1, item.quantity + 1),
                        onDecrement: () => cn.updateQuantity(item.product.id ?? -1, item.quantity - 1),
                        onRemove: () => cn.removeItem(item.product.id ?? -1),
                      );
                    },
                  ),
          ),
          if (cart.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE8EAED)))),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(loc.tr('grand_total'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${cn.grandTotal.toStringAsFixed(0)} ${loc.tr('currency')}',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Theme.of(context).colorScheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: ElevatedButton(
                      onPressed: () => context.go('/checkout'),
                      child: Text(loc.tr('checkout')),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLowStock = product.stock > 0 && product.stock <= 5;
    final isOut = product.stock == 0;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined,
                      color: Theme.of(context).colorScheme.primary, size: 24),
                  const SizedBox(height: 8),
                  Text(product.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('${product.price.toStringAsFixed(0)} د.ج',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
            if (isLowStock || isOut)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isOut ? Colors.red[100] : Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOut ? '0' : '${product.stock}',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: isOut ? Colors.red[700] : Colors.orange[700],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _CartItemTile({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.product.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                    '${item.product.price.toStringAsFixed(0)} × ${item.quantity} = ${item.subtotal.toStringAsFixed(0)} د.ج',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: item.quantity > 1 ? onDecrement : onRemove,
                  icon: Icon(item.quantity > 1 ? Icons.remove : Icons.delete_outline,
                      size: 18, color: item.quantity > 1 ? null : Colors.red),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F4F6),
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text('${item.quantity}', textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  onPressed: onIncrement,
                  icon: const Icon(Icons.add, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F4F6),
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
