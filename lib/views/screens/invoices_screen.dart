import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/invoice.dart';
import '../../models/cart_item.dart';
import '../../models/product.dart';
import '../../services/database_service.dart';
import '../../services/pdf_service.dart';
import '../../services/printer_service.dart';
import '../../providers/cart_provider.dart';
import '../../l10n/app_localizations.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  List<Invoice> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    final invoices = await DatabaseService.instance.getInvoices();
    if (!mounted) return;
    setState(() {
      _invoices = invoices;
      _isLoading = false;
    });
  }

  // Convert InvoiceItem list to CartItem list for printer
  Future<List<CartItem>> _itemsToCartItems(List<InvoiceItem> items) async {
    final cartItems = <CartItem>[];
    for (final item in items) {
      final product = await DatabaseService.instance.getProductById(item.productId);
      if (product != null) {
        for (int i = 0; i < item.quantity; i++) {
          cartItems.add(CartItem(product: product));
        }
      } else {
        // Product deleted - create temp product
        final temp = Product(name: item.productName, price: item.price, barcode: '', stock: 0);
        for (int i = 0; i < item.quantity; i++) {
          cartItems.add(CartItem(product: temp));
        }
      }
    }
    return cartItems;
  }

  // Print receipt for an invoice
  Future<void> _printInvoice(Invoice invoice) async {
    final loc = AppLocalizations.of(context);
    final items = await DatabaseService.instance.getInvoiceItems(invoice.id!);
    final cartItems = await _itemsToCartItems(items);

    try {
      final cn = ref.read(cartProvider.notifier);
      await PrinterService.instance.printReceipt(
        cartItems, cn,
        customerName: invoice.customerName.isNotEmpty ? invoice.customerName : null,
        paymentMethod: invoice.paymentMethod,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.tr('print_success')),
          backgroundColor: Colors.green[600],
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${loc.tr('print_error')}: $e'),
          backgroundColor: Colors.red[600],
        ));
      }
    }
  }

  // Download PDF for an invoice
  Future<void> _downloadPdf(Invoice invoice) async {
    final loc = AppLocalizations.of(context);
    final items = await DatabaseService.instance.getInvoiceItems(invoice.id!);
    final cartItems = await _itemsToCartItems(items);

    try {
      final shop = await DatabaseService.instance.getShop();
      final pdfBytes = await PdfService.generatePdfBytes(
        shop: shop,
        cart: cartItems,
        totalAmount: invoice.totalAmount,
        paymentMethod: invoice.paymentMethod,
        customerName: invoice.customerName.isNotEmpty ? invoice.customerName : null,
        invoiceNumber: invoice.invoiceNumber,
        date: invoice.date,
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/invoice_${invoice.id}.pdf');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'invoice_${invoice.id}.pdf');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.tr('success')),
          backgroundColor: Colors.green[600],
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${loc.tr('error')}: $e'),
          backgroundColor: Colors.red[600],
        ));
      }
    }
  }

  void _showInvoiceDetails(Invoice invoice) {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('#${invoice.id ?? "?"}', style: Theme.of(context).textTheme.titleLarge),
                          Text(DateFormat('dd/MM/yyyy HH:mm').format(invoice.date),
                              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ),
                    _paymentBadge(invoice.paymentMethod, loc),
                  ],
                ),
              ),
              const Divider(),
              if (invoice.customerName.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  color: Colors.orange[50],
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 6),
                      Text(invoice.customerName, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange[700])),
                      if (invoice.customerPhone.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(invoice.customerPhone, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              Expanded(
                child: FutureBuilder<List<InvoiceItem>>(
                  future: DatabaseService.instance.getInvoiceItems(invoice.id!),
                  builder: (_, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final items = snapshot.data!;
                    return ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final item = items[i];
                        return ListTile(
                          dense: true,
                          title: Text(item.productName),
                          subtitle: Text('${item.quantity}× ${item.price.toStringAsFixed(0)}'),
                          trailing: Text('${item.subtotal.toStringAsFixed(0)} ${loc.tr('currency')}'),
                        );
                      },
                    );
                  },
                ),
              ),
              // Action buttons + total
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE8EAED)))),
                child: Column(
                  children: [
                    // Print & PDF buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () { Navigator.pop(ctx); _printInvoice(invoice); },
                            icon: const Icon(Icons.print, size: 18),
                            label: Text(loc.tr('print_receipt')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () { Navigator.pop(ctx); _downloadPdf(invoice); },
                            icon: const Icon(Icons.download, size: 18),
                            label: Text('PDF'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(loc.tr('grand_total'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${invoice.totalAmount.toStringAsFixed(0)} ${loc.tr('currency')}',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Theme.of(context).colorScheme.primary)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentBadge(String method, AppLocalizations loc) {
    final isCredit = method == 'credit';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isCredit ? Colors.orange[100] : Colors.green[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(loc.tr(method), style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: isCredit ? Colors.orange[700] : Colors.green[700],
      )),
    );
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
          title: Text(loc.tr('invoices')),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _invoices.isEmpty
                ? Center(child: Text(loc.tr('no_invoices')))
                : RefreshIndicator(
                    onRefresh: _loadInvoices,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _invoices.length,
                      itemBuilder: (_, i) {
                        final invoice = _invoices[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: () => _showInvoiceDetails(invoice),
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(20),
                              child: Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.primary, size: 20),
                            ),
                            title: Row(
                              children: [
                                Text('#${invoice.id ?? "?"}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(width: 8),
                                _paymentBadge(invoice.paymentMethod, loc),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(DateFormat('dd/MM/yyyy HH:mm').format(invoice.date),
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                if (invoice.customerName.isNotEmpty)
                                  Text(invoice.customerName,
                                      style: TextStyle(color: Colors.orange[600], fontSize: 11)),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Print button
                                IconButton(
                                  onPressed: () => _printInvoice(invoice),
                                  icon: Icon(Icons.print, size: 20, color: Theme.of(context).colorScheme.primary),
                                  tooltip: loc.tr('print_receipt'),
                                ),
                                // PDF button
                                IconButton(
                                  onPressed: () => _downloadPdf(invoice),
                                  icon: Icon(Icons.picture_as_pdf, size: 20, color: Colors.red[600]),
                                  tooltip: 'PDF',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
