# Algerian Billing ERP

## What is it?

A mobile billing and inventory management app built for small Algerian stores — grocery shops, pharmacies, mini-markets, and similar businesses. It runs on Android phones and tablets, works offline (no internet needed), and supports French and Arabic with RTL.

## Problems it solves

### 1. Manual billing is slow and error-prone
Cashiers often handwrite receipts or use basic calculators. This leads to wrong totals, forgotten items, and slow queues. The app lets you scan barcodes or tap products to add them to a cart, calculates the total instantly, and prints a receipt on a Bluetooth thermal printer in seconds.

### 2. No track of daily sales
Most small shops don't know how much they sold today until they manually count the cash drawer. The dashboard shows real-time daily stats — total revenue, number of transactions, items sold — so the owner always knows the business performance at a glance.

### 3. Credit/trust customers are hard to manage
In Algeria, it's common for regular customers to buy on credit ("aversa") and pay later. Tracking who owes what, how much, and for which invoices gets chaotic with paper. The app groups invoices by customer, shows total debt per person, and lets you record partial or full payments instantly.

### 4. Inventory is managed by memory
When stock runs out, shop owners often realize only after a customer asks for a product. The inventory screen tracks stock levels with color-coded warnings (green = good, orange = low, red = out of stock). You can export/import your product list via CSV to back it up or update it in bulk.

### 5. No professional receipts
Handwritten notes don't look professional and often miss details. The app generates clean, formatted receipts with shop name, address, phone, itemized list, totals, and payment method — printed on thermal paper or shared as PDF.

### 6. Language barrier
Many Algerian shop owners speak Arabic, French, or both. The app supports both languages with a single tap toggle, including full RTL layout for Arabic.

## Features

| Feature | What it does |
|---|---|
| **POS (Point of Sale)** | Scan barcodes or tap products to build a cart, checkout with cash or credit |
| **Dashboard** | Daily summary — revenue, transactions, items sold |
| **Inventory** | Add/edit/delete products, stock tracking, CSV export/import |
| **Credit Management** | Track customer debts, record payments, view history |
| **Invoices** | Browse all invoices, print receipts, download as PDF |
| **Thermal Printer** | Direct Bluetooth printing to ESC/POS thermal printers |
| **Bilingual** | French and Arabic with full RTL support |
| **Offline** | Everything stored locally in SQLite — no internet required |

## Tech stack

- **Flutter** (Dart) — cross-platform UI
- **SQLite** (sqflite) — local database
- **Riverpod** — state management
- **go_router** — navigation
- **print_bluetooth_thermal** — thermal printer communication
- **pdf** — PDF generation
- **mobile_scanner** — barcode scanning
- **share_plus** — file sharing (PDF receipts)
- **file_picker** — CSV import from file explorer
