# Boutique Buddy

Offline-first macOS app for running a small ladies’ boutique — inventory, daily sales, customer ledgers, and shareable receipts. Built with **SwiftUI** and **SwiftData**. No login, no cloud, no internet required.

## Features

### Inventory (Items)
- Track stock with categories and sub-types (Suits · Stitched/Unstitched, Footwear, Jewellery)
- Add purchases manually or via CSV import
- Auto-generated SKUs, cost price and MRP, low-stock flags
- Soft-archive items so historical sales stay linked

### Daily Entries
- Log sales quickly with searchable item and customer pickers
- Discounts (% or ₹), live summary of gross / net / paid / pending
- Partial payments and credit sales with automatic ledger entries
- Payment entries (received / paid) from the same Add Entry window
- Journal list merges sales and payments by day
- CSV import for bulk sales

### Parties (Customers)
- Customer list with running balance (who owes whom)
- Opening balances, receive / make payments
- Full ledger with running balance per line
- Share account statement as an image

### Receipts & Sharing
- Copy sale receipts or account statements to the clipboard
- Paper-style design with stitch dividers and scalloped edge
- Share via the standard macOS share sheet (Messages, Mail, AirDrop, Save Image)
- Brand name, logo, address, and phone from Settings

### Tools & Settings
- Manage categories and default markup %
- Smart Price — suggest MRP from cost + category markup
- Barcode / price label printing (Code128 from SKU)
- Backup and restore of the local data store
- Automatic local backups on quit
- Shop Settings (⌘,) for brand identity and thank-you note

### Design principles
- Single-user, single-shop, ₹ (INR)
- Fully offline — all data stays on your Mac
- Overselling allowed with a warning (real shops often record sales before stock-in)

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+ to build

## Getting started

1. Open `Boutique Buddy.xcodeproj` in Xcode
2. Select the **Boutique Buddy** scheme
3. Run with **⌘R**

First launch seeds default categories and optional demo data for evaluation. Use **Tools → Load Demo Data** or **Reset Shop Data** as needed.

## Project structure

```
Boutique Buddy/
├── Models/          # SwiftData models (Item, Sale, Party, Ledger, …)
├── Views/           # Dashboard, Entries, Items, Parties, Tools, Settings, Sharing
├── Utilities/       # CSV, pricing, backup, barcodes, image sharing
└── Assets.xcassets
```

## License

Personal use. Not distributed on the App Store.
