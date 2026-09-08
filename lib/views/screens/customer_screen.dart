import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../services/database_service.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/input_label.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  List<Customer> _customers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    final customers = await DatabaseService.instance.getCustomers();
    setState(() {
      _customers = customers;
      _isLoading = false;
    });
  }

  List<Customer> get _filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    return _customers
        .where((c) =>
            c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c.phoneNumber.contains(_searchQuery) ||
            c.nif.contains(_searchQuery))
        .toList();
  }

  void _showAddCustomerDialog({Customer? existing}) {
    final loc = AppLocalizations.of(context);
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phoneNumber ?? '');
    final emailController = TextEditingController(text: existing?.email ?? '');
    final addressController = TextEditingController(text: existing?.address ?? '');
    final nifController = TextEditingController(text: existing?.nif ?? '');
    final rcController = TextEditingController(text: existing?.rc ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing != null ? loc.tr('edit_customer') : loc.tr('add_customer')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const InputLabel(text: 'Name', isRequired: true),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(hintText: loc.tr('customer_name')),
              ),
              const SizedBox(height: 16),
              const InputLabel(text: 'Phone'),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(hintText: loc.tr('customer_phone')),
              ),
              const SizedBox(height: 16),
              const InputLabel(text: 'NIF'),
              TextField(
                controller: nifController,
                decoration: InputDecoration(
                  hintText: loc.tr('customer_nif'),
                ),
              ),
              const SizedBox(height: 16),
              const InputLabel(text: 'RC'),
              TextField(
                controller: rcController,
                decoration: InputDecoration(
                  hintText: loc.tr('customer_rc'),
                ),
              ),
              const SizedBox(height: 16),
              const InputLabel(text: 'Address'),
              TextField(
                controller: addressController,
                decoration: InputDecoration(hintText: loc.tr('customer_address')),
              ),
              const SizedBox(height: 16),
              const InputLabel(text: 'Email'),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(hintText: loc.tr('customer_email')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;

              final customer = Customer(
                id: existing?.id,
                name: nameController.text,
                phoneNumber: phoneController.text,
                email: emailController.text,
                address: addressController.text,
                nif: nifController.text,
                rc: rcController.text,
              );

              if (existing != null) {
                await DatabaseService.instance.updateCustomer(customer);
              } else {
                await DatabaseService.instance.insertCustomer(customer);
              }

              _loadCustomers();
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(loc.tr('save')),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Customer customer) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.tr('delete')),
        content: Text(loc.tr('confirm_delete_customer')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.tr('cancel')),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseService.instance.deleteCustomer(customer.id!);
              _loadCustomers();
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(loc.tr('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.tr('customer_management')),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: loc.tr('search'),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCustomers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline,
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(loc.tr('no_customers'),
                                style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = _filteredCustomers[index];
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary.withAlpha(25),
                                child: Text(
                                  customer.name.isNotEmpty
                                      ? customer.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                customer.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (customer.phoneNumber.isNotEmpty)
                                    Text(customer.phoneNumber,
                                        style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                  if (customer.nif.isNotEmpty)
                                    Text('NIF: ${customer.nif}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    color: Theme.of(context).colorScheme.primary,
                                    onPressed: () => _showAddCustomerDialog(existing: customer),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: Colors.red,
                                    onPressed: () => _confirmDelete(customer),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCustomerDialog(),
        child: const Icon(Icons.person_add_outlined, size: 28),
      ),
    );
  }
}
