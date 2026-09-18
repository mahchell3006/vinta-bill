import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/invoice.dart';
import '../models/category.dart';
import '../models/shop.dart';
import '../models/purchase.dart';
import '../models/bulk_preset.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('algerian_billing.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 7,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        // Safety: ensure critical columns always exist
        await _ensureColumn(db, 'invoices', 'paidAmount', 'REAL DEFAULT 0.0');
        await _ensureColumn(db, 'invoices', 'customerName', "TEXT DEFAULT ''");
        await _ensureColumn(db, 'invoices', 'customerPhone', "TEXT DEFAULT ''");
        // Wholesale fields (v5)
        await _ensureColumn(db, 'products', 'is_bulk_convertible', 'INTEGER DEFAULT 0');
        await _ensureColumn(db, 'products', 'wholesale_unit_name', "TEXT DEFAULT ''");
        await _ensureColumn(db, 'products', 'conversion_factor', 'INTEGER DEFAULT 1');
        await _ensureColumn(db, 'products', 'wholesale_cost_price', 'REAL DEFAULT 0.0');
        await _ensureColumn(db, 'products', 'cost_price', 'REAL DEFAULT 0.0');
        // Packs tracking (bulk orders v2)
        await _ensureColumn(db, 'products', 'packs', 'INTEGER DEFAULT 0');
      },
    );
  }

  Future<void> _ensureColumn(Database db, String table, String column, String definition) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    } catch (_) {
      // Column already exists
    }
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _ensureColumn(db, 'invoices', 'customerName', "TEXT DEFAULT ''");
      await _ensureColumn(db, 'invoices', 'customerPhone', "TEXT DEFAULT ''");
    }
    if (oldVersion < 3) {
      await _ensureColumn(db, 'invoices', 'paidAmount', 'REAL DEFAULT 0.0');
    }
    if (oldVersion < 5) {
      // Wholesale fields
      await _ensureColumn(db, 'products', 'is_bulk_convertible', 'INTEGER DEFAULT 0');
      await _ensureColumn(db, 'products', 'wholesale_unit_name', "TEXT DEFAULT ''");
      await _ensureColumn(db, 'products', 'conversion_factor', 'INTEGER DEFAULT 1');
      await _ensureColumn(db, 'products', 'wholesale_cost_price', 'REAL DEFAULT 0.0');
      await _ensureColumn(db, 'products', 'cost_price', 'REAL DEFAULT 0.0');
      // Purchases table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchases (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          quantity_wholesale_units INTEGER NOT NULL,
          quantity_retail_units INTEGER NOT NULL,
          total_cost REAL NOT NULL,
          unit_cost REAL NOT NULL,
          wholesale_unit_name TEXT DEFAULT '',
          created_at TEXT NOT NULL,
          FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 6) {
      // Bulk presets table (reusable plateau/sac definitions per product)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS bulk_presets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          conversion_factor INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 7) {
      // Packs tracking for bulk orders
      await _ensureColumn(db, 'products', 'packs', 'INTEGER DEFAULT 0');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT DEFAULT '',
        price REAL NOT NULL,
        stock INTEGER NOT NULL DEFAULT 0,
        categoryId INTEGER,
        barcode TEXT DEFAULT '',
        tvaRate REAL NOT NULL DEFAULT 0.0,
        is_bulk_convertible INTEGER DEFAULT 0,
        wholesale_unit_name TEXT DEFAULT '',
        conversion_factor INTEGER DEFAULT 1,
        wholesale_cost_price REAL DEFAULT 0.0,
        cost_price REAL DEFAULT 0.0,
        packs INTEGER DEFAULT 0,
        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phoneNumber TEXT DEFAULT '',
        email TEXT DEFAULT '',
        address TEXT DEFAULT '',
        nif TEXT DEFAULT '',
        rc TEXT DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceNumber TEXT NOT NULL,
        customerId INTEGER,
        customerName TEXT DEFAULT '',
        customerPhone TEXT DEFAULT '',
        date TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        tvaAmount REAL NOT NULL DEFAULT 0.0,
        discount REAL DEFAULT 0.0,
        paymentMethod TEXT NOT NULL DEFAULT 'cash',
        isPaid INTEGER DEFAULT 1,
        paidAmount REAL DEFAULT 0.0,
        FOREIGN KEY (customerId) REFERENCES customers (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceId INTEGER NOT NULL,
        productId INTEGER NOT NULL,
        productName TEXT NOT NULL,
        price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        tvaRate REAL NOT NULL DEFAULT 0.0,
        FOREIGN KEY (invoiceId) REFERENCES invoices (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE shop (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT DEFAULT '',
        addressLine1 TEXT DEFAULT '',
        addressLine2 TEXT DEFAULT '',
        phoneNumber TEXT DEFAULT '',
        nif TEXT DEFAULT '',
        rc TEXT DEFAULT '',
        footerText TEXT DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        quantity_wholesale_units INTEGER NOT NULL,
        quantity_retail_units INTEGER NOT NULL,
        total_cost REAL NOT NULL,
        unit_cost REAL NOT NULL,
        wholesale_unit_name TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE bulk_presets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        conversion_factor INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    await db.insert('categories', {'name': 'Général'});
  }

  // ==================== PRODUCTS ====================

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert('products', product.toMap());
  }

  Future<List<Product>> getProducts() async {
    final db = await database;
    final result = await db.query('products', orderBy: 'id DESC');
    return result.map((map) => Product.fromMap(map)).toList();
  }

  Future<Product?> getProductById(int id) async {
    final db = await database;
    final result = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Product.fromMap(result.first);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final result = await db.query('products', where: 'barcode = ?', whereArgs: [barcode]);
    if (result.isEmpty) return null;
    return Product.fromMap(result.first);
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await database;
    final result = await db.query(
      'products',
      where: 'name LIKE ? OR barcode LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return result.map((map) => Product.fromMap(map)).toList();
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return await db.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateProductStock(int productId, int quantityChange) async {
    final db = await database;
    if (quantityChange >= 0) {
      // Adding stock — just add to total
      await db.rawUpdate(
        'UPDATE products SET stock = MAX(0, stock + ?) WHERE id = ?',
        [quantityChange, productId],
      );
    } else {
      // Selling — reduce stock, then recalculate packs from stock
      final rows = await db.query(
        'products', columns: ['stock', 'conversion_factor'],
        where: 'id = ?', whereArgs: [productId],
      );
      if (rows.isEmpty) return;
      final currentStock = rows.first['stock'] as int? ?? 0;
      final conv = rows.first['conversion_factor'] as int? ?? 1;
      final absQty = quantityChange.abs();
      final newStock = (currentStock - absQty).clamp(0, currentStock);

      await db.rawUpdate(
        'UPDATE products SET stock = ? WHERE id = ?',
        [newStock, productId],
      );

      // Recalculate packs from stock and conversion factor
      if (conv > 1) {
        await db.rawUpdate(
          'UPDATE products SET packs = stock / ? WHERE id = ?',
          [conv, productId],
        );
      }
    }
  }

  Future<void> setProductStock(int productId, int newStock) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE products SET stock = ? WHERE id = ?',
      [newStock < 0 ? 0 : newStock, productId],
    );
  }

  Future<List<Product>> getLowStockProducts({int threshold = 5}) async {
    final db = await database;
    final result = await db.query('products', where: 'stock <= ?', whereArgs: [threshold], orderBy: 'stock ASC');
    return result.map((map) => Product.fromMap(map)).toList();
  }

  Future<void> updateProductCostPrice(int productId, double newCostPrice) async {
    final db = await database;
    await db.update(
      'products',
      {'cost_price': newCostPrice},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  // ==================== CATEGORIES ====================

  Future<int> insertCategory(Category category) async {
    final db = await database;
    return await db.insert('categories', category.toMap());
  }

  Future<List<Category>> getCategories() async {
    final db = await database;
    final result = await db.query('categories', orderBy: 'name ASC');
    return result.map((map) => Category.fromMap(map)).toList();
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    return await db.update('categories', category.toMap(), where: 'id = ?', whereArgs: [category.id]);
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== CUSTOMERS ====================

  Future<int> insertCustomer(Customer customer) async {
    final db = await database;
    return await db.insert('customers', customer.toMap());
  }

  Future<List<Customer>> getCustomers() async {
    final db = await database;
    final result = await db.query('customers', orderBy: 'id DESC');
    return result.map((map) => Customer.fromMap(map)).toList();
  }

  Future<Customer?> getCustomerById(int id) async {
    final db = await database;
    final result = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Customer.fromMap(result.first);
  }

  Future<int> updateCustomer(Customer customer) async {
    final db = await database;
    return await db.update('customers', customer.toMap(), where: 'id = ?', whereArgs: [customer.id]);
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== INVOICES ====================

  Future<int> insertInvoice(Invoice invoice, List<InvoiceItem> items) async {
    final db = await database;
    int invoiceId = 0;

    await db.transaction((txn) async {
      invoiceId = await txn.insert('invoices', invoice.toMap());
      for (var item in items) {
        final itemMap = item.toMap();
        itemMap['invoiceId'] = invoiceId;
        await txn.insert('invoice_items', itemMap);
      }
    });

    return invoiceId;
  }

  Future<List<Invoice>> getInvoices() async {
    final db = await database;
    final result = await db.query('invoices', orderBy: 'date DESC');
    return result.map((map) => Invoice.fromMap(map)).toList();
  }

  Future<Invoice?> getInvoiceById(int id) async {
    final db = await database;
    final result = await db.query('invoices', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Invoice.fromMap(result.first);
  }

  Future<List<InvoiceItem>> getInvoiceItems(int invoiceId) async {
    final db = await database;
    final result = await db.query('invoice_items', where: 'invoiceId = ?', whereArgs: [invoiceId]);
    return result.map((map) => InvoiceItem.fromMap(map)).toList();
  }

  Future<int> deleteInvoice(int id) async {
    final db = await database;
    return await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Invoice>> getCreditInvoices() async {
    final db = await database;
    final result = await db.query(
      'invoices',
      where: "paymentMethod = 'credit' AND paidAmount < totalAmount",
      orderBy: 'date DESC',
    );
    return result.map((map) => Invoice.fromMap(map)).toList();
  }

  Future<void> payCreditInvoice(int invoiceId, double amount) async {
    final db = await database;
    final result = await db.query('invoices',
        columns: ['paidAmount', 'totalAmount'], where: 'id = ?', whereArgs: [invoiceId]);
    if (result.isEmpty) return;

    final currentPaid = (result.first['paidAmount'] as num?)?.toDouble() ?? 0;
    final total = (result.first['totalAmount'] as num).toDouble();
    final newPaid = currentPaid + amount;

    await db.update(
      'invoices',
      {
        'paidAmount': newPaid > total ? total : newPaid,
        'isPaid': newPaid >= total ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }

  // ==================== DAILY SALES ====================

  Future<Map<String, dynamic>> getDailySales() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(totalAmount), 0) as revenue,
        COUNT(*) as transactionCount
      FROM invoices
      WHERE date >= ? AND date < ? AND paymentMethod != 'credit'
    ''', [startOfDay.toIso8601String(), endOfDay.toIso8601String()]);

    final itemsResult = await db.rawQuery('''
      SELECT COALESCE(SUM(quantity), 0) as totalPieces
      FROM invoice_items ii
      JOIN invoices i ON ii.invoiceId = i.id
      WHERE i.date >= ? AND i.date < ?
    ''', [startOfDay.toIso8601String(), endOfDay.toIso8601String()]);

    return {
      'revenue': (result.first['revenue'] as num).toDouble(),
      'transactionCount': result.first['transactionCount'] as int,
      'totalPieces': itemsResult.first['totalPieces'] as int,
    };
  }

  // ==================== COGS & NET PROFIT ====================

  /// Calculate Cost of Goods Sold for today
  Future<double> getDailyCOGS() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(ii.quantity * p.cost_price), 0) as cogs
      FROM invoice_items ii
      JOIN invoices i ON ii.invoiceId = i.id
      JOIN products p ON ii.productId = p.id
      WHERE i.date >= ? AND i.date < ?
    ''', [startOfDay.toIso8601String(), endOfDay.toIso8601String()]);

    return (result.first['cogs'] as num).toDouble();
  }

  // ==================== PURCHASES ====================

  Future<int> insertPurchase(Purchase purchase) async {
    final db = await database;
    return await db.insert('purchases', purchase.toMap());
  }

  Future<List<Purchase>> getPurchases() async {
    final db = await database;
    final result = await db.query('purchases', orderBy: 'created_at DESC');
    return result.map((map) => Purchase.fromMap(map)).toList();
  }

  Future<List<Purchase>> getPurchasesByProduct(int productId) async {
    final db = await database;
    final result = await db.query(
      'purchases',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => Purchase.fromMap(map)).toList();
  }

  /// Bulk restock: adds stock, logs purchase, blends unit cost with
  /// weighted average (old stock value + new batch value) / total stock.
  /// This keeps profit honest when supplier price changes day to day
  /// (e.g. eggs at 14 DA today, 16 DA tomorrow).
  Future<void> bulkRestock({
    required int productId,
    required int wholesaleUnits,
    required double totalCost,
    required int conversionFactor,
    required String unitName,
  }) async {
    final db = await database;
    final retailUnits = wholesaleUnits * conversionFactor;
    if (retailUnits <= 0) return;
    final newUnitCost = totalCost / retailUnits;

    await db.transaction((txn) async {
      // Read current stock + cost to compute weighted average
      final rows = await txn.query(
        'products',
        columns: ['stock', 'cost_price'],
        where: 'id = ?',
        whereArgs: [productId],
      );
      final oldStock = rows.isEmpty ? 0 : (rows.first['stock'] as int? ?? 0);
      final oldCost = rows.isEmpty ? 0.0 : ((rows.first['cost_price'] as num?)?.toDouble() ?? 0.0);

      final blendedCost = oldStock > 0
          ? (oldStock * oldCost + retailUnits * newUnitCost) / (oldStock + retailUnits)
          : newUnitCost;

      // Update product stock and blended cost price
      await txn.rawUpdate(
        'UPDATE products SET stock = stock + ?, cost_price = ?, is_bulk_convertible = 1, wholesale_unit_name = ?, conversion_factor = ? WHERE id = ?',
        [retailUnits, blendedCost, unitName, conversionFactor, productId],
      );

      // Log the purchase (unit_cost = this batch's cost, not the blended one)
      await txn.insert('purchases', {
        'product_id': productId,
        'quantity_wholesale_units': wholesaleUnits,
        'quantity_retail_units': retailUnits,
        'total_cost': totalCost,
        'unit_cost': newUnitCost,
        'wholesale_unit_name': unitName,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  /// Single unit restock: adds stock, blends cost with weighted average
  Future<void> singleRestock({
    required int productId,
    required int quantity,
    required double totalCost,
  }) async {
    final db = await database;
    if (quantity <= 0) return;
    final newUnitCost = totalCost / quantity;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'products',
        columns: ['stock', 'cost_price'],
        where: 'id = ?',
        whereArgs: [productId],
      );
      final oldStock = rows.isEmpty ? 0 : (rows.first['stock'] as int? ?? 0);
      final oldCost = rows.isEmpty ? 0.0 : ((rows.first['cost_price'] as num?)?.toDouble() ?? 0.0);

      final blendedCost = oldStock > 0
          ? (oldStock * oldCost + quantity * newUnitCost) / (oldStock + quantity)
          : newUnitCost;

      await txn.rawUpdate(
        'UPDATE products SET stock = stock + ?, cost_price = ? WHERE id = ?',
        [quantity, blendedCost, productId],
      );

      await txn.insert('purchases', {
        'product_id': productId,
        'quantity_wholesale_units': 1,
        'quantity_retail_units': quantity,
        'total_cost': totalCost,
        'unit_cost': newUnitCost,
        'wholesale_unit_name': '',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  // ==================== BULK ORDERS ====================

  /// Bulk order: user buys N packs of a product, each pack contains
  /// [conversionFactor] retail units.  Updates stock AND packs count,
  /// logs the purchase, and blends the cost price.
  Future<void> bulkOrder({
    required int productId,
    required int quantity,          // number of packs bought
    required double totalCost,      // what was paid (total or per-pack)
    required int conversionFactor,  // units inside one pack
    required String name,           // e.g. "Ballet D'eau"
    required bool isPriceTotal,     // true = totalCost is the batch total
  }) async {
    final db = await database;
    final retailUnits = quantity * conversionFactor;
    if (retailUnits <= 0) return;
    final effectiveCost = isPriceTotal ? totalCost : totalCost * quantity;
    final newUnitCost = effectiveCost / retailUnits;

    await db.transaction((txn) async {
      // Read current stock + cost for weighted average
      final rows = await txn.query(
        'products',
        columns: ['stock', 'cost_price'],
        where: 'id = ?',
        whereArgs: [productId],
      );
      final oldStock = rows.isEmpty ? 0 : (rows.first['stock'] as int? ?? 0);
      final oldCost = rows.isEmpty ? 0.0 : ((rows.first['cost_price'] as num?)?.toDouble() ?? 0.0);

      final blendedCost = oldStock > 0
          ? (oldStock * oldCost + retailUnits * newUnitCost) / (oldStock + retailUnits)
          : newUnitCost;

      // Update stock, packs, cost, and bulk config
      await txn.rawUpdate(
        'UPDATE products SET stock = stock + ?, packs = packs + ?, cost_price = ?, '
        'is_bulk_convertible = 1, wholesale_unit_name = ?, conversion_factor = ? WHERE id = ?',
        [retailUnits, quantity, blendedCost, name, conversionFactor, productId],
      );

      // Log the purchase
      await txn.insert('purchases', {
        'product_id': productId,
        'quantity_wholesale_units': quantity,
        'quantity_retail_units': retailUnits,
        'total_cost': effectiveCost,
        'unit_cost': newUnitCost,
        'wholesale_unit_name': name,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  // ==================== BULK PRESETS ====================

  Future<List<BulkPreset>> getBulkPresets(int productId) async {
    final db = await database;
    final result = await db.query(
      'bulk_presets',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'id ASC',
    );
    return result.map((map) => BulkPreset.fromMap(map)).toList();
  }

  Future<int> insertBulkPreset(BulkPreset preset) async {
    final db = await database;
    return await db.insert('bulk_presets', preset.toMap());
  }

  /// First preset per product, keyed by product id — one query for list views.
  Future<Map<int, BulkPreset>> getFirstPresetPerProduct() async {
    final db = await database;
    final result = await db.query('bulk_presets', orderBy: 'id ASC');
    final map = <int, BulkPreset>{};
    for (final row in result) {
      final preset = BulkPreset.fromMap(row);
      map.putIfAbsent(preset.productId, () => preset);
    }
    return map;
  }

  Future<int> updateBulkPreset(BulkPreset preset) async {
    final db = await database;
    return await db.update('bulk_presets', preset.toMap(),
        where: 'id = ?', whereArgs: [preset.id]);
  }

  Future<int> deleteBulkPreset(int id) async {
    final db = await database;
    return await db.delete('bulk_presets', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== SHOP ====================

  Future<Shop> getShop() async {
    final db = await database;
    final result = await db.query('shop', limit: 1);
    if (result.isEmpty) return const Shop();
    return Shop.fromMap(result.first);
  }

  Future<void> upsertShop(Shop shop) async {
    final db = await database;
    final result = await db.query('shop', limit: 1);
    if (result.isEmpty) {
      await db.insert('shop', shop.toMap());
    } else {
      await db.update('shop', shop.toMap(), where: 'id = ?', whereArgs: [result.first['id']]);
    }
  }

  // ==================== PATH ====================

  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'algerian_billing.db');
  }

  // ==================== IMPORT/EXPORT ====================

  Future<List<Map<String, dynamic>>> exportProductsAsMaps() async {
    final db = await database;
    return await db.query('products', orderBy: 'id ASC');
  }

  Future<int> importProductsFromMaps(List<Map<String, dynamic>> products) async {
    final db = await database;
    int count = 0;
    await db.transaction((txn) async {
      for (var productMap in products) {
        productMap.remove('id');
        await txn.insert('products', productMap);
        count++;
      }
    });
    return count;
  }
}
