# Selective Merge Engine — Implementation Plan

## Overview
Replace the simple CSV import with a full backup/restore system using `.abp` files (ZIP archives containing the SQLite database). Add a diff engine that compares incoming data against the local database, presents an interactive preview UI, and lets the user selectively merge changes.

## Pre-requisite: Backup Current State
1. Create a zip of the entire `algerian_billing_app/` project directory (excluding `build/`, `.dart_tool/`, `.gradle/`)
2. Save as `algerian_billing_app_backup_2026-09-12.zip` in `E:/Billing app/`

---

## New Dependencies
- `archive: ^3.6.0` — ZIP creation/extraction (already transitive dep of `pdf`, but we'll declare it explicitly)
- No new packages needed — `file_picker` and `share_plus` already installed

---

## Architecture — 4 New Files + 4 Modified Files

### New Files

#### 1. `lib/services/backup_service.dart` — Core Backup/Restore Engine
**Responsibilities:**
- `createBackup({required List<String> sections})` → generates `.abp` file (ZIP containing `data.db` + `manifest.json`)
- `extractBackup(String filePath)` → extracts to temp dir, returns `BackupManifest`
- `computeDiff({required String incomingDbPath})` → `ImportDiff` comparing incoming vs local DB
- `executeMerge({required ImportDiff diff, required List<String> selectedSections})` → transactional merge

**Backup format (`.abp` = ZIP):**
```
backup.abp
├── data.db          (copy of SQLite database)
└── manifest.json    (metadata: timestamp, app version, shop name, sections included)
```

**Manifest JSON structure:**
```json
{
  "version": "1.0.0",
  "createdAt": "2026-09-12T10:30:00",
  "shopName": "Mon Magasin",
  "sections": ["invoices", "products", "customers", "categories"],
  "counts": {
    "invoices": 142,
    "products": 89,
    "customers": 23,
    "categories": 5
  }
}
```

**Diff Logic (`computeDiff`):**
Opens the incoming DB as a separate SQLite connection (read-only). Compares each table:

| Section | Diff Logic | Merge Strategy |
|---------|-----------|----------------|
| **Invoices + Items** | Find invoices in incoming NOT in local (match by `invoiceNumber`) | `INSERT OR IGNORE` — new invoices + their items |
| **Products** | Match by `barcode` (if non-empty) or `name`. Detect: new products, price changes, stock changes | New → INSERT. Existing → UPDATE price/stock if user toggles |
| **Customers** | Match by `name` + `phoneNumber`. Detect: new customers, debt changes | New → INSERT. Existing → UPDATE if debt changed |
| **Categories** | Match by `name`. Detect new categories | `INSERT OR IGNORE` |

**ImportDiff data class:**
```dart
class ImportDiff {
  final List<InvoiceDiff> newInvoices;        // invoices not in local
  final List<ProductDiff> productChanges;      // new + modified products
  final List<CustomerDiff> customerChanges;    // new + modified customers
  final List<Category> newCategories;          // new categories
  final Map<String, int> summary;              // counts per section
}
```

**Merge Execution:**
- Wraps everything in `db.transaction()`
- For invoices: `INSERT OR IGNORE` (keyed on invoiceNumber)
- For products: INSERT new, UPDATE existing (price/stock) based on user selection
- For customers: INSERT new, UPDATE debt for existing
- Returns success/failure count

#### 2. `lib/models/backup_models.dart` — Data Classes
```dart
class BackupManifest { version, createdAt, shopName, sections, counts }
class ImportDiff { newInvoices, productChanges, customerChanges, newCategories, summary }
class InvoiceDiff { Invoice invoice, List<InvoiceItem> items, bool alreadyExists }
class ProductDiff { Product incoming, Product? existing, DiffType type } // DiffType: new, priceChanged, stockChanged, both
class CustomerDiff { Customer incoming, Customer? existing, double? debtChange }
```

#### 3. `lib/views/screens/import_preview_screen.dart` — Interactive Merge UI
**Layout:**
```
┌─────────────────────────────────────┐
│ Import Preview                  [X] │
├─────────────────────────────────────┤
│ Select All                           │
│ ☑ Import New Invoices (14)           │
│ ☑ Update Inventory Stock (22 items)  │
│ ☐ Update Prices (3 items)            │
│    ├ Eau Minerale   50 → 55 DA       │
│    ├ Jus d'Orange   80 → 85 DA       │
│    └ Cafe Torrefie  120 → 130 DA     │
│ ☑ Sync Customer Debt (5 customers)   │
│ ☑ Import New Categories (2)          │
├─────────────────────────────────────┤
│ [████████████░░░░] 75%               │  ← shown during merge
│                                       │
│ [     Merge Selected     ]            │
└─────────────────────────────────────┘
```

**UI Components:**
- `SelectableSection` widget — checkbox + title + count badge, expandable child
- Price change list — shows old → new with color coding (green = lower, red = higher)
- Progress bar during merge execution
- "Master Toggle" checkbox at top

**Flow:**
1. User picks `.abp` file via FilePicker
2. Screen shows loading spinner while `extractBackup()` + `computeDiff()` run
3. Preview sections render with checkboxes
4. User toggles sections on/off
5. User taps "Merge Selected"
6. Progress bar runs during `executeMerge()`
7. On success: show snackbar, pop back to previous screen, invalidate providers

#### 4. `lib/views/screens/export_settings_screen.dart` — Export Configuration
**Layout:**
```
┌─────────────────────────────────────┐
│ Export Settings                 [X] │
├─────────────────────────────────────┤
│ Quick Export Presets:                │
│                                       │
│ [Full Backup]     ← selects all      │
│ [Sales Only]      ← invoices only    │
│ [Inventory Only]  ← products+cats    │
│ [Customers Only]  ← customers only   │
│                                       │
│ Custom Selection:                     │
│ ☑ Invoices & Sales                   │
│ ☑ Products & Inventory               │
│ ☑ Customers & Debt                   │
│ ☑ Categories                         │
│ ☐ Shop Settings                      │
│                                       │
│ [      Export .abp File      ]        │
└─────────────────────────────────────┘
```

### Modified Files

#### 5. `lib/services/database_service.dart`
**Add methods:**
- `getDatabasePath()` — expose the DB file path for backup copy
- `backupDatabaseToPath(String destPath)` — raw file copy of the DB
- `getIncomingDatabase(String path)` — opens a second DB connection for diff
- `insertInvoiceIfNew(Invoice, List<InvoiceItem>)` — INSERT OR IGNORE
- `upsertProduct(Product)` — INSERT OR UPDATE by barcode
- `upsertCustomer(Customer)` — INSERT OR UPDATE by name+phone
- `bulkMerge({...})` — transactional wrapper

#### 6. `lib/views/screens/inventory_screen.dart`
**Modify the import/export menu:**
- "Export CSV" stays as-is for products
- "Import CSV" stays as-is for products
- Add new menu items:
  - "Export Backup (.abp)" → navigates to export_settings_screen
  - "Import Backup (.abp)" → opens file picker for .abp, navigates to import_preview_screen

#### 7. `lib/l10n/app_localizations_fr.dart` + `app_localizations_ar.dart`
**Add ~30 new translation keys:**
- `backup`, `restore`, `import_preview`, `export_settings`
- `new_invoices`, `product_changes`, `customer_changes`, `new_categories`
- `select_all`, `merge_selected`, `merge_complete`, `merge_error`
- `old_price`, `new_price`, `price_changed`, `stock_changed`
- `debt_change`, `export_full`, `export_sales_only`, `export_inventory_only`
- etc.

#### 8. `lib/app.dart` or router config
**Add routes:**
- `/import-preview` → ImportPreviewScreen
- `/export-settings` → ExportSettingsScreen

---

## Implementation Order

1. **Backup current project** → zip the whole directory
2. **`backup_models.dart`** — pure data classes, no dependencies
3. **`backup_service.dart`** — core engine with diff + merge logic
4. **Add DB methods** to `database_service.dart` — upsert helpers, incoming DB reader
5. **`import_preview_screen.dart`** — the interactive preview UI
6. **`export_settings_screen.dart`** — export configuration screen
7. **Update inventory_screen.dart** — add menu items for backup/restore
8. **Add routes** to router config
9. **Add translations** to FR and AR locale files
10. **Add `archive` to pubspec.yaml** if not already available
11. **Flutter analyze → build → install**

## Risk Mitigation
- All merge operations wrapped in SQLite transactions — if anything fails, DB rolls back
- Incoming DB opened as read-only — never modifies the backup file
- `INSERT OR IGNORE` prevents duplicate invoices
- Backup before merge: auto-create a safety backup of current DB before merging
- Progress bar + error handling with user-facing messages
