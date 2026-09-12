import 'invoice.dart';
import 'product.dart';
import 'customer.dart';
import 'category.dart';

/// Metadata included in every .abp backup file
class BackupManifest {
  final String version;
  final DateTime createdAt;
  final String shopName;
  final List<String> sections;
  final Map<String, int> counts;

  const BackupManifest({
    required this.version,
    required this.createdAt,
    required this.shopName,
    required this.sections,
    required this.counts,
  });

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    return BackupManifest(
      version: json['version'] as String? ?? '1.0.0',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      shopName: json['shopName'] as String? ?? '',
      sections: List<String>.from(json['sections'] as List? ?? []),
      counts: Map<String, int>.from(json['counts'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'shopName': shopName,
    'sections': sections,
    'counts': counts,
  };
}

/// Diff type for a product change
enum DiffType { newProduct, priceChanged, stockChanged, bothChanged }

/// A single product difference between incoming and local DB
class ProductDiff {
  final Product incoming;
  final Product? existing; // null if new
  final DiffType type;

  const ProductDiff({required this.incoming, this.existing, required this.type});

  bool get isNew => existing == null;
}

/// A single customer difference
class CustomerDiff {
  final Customer incoming;
  final Customer? existing; // null if new
  final double? debtChange; // difference in credit amount

  const CustomerDiff({required this.incoming, this.existing, this.debtChange});
}

/// An invoice that exists in the incoming backup
class InvoiceDiff {
  final Invoice invoice;
  final List<InvoiceItem> items;
  final bool alreadyExists; // true if invoiceNumber matches local

  const InvoiceDiff({required this.invoice, required this.items, required this.alreadyExists});
}

/// Complete diff result between incoming backup and local database
class ImportDiff {
  final List<InvoiceDiff> newInvoices;
  final List<ProductDiff> productChanges;
  final List<CustomerDiff> customerChanges;
  final List<Category> newCategories;
  final int totalIncomingInvoices;
  final int totalIncomingProducts;
  final int totalIncomingCustomers;

  const ImportDiff({
    required this.newInvoices,
    required this.productChanges,
    required this.customerChanges,
    required this.newCategories,
    required this.totalIncomingInvoices,
    required this.totalIncomingProducts,
    required this.totalIncomingCustomers,
  });

  int get newInvoiceCount => newInvoices.where((d) => !d.alreadyExists).length;
  int get newProductCount => productChanges.where((d) => d.isNew).length;
  int get modifiedProductCount => productChanges.where((d) => !d.isNew).length;
  int get newCustomerCount => customerChanges.where((d) => d.existing == null).length;
  int get modifiedCustomerCount => customerChanges.where((d) => d.existing != null).length;
  int get newCategoryCount => newCategories.length;

  bool get isEmpty =>
      newInvoiceCount == 0 &&
      productChanges.isEmpty &&
      customerChanges.isEmpty &&
      newCategoryCount == 0;
}
