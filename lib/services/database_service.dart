import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/invoice.dart';
import '../models/category.dart';
import '../models/shop.dart';

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
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        // Safety: ensure critical columns always exist
        await _ensureColumn(db, 'invoices', 'paidAmount', 'REAL DEFAULT 0.0');
        await _ensureColumn(db, 'invoices', 'customerName', "TEXT DEFAULT ''");
        await _ensureColumn(db, 'invoices', 'customerPhone', "TEXT DEFAULT ''");
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
    await db.rawUpdate(
      'UPDATE products SET stock = MAX(0, stock + ?) WHERE id = ?',
      [quantityChange, productId],
    );
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
