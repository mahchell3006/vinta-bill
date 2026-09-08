import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/invoice.dart';
import '../../services/database_service.dart';
import '../../l10n/app_localizations.dart';

class CreditClientsScreen extends ConsumerStatefulWidget {
  const CreditClientsScreen({super.key});

  @override
  ConsumerState<CreditClientsScreen> createState() => _CreditClientsScreenState();
}

class _CreditClientsScreenState extends ConsumerState<CreditClientsScreen> {
  List<Invoice> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCredits();
  }

  Future<void> _loadCredits() async {
    setState(() => _isLoading = true);
    final invoices = await DatabaseService.instance.getCreditInvoices();
    if (!mounted) return;
    setState(() {
      _invoices = invoices;
      _isLoading = false;
    });
  }

  Map<String, List<Invoice>> get _grouped {
    final map = <String, List<Invoice>>{};
    for (final inv in _invoices) {
      final name = inv.customerName.isEmpty ? 'Inconnu' : inv.customerName;
      map.putIfAbsent(name, () => []).add(inv);
    }
    return map;
  }

  double get _totalDebt => _invoices.fold(0.0, (s, i) => s + i.remainingAmount);

  Future<void> _makePayment(Invoice invoice) async {
    final loc = AppLocalizations.of(context);
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.tr('make_payment')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${loc.tr('customer_name')}: ${invoice.customerName}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${loc.tr('remaining')}: ${invoice.remainingAmount.toStringAsFixed(0)} ${loc.tr('currency')}',
                  style: TextStyle(color: Colors.red[600], fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                decoration: InputDecoration(
                  labelText: loc.tr('payment_amount'),
                  suffixText: loc.tr('currency'),
                ),
                autofocus: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return loc.tr('amount_required');
                  final amount = double.tryParse(v.replaceAll(',', '.'));
                  if (amount == null || amount <= 0) return loc.tr('amount_invalid');
                  if (amount > invoice.remainingAmount) return loc.tr('amount_exceeds');
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _quickBtn('25%', invoice.remainingAmount * 0.25, amountCtrl),
                  const SizedBox(width: 4),
                  _quickBtn('50%', invoice.remainingAmount * 0.50, amountCtrl),
                  const SizedBox(width: 4),
                  _quickBtn('75%', invoice.remainingAmount * 0.75, amountCtrl),
                  const SizedBox(width: 4),
                  _quickBtn(loc.tr('all'), invoice.remainingAmount, amountCtrl),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.tr('cancel'))),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
                Navigator.pop(ctx, amount);
              }
            },
            child: Text(loc.tr('make_payment')),
          ),
        ],
      ),
    );

    if (result != null && result > 0 && invoice.id != null) {
      await DatabaseService.instance.payCreditInvoice(invoice.id!, result);
      await _loadCredits();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.tr('success')),
          backgroundColor: Colors.green[600],
        ));
      }
    }
  }

  Widget _quickBtn(String label, double amount, TextEditingController ctrl) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () => ctrl.text = amount.toStringAsFixed(0),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8), minimumSize: Size.zero),
        child: Text(label, style: const TextStyle(fontSize: 10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final grouped = _grouped;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) context.go('/'); },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/')),
          title: Text(loc.tr('credit_clients')),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _invoices.isEmpty
                ? Center(child: Text(loc.tr('no_credit_invoices')))
                : RefreshIndicator(
                    onRefresh: _loadCredits,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Total debt
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.red[600],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Text(loc.tr('total_debt'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 6),
                              Text('${_totalDebt.toStringAsFixed(0)} ${loc.tr('currency')}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28)),
                              const SizedBox(height: 4),
                              Text('${_invoices.length} ${loc.tr('invoices')}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Customer groups
                        for (final entry in grouped.entries) ...[
                          Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red[50],
                                child: Icon(Icons.person, color: Colors.red[600], size: 20),
                              ),
                              title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('${entry.value.length} ${loc.tr('invoices')}'),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                  '${entry.value.fold(0.0, (s, i) => s + i.remainingAmount).toStringAsFixed(0)} ${loc.tr('currency')}',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red[700], fontSize: 12),
                                ),
                              ),
                              children: entry.value.map((inv) => _buildInvoiceTile(inv, loc)).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildInvoiceTile(Invoice invoice, AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(DateFormat('dd/MM/yyyy').format(invoice.date),
                    style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                const Spacer(),
                if (invoice.customerPhone.isNotEmpty)
                  Text(invoice.customerPhone, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: invoice.totalAmount > 0 ? invoice.paidAmount / invoice.totalAmount : 0,
              backgroundColor: Colors.grey[200],
              color: Colors.green,
              minHeight: 4,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${loc.tr('paid')}: ${invoice.paidAmount.toStringAsFixed(0)} ${loc.tr('currency')}',
                    style: TextStyle(color: Colors.green[600], fontSize: 11, fontWeight: FontWeight.w500)),
                Text('${loc.tr('remaining')}: ${invoice.remainingAmount.toStringAsFixed(0)} ${loc.tr('currency')}',
                    style: TextStyle(color: Colors.red[600], fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${loc.tr('grand_total')}: ${invoice.totalAmount.toStringAsFixed(0)} ${loc.tr('currency')}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _makePayment(invoice),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                  ),
                  child: Text(loc.tr('make_payment'), style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
