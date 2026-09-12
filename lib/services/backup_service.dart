import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/backup_models.dart';
import '../models/invoice.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/category.dart';
import 'database_service.dart';

class BackupService {
  BackupService._();
  static final instance = BackupService._();

  /// Create a full backup as .abp file (ZIP archive)
  /// [sections] controls what to include: 'invoices', 'products', 'customers', 'categories'
  Future<File> createBackup({required List<String> sections}) async {
    final dbPath = await getDatabasesPath();
    final dbFile = File(p.join(dbPath, 'algerian_billing.db'));

    if (!dbFile.existsSync()) {
      throw Exception('Database file not found');
    }

    // Gather manifest data
    final db = await openDatabase(dbFile.path, readOnly: true);
    try {
      final shop = await DatabaseService.instance.getShop();
      final counts = <String, int>{};

      if (sections.contains('invoices')) {
        final r = await db.rawQuery('SELECT COUNT(*) as c FROM invoices');
        counts['invoices'] = (r.first['c'] as int?) ?? 0;
      }
      if (sections.contains('products')) {
        final r = await db.rawQuery('SELECT COUNT(*) as c FROM products');
        counts['products'] = (r.first['c'] as int?) ?? 0;
      }
      if (sections.contains('customers')) {
        final r = await db.rawQuery('SELECT COUNT(*) as c FROM customers');
        counts['customers'] = (r.first['c'] as int?) ?? 0;
      }
      if (sections.contains('categories')) {
        final r = await db.rawQuery('SELECT COUNT(*) as c FROM categories');
        counts['categories'] = (r.first['c'] as int?) ?? 0;
      }

      final manifest = BackupManifest(
        version: '1.0.0',
        createdAt: DateTime.now(),
        shopName: shop.name,
        sections: sections,
        counts: counts,
      );

      // Create ZIP archive
      final archive = Archive();

      // Add the database file
      final dbBytes = await dbFile.readAsBytes();
      archive.addFile(ArchiveFile('data.db', dbBytes.length, dbBytes));

      // Add manifest
      final manifestBytes = manifest.toJson().toString().codeUnits;
      archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

      // Encode to ZIP
      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) throw Exception('Failed to encode backup');

      // Save to temp directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupFile = File('${tempDir.path}/backup_$timestamp.abp');
      await backupFile.writeAsBytes(zipData, flush: true);

      return backupFile;
    } finally {
      await db.close();
    }
  }

  /// Extract an .abp backup file and return the manifest + extracted DB path
  Future<({BackupManifest manifest, String dbPath})> extractBackup(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Extract to temp staging directory
    final tempDir = await getTemporaryDirectory();
    final stagingDir = Directory('${tempDir.path}/import_staging_${DateTime.now().millisecondsSinceEpoch}');
    await stagingDir.create(recursive: true);

    String? dbExtractedPath;
    String? manifestJson;

    for (final file in archive) {
      final outPath = p.join(stagingDir.path, file.name);
      if (file.isFile) {
        final data = file.content as List<int>;
        await File(outPath).writeAsBytes(data, flush: true);
        if (file.name == 'data.db') dbExtractedPath = outPath;
        if (file.name == 'manifest.json') manifestJson = String.fromCharCodes(data);
      }
    }

    if (dbExtractedPath == null) throw Exception('Backup does not contain a database file');
    if (manifestJson == null) throw Exception('Backup does not contain a manifest');

    // Parse manifest
    // Simple JSON parsing without dart:convert dependency issue
    final manifest = _parseManifest(manifestJson);

    return (manifest: manifest, dbPath: dbExtractedPath);
  }

  BackupManifest _parseManifest(String json) {
    // Manual lightweight JSON parsing for the manifest
    try {
      // Remove braces and split by comma
      final content = json.trim();
      if (!content.startsWith('{')) return _defaultManifest();

      final map = <String, dynamic>{};
      // Extract version
      final versionMatch = RegExp(r'"version"\s*:\s*"([^"]*)"').firstMatch(content);
      if (versionMatch != null) map['version'] = versionMatch.group(1);

      // Extract createdAt
      final dateMatch = RegExp(r'"createdAt"\s*:\s*"([^"]*)"').firstMatch(content);
      if (dateMatch != null) map['createdAt'] = dateMatch.group(1);

      // Extract shopName
      final shopMatch = RegExp(r'"shopName"\s*:\s*"([^"]*)"').firstMatch(content);
      if (shopMatch != null) map['shopName'] = shopMatch.group(1);

      // Extract sections array
      final sectionsMatch = RegExp(r'"sections"\s*:\s*\[([^\]]*)\]').firstMatch(content);
      if (sectionsMatch != null) {
        final sectionsStr = sectionsMatch.group(1) ?? '';
        map['sections'] = sectionsStr.split(',').map((s) => s.trim().replaceAll('"', '')).toList();
      }

      // Extract counts
      final countsMatch = RegExp(r'"counts"\s*:\s*\{([^}]*)\}').firstMatch(content);
      if (countsMatch != null) {
        final countsStr = countsMatch.group(1) ?? '';
        final counts = <String, int>{};
        final entries = countsStr.split(',');
        for (final entry in entries) {
          final kv = entry.split(':');
          if (kv.length == 2) {
            final key = kv[0].trim().replaceAll('"', '');
            final val = int.tryParse(kv[1].trim()) ?? 0;
            counts[key] = val;
          }
        }
        map['counts'] = counts;
      }

      return BackupManifest.fromJson(map);
    } catch (_) {
      return _defaultManifest();
    }
  }

  BackupManifest _defaultManifest() => BackupManifest(
    version: '1.0.0',
    createdAt: DateTime.now(),
    shopName: '',
    sections: [],
    counts: {},
  );

  /// Compute diff between incoming backup DB and local DB
  Future<ImportDiff> computeDiff({required String incomingDbPath}) async {
    final incomingDb = await openDatabase(incomingDbPath, readOnly: true);
    final localDb = await DatabaseService.instance.database;

    try {
      // 1. Invoice diff
      final newInvoices = await _diffInvoices(incomingDb, localDb);

      // 2. Product diff
      final productChanges = await _diffProducts(incomingDb, localDb);

      // 3. Customer diff
      final customerChanges = await _diffCustomers(incomingDb, localDb);

      // 4. Category diff
      final newCategories = await _diffCategories(incomingDb, localDb);

      // Count totals from incoming
      final totalInvoices = Sqflite.firstIntValue(
        await incomingDb.rawQuery('SELECT COUNT(*) FROM invoices'),
      ) ?? 0;
      final totalProducts = Sqflite.firstIntValue(
        await incomingDb.rawQuery('SELECT COUNT(*) FROM products'),
      ) ?? 0;
      final totalCustomers = Sqflite.firstIntValue(
        await incomingDb.rawQuery('SELECT COUNT(*) FROM customers'),
      ) ?? 0;

      return ImportDiff(
        newInvoices: newInvoices,
        productChanges: productChanges,
        customerChanges: customerChanges,
        newCategories: newCategories,
        totalIncomingInvoices: totalInvoices,
        totalIncomingProducts: totalProducts,
        totalIncomingCustomers: totalCustomers,
      );
    } finally {
      await incomingDb.close();
    }
  }

  Future<List<InvoiceDiff>> _diffInvoices(Database incomingDb, Database localDb) async {
    // Get all invoice numbers already in local DB
    final localNumbersRaw = await localDb.rawQuery('SELECT invoiceNumber FROM invoices');
    final localNumbers = localNumbersRaw.map((r) => r['invoiceNumber'] as String).toSet();

    // Get all invoices from incoming
    final incomingRows = await incomingDb.query('invoices', orderBy: 'id ASC');
    final diffs = <InvoiceDiff>[];

    for (final row in incomingRows) {
      final invoice = Invoice.fromMap(row);
      final alreadyExists = localNumbers.contains(invoice.invoiceNumber);

      // Get items for this invoice
      final itemRows = await incomingDb.query(
        'invoice_items',
        where: 'invoiceId = ?',
        whereArgs: [row['id']],
      );
      final items = itemRows.map((r) => InvoiceItem.fromMap(r)).toList();

      diffs.add(InvoiceDiff(
        invoice: invoice,
        items: items,
        alreadyExists: alreadyExists,
      ));
    }

    return diffs;
  }

  Future<List<ProductDiff>> _diffProducts(Database incomingDb, Database localDb) async {
    // Build local product index by barcode (if non-empty) then by name
    final localProducts = await DatabaseService.instance.getProducts();
    final localByBarcode = <String, Product>{};
    final localByName = <String, Product>{};
    for (final p in localProducts) {
      if (p.barcode.isNotEmpty) localByBarcode[p.barcode] = p;
      localByName[p.name.toLowerCase()] = p;
    }

    final incomingRows = await incomingDb.query('products', orderBy: 'id ASC');
    final diffs = <ProductDiff>[];
    final seenLocalIds = <int>{};

    for (final row in incomingRows) {
      final incoming = Product.fromMap(row);
      Product? existing;

      // Match by barcode first, then by name
      if (incoming.barcode.isNotEmpty && localByBarcode.containsKey(incoming.barcode)) {
        existing = localByBarcode[incoming.barcode];
      } else if (localByName.containsKey(incoming.name.toLowerCase())) {
        existing = localByName[incoming.name.toLowerCase()];
      }

      if (existing != null) {
        seenLocalIds.add(existing.id!);
        // Detect changes
        final priceChanged = (incoming.price - existing.price).abs() > 0.01;
        final stockChanged = incoming.stock != existing.stock;

        if (priceChanged || stockChanged) {
          final type = priceChanged && stockChanged
              ? DiffType.bothChanged
              : priceChanged
                  ? DiffType.priceChanged
                  : DiffType.stockChanged;
          diffs.add(ProductDiff(incoming: incoming, existing: existing, type: type));
        }
      } else {
        // New product
        diffs.add(ProductDiff(incoming: incoming, existing: null, type: DiffType.newProduct));
      }
    }

    return diffs;
  }

  Future<List<CustomerDiff>> _diffCustomers(Database incomingDb, Database localDb) async {
    // Build local customer index by name+phone
    final localRows = await localDb.query('customers', orderBy: 'id ASC');
    final localCustomers = <String, Customer>{};
    for (final row in localRows) {
      final c = Customer.fromMap(row);
      final key = '${c.name.toLowerCase()}_${c.phoneNumber}';
      localCustomers[key] = c;
    }

    final incomingRows = await incomingDb.query('customers', orderBy: 'id ASC');
    final diffs = <CustomerDiff>[];

    for (final row in incomingRows) {
      final incoming = Customer.fromMap(row);
      final key = '${incoming.name.toLowerCase()}_${incoming.phoneNumber}';
      final existing = localCustomers[key];

      diffs.add(CustomerDiff(
        incoming: incoming,
        existing: existing,
        debtChange: null, // TODO: compute from credit invoices if needed
      ));
    }

    return diffs;
  }

  Future<List<Category>> _diffCategories(Database incomingDb, Database localDb) async {
    final localNamesRaw = await localDb.rawQuery('SELECT name FROM categories');
    final localNames = localNamesRaw.map((r) => (r['name'] as String).toLowerCase()).toSet();

    final incomingRows = await incomingDb.query('categories', orderBy: 'id ASC');
    final newOnes = <Category>[];

    for (final row in incomingRows) {
      final cat = Category.fromMap(row);
      if (!localNames.contains(cat.name.toLowerCase())) {
        newOnes.add(cat);
      }
    }

    return newOnes;
  }

  /// Execute the selective merge in a transaction
  Future<MergeResult> executeMerge({
    required String incomingDbPath,
    required ImportDiff diff,
    required bool mergeInvoices,
    required bool mergeProducts,
    required bool mergeCustomers,
    required bool mergeCategories,
    required bool updatePrices,
    required bool updateStock,
  }) async {
    final incomingDb = await openDatabase(incomingDbPath, readOnly: true);
    final db = await DatabaseService.instance.database;
    int invoicesAdded = 0, productsAdded = 0, productsUpdated = 0;
    int customersAdded = 0, categoriesAdded = 0;

    try {
      await db.transaction((txn) async {
        // 1. Categories first (products may reference them)
        if (mergeCategories) {
          for (final cat in diff.newCategories) {
            try {
              await txn.insert('categories', cat.toMap());
              categoriesAdded++;
            } catch (_) {}
          }
        }

        // 2. Products
        if (mergeProducts) {
          for (final pd in diff.productChanges) {
            if (pd.isNew) {
              // Insert new product (strip id to let autoincrement work)
              final map = pd.incoming.toMap();
              map.remove('id');
              await txn.insert('products', map);
              productsAdded++;
            } else {
              // Update existing product
              final updates = <String, dynamic>{};
              if (updatePrices) {
                updates['price'] = pd.incoming.price;
              }
              if (updateStock) {
                updates['stock'] = pd.incoming.stock;
              }
              if (updates.isNotEmpty) {
                await txn.update(
                  'products',
                  updates,
                  where: 'id = ?',
                  whereArgs: [pd.existing!.id],
                );
                productsUpdated++;
              }
            }
          }
        }

        // 3. Customers
        if (mergeCustomers) {
          for (final cd in diff.customerChanges) {
            if (cd.existing == null) {
              final map = cd.incoming.toMap();
              map.remove('id');
              await txn.insert('customers', map);
              customersAdded++;
            }
          }
        }

        // 4. Invoices + Items (INSERT OR IGNORE by invoiceNumber)
        if (mergeInvoices) {
          for (final invDiff in diff.newInvoices) {
            if (invDiff.alreadyExists) continue;

            // Check if invoiceNumber already exists (double safety)
            final existing = await txn.query(
              'invoices',
              where: 'invoiceNumber = ?',
              whereArgs: [invDiff.invoice.invoiceNumber],
            );
            if (existing.isNotEmpty) continue;

            // Insert invoice
            final invMap = invDiff.invoice.toMap();
            invMap.remove('id');
            final newId = await txn.insert('invoices', invMap);

            // Insert items with new invoiceId
            for (final item in invDiff.items) {
              final itemMap = item.toMap();
              itemMap.remove('id');
              itemMap['invoiceId'] = newId;
              await txn.insert('invoice_items', itemMap);
            }
            invoicesAdded++;
          }
        }
      });

      return MergeResult(
        invoicesAdded: invoicesAdded,
        productsAdded: productsAdded,
        productsUpdated: productsUpdated,
        customersAdded: customersAdded,
        categoriesAdded: categoriesAdded,
        success: true,
      );
    } catch (e) {
      return MergeResult(
        invoicesAdded: 0,
        productsAdded: 0,
        productsUpdated: 0,
        customersAdded: 0,
        categoriesAdded: 0,
        success: false,
        error: e.toString(),
      );
    } finally {
      await incomingDb.close();
    }
  }

  /// Create a safety backup of the current database before merge
  Future<String> createSafetyBackup() async {
    final dbPath = await getDatabasesPath();
    final dbFile = File(p.join(dbPath, 'algerian_billing.db'));

    final tempDir = await getTemporaryDirectory();
    final safetyPath = '${tempDir.path}/pre_merge_backup_${DateTime.now().millisecondsSinceEpoch}.db';
    await dbFile.copy(safetyPath);
    return safetyPath;
  }

  /// Cleanup staging directory
  Future<void> cleanupStaging(String dbPath) async {
    try {
      final dir = Directory(p.dirname(dbPath));
      if (dir.path.contains('import_staging')) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }
}

/// Result of a merge operation
class MergeResult {
  final int invoicesAdded;
  final int productsAdded;
  final int productsUpdated;
  final int customersAdded;
  final int categoriesAdded;
  final bool success;
  final String? error;

  const MergeResult({
    required this.invoicesAdded,
    required this.productsAdded,
    required this.productsUpdated,
    required this.customersAdded,
    required this.categoriesAdded,
    required this.success,
    this.error,
  });
}
