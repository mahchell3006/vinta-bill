import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/invoice.dart';
import '../../providers/cart_provider.dart';
import '../../services/database_service.dart';
import '../../services/printer_service.dart';
import '../../l10n/app_localizations.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _paymentMethod = 'cash';
  bool _isProcessing = false;
  bool _printEnabled = true;

  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final cn = ref.read(cartProvider.notifier);
    final loc = AppLocalizations.of(context);
    final grandTotal = cn.grandTotal;
    final isCredit = _paymentMethod == 'credit';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) context.go('/pos'); },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/pos')),
          title: Text(loc.tr('checkout')),
        ),
        body: cart.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(loc.tr('empty_cart'), style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Order summary
                  Card(child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.tr('order_summary'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        ...cart.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text('${item.quantity}× ${item.product.name}', style: const TextStyle(fontSize: 13))),
                              Text('${item.subtotal.toStringAsFixed(0)} ${loc.tr('currency')}', style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        )),
                      ],
                    ),
                  )),
                  const SizedBox(height: 12),

                  // Payment method
                  Card(child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.tr('payment_method'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _paymentOption('cash', loc.tr('cash'), Icons.money)),
                            const SizedBox(width: 8),
                            Expanded(child: _paymentOption('card', loc.tr('card'), Icons.credit_card)),
                            const SizedBox(width: 8),
                            Expanded(child: _paymentOption('credit', loc.tr('credit'), Icons.account_balance_wallet)),
                          ],
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 12),

                  // Credit fields
                  if (isCredit) ...[
                    Card(child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(loc.tr('credit_customer_info'), style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _customerNameController,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(labelText: loc.tr('customer_name')),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _customerPhoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(labelText: loc.tr('customer_phone')),
                          ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 12),
                  ],

                  // Print option
                  Card(child: SwitchListTile(
                    title: Text(loc.tr('print_receipt')),
                    secondary: Icon(Icons.print, color: Theme.of(context).colorScheme.primary),
                    value: _printEnabled,
                    onChanged: (v) => setState(() => _printEnabled = v),
                  )),
                  const SizedBox(height: 16),

                  // Total
                  Card(child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(loc.tr('grand_total'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            Text('${grandTotal.toStringAsFixed(0)} ${loc.tr('currency')}',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Theme.of(context).colorScheme.primary)),
                          ],
                        ),
                        if (isCredit) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(loc.tr('remaining'), style: TextStyle(color: Colors.red[600])),
                              Text('${grandTotal.toStringAsFixed(0)} ${loc.tr('currency')}',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red[600])),
                            ],
                          ),
                        ],
                      ],
                    ),
                  )),
                  const SizedBox(height: 16),

                  // Save button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _saveInvoice,
                      child: _isProcessing
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(loc.tr('save_invoice')),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
      ),
    );
  }

  Widget _paymentOption(String value, String label, IconData icon) {
    final isSelected = _paymentMethod == value;
    final theme = Theme.of(context);
    return Material(
      color: isSelected ? theme.colorScheme.primary.withAlpha(15) : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? theme.colorScheme.primary : Colors.grey[300]!, width: isSelected ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? theme.colorScheme.primary : Colors.grey),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveInvoice() async {
    final loc = AppLocalizations.of(context);
    final cn = ref.read(cartProvider.notifier);
    final cartItems = ref.read(cartProvider);

    if (cartItems.isEmpty) return;

    if (_paymentMethod == 'credit' && _customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(loc.tr('name_required')),
        backgroundColor: Colors.red[600],
      ));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final totalAmount = cn.grandTotal;
      final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch}';

      final invoice = Invoice(
        invoiceNumber: invoiceNumber,
        date: DateTime.now(),
        totalAmount: totalAmount,
        paymentMethod: _paymentMethod,
        customerName: _paymentMethod == 'credit' ? _customerNameController.text.trim() : '',
        customerPhone: _paymentMethod == 'credit' ? _customerPhoneController.text.trim() : '',
        paidAmount: _paymentMethod == 'credit' ? 0.0 : totalAmount,
        isPaid: _paymentMethod != 'credit',
      );

      final items = cartItems.map((ci) => InvoiceItem(
        productId: ci.product.id ?? 0,
        productName: ci.product.name,
        quantity: ci.quantity,
        price: ci.product.price,
      )).toList();

      await DatabaseService.instance.insertInvoice(invoice, items);

      // Stock update
      for (final ci in cartItems) {
        if (ci.product.id != null) {
          await DatabaseService.instance.updateProductStock(ci.product.id!, -ci.quantity);
        }
      }

      // Print receipt (fire and forget, don't block checkout)
      if (_printEnabled) {
        PrinterService.instance.printReceipt(
          cartItems, cn,
          customerName: _paymentMethod == 'credit' ? _customerNameController.text.trim() : null,
          paymentMethod: _paymentMethod,
        ).catchError((_) {}); // Don't let print errors block checkout
      }

      // Clear cart and navigate immediately
      cn.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.tr('success')),
          backgroundColor: Colors.green[600],
        ));
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${loc.tr('error')}: $e'),
          backgroundColor: Colors.red[600],
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
