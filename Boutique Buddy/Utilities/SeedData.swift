//
//  SeedData.swift
//  Boutique Buddy
//

import Foundation
import SwiftData

enum SeedData {
    static func ensureDefaults(in context: ModelContext) {
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        var settings = (try? context.fetch(settingsDescriptor))?.first

        if settings == nil {
            let created = AppSettings()
            context.insert(created)
            settings = created
        }

        // Migrate legacy `shopName` → `brandName` from earlier builds.
        if let settings {
            let legacy = settings.shopName.trimmingCharacters(in: .whitespacesAndNewlines)
            let current = settings.brandName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !legacy.isEmpty, current.isEmpty || current == "Boutique Buddy" {
                if legacy != "Boutique Buddy" || current.isEmpty {
                    settings.brandName = legacy
                }
            }
            if !legacy.isEmpty {
                settings.shopName = ""
            }
            if settings.brandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                settings.brandName = "Boutique Buddy"
            }
            if settings.thankYouNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                settings.thankYouNote = "Thank you for shopping with us! 🙏"
            }
        }

        seedCategoriesIfNeeded(in: context, settings: settings)

        let itemCount = (try? context.fetchCount(FetchDescriptor<InventoryItem>())) ?? 0
        if settings?.hasSeededDemoData != true, itemCount == 0 {
            loadDemoData(in: context)
            settings?.hasSeededDemoData = true
        }

        try? context.save()
    }

    /// Inserts sample shop data for evaluation. Safe to call only on an empty inventory,
    /// or after clearing data intentionally.
    @discardableResult
    static func loadDemoData(in context: ModelContext) -> String {
        seedCategoriesIfNeeded(in: context, settings: (try? context.fetch(FetchDescriptor<AppSettings>()))?.first)

        let categories = (try? context.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        guard let suits = categories.first(where: { $0.name == "Suits" }),
              let footwear = categories.first(where: { $0.name == "Footwear" }),
              let jewellery = categories.first(where: { $0.name == "Jewellery" }) else {
            return "Categories missing — open the app once, then try again."
        }

        let calendar = Calendar.current
        func daysAgo(_ n: Int) -> Date {
            calendar.date(byAdding: .day, value: -n, to: Date()) ?? Date()
        }

        // MARK: Items + purchases
        struct DemoItem {
            let name: String
            let sku: String
            let category: Category
            let subType: String?
            let cost: Decimal
            let mrp: Decimal
            let qty: Int
            let supplier: String
            let purchaseDaysAgo: Int
        }

        let demoItems: [DemoItem] = [
            .init(name: "Pink Georgette Suit", sku: "SUI-0001", category: suits, subType: "Stitched", cost: 1800, mrp: 2590, qty: 8, supplier: "Jaipur Fabrics", purchaseDaysAgo: 21),
            .init(name: "Navy Anarkali Suit", sku: "SUI-0002", category: suits, subType: "Stitched", cost: 2200, mrp: 3190, qty: 5, supplier: "Jaipur Fabrics", purchaseDaysAgo: 21),
            .init(name: "Cream Cotton Suit Set", sku: "SUI-0003", category: suits, subType: "Unstitched", cost: 950, mrp: 1490, qty: 12, supplier: "Surat Textiles", purchaseDaysAgo: 14),
            .init(name: "Floral Print Unstitched", sku: "SUI-0004", category: suits, subType: "Unstitched", cost: 1100, mrp: 1690, qty: 10, supplier: "Surat Textiles", purchaseDaysAgo: 14),
            .init(name: "Maroon Velvet Suit", sku: "SUI-0005", category: suits, subType: "Stitched", cost: 2800, mrp: 3990, qty: 3, supplier: "Delhi Wholesale", purchaseDaysAgo: 10),
            .init(name: "Black Kolhapuri Flats", sku: "FOO-0001", category: footwear, subType: nil, cost: 450, mrp: 799, qty: 15, supplier: "Agra Shoes", purchaseDaysAgo: 18),
            .init(name: "Beige Block Heels", sku: "FOO-0002", category: footwear, subType: nil, cost: 680, mrp: 1190, qty: 7, supplier: "Agra Shoes", purchaseDaysAgo: 18),
            .init(name: "Gold Embellished Juttis", sku: "FOO-0003", category: footwear, subType: nil, cost: 520, mrp: 990, qty: 2, supplier: "Agra Shoes", purchaseDaysAgo: 7),
            .init(name: "Pearl Drop Earrings", sku: "JEW-0001", category: jewellery, subType: nil, cost: 180, mrp: 399, qty: 20, supplier: "Jaipur Jewels", purchaseDaysAgo: 12),
            .init(name: "Kundan Necklace Set", sku: "JEW-0002", category: jewellery, subType: nil, cost: 850, mrp: 1490, qty: 6, supplier: "Jaipur Jewels", purchaseDaysAgo: 12),
            .init(name: "Oxidised Bangle Pair", sku: "JEW-0003", category: jewellery, subType: nil, cost: 220, mrp: 449, qty: 1, supplier: "Jaipur Jewels", purchaseDaysAgo: 5),
            .init(name: "Mint Green Palazzo Suit", sku: "SUI-0006", category: suits, subType: "Stitched", cost: 1600, mrp: 2390, qty: 0, supplier: "Jaipur Fabrics", purchaseDaysAgo: 30)
        ]

        var itemsBySKU: [String: InventoryItem] = [:]

        for demo in demoItems {
            let item = InventoryItem(
                name: demo.name,
                sku: demo.sku,
                category: demo.category,
                subType: demo.subType,
                costPrice: demo.cost,
                mrp: demo.mrp,
                quantityOnHand: demo.qty,
                dateAdded: daysAgo(demo.purchaseDaysAgo),
                supplier: demo.supplier
            )
            context.insert(item)

            let purchase = PurchaseRecord(
                item: item,
                quantity: demo.qty + purchaseBuffer(for: demo.sku),
                costPriceAtPurchase: demo.cost,
                purchaseDate: daysAgo(demo.purchaseDaysAgo),
                supplier: demo.supplier,
                source: .manual,
                notes: "Demo stock-in"
            )
            context.insert(purchase)
            item.quantityOnHand = demo.qty + purchaseBuffer(for: demo.sku)

            itemsBySKU[demo.sku] = item
        }

        // MARK: Parties
        let meena = Party(name: "Meena Sharma", phone: "98765 43210", address: "Sector 14, near temple", notes: "Prefers stitched suits", dateAdded: daysAgo(20))
        let priya = Party(name: "Priya Verma", phone: "98111 22334", address: "Village Road, House 42", dateAdded: daysAgo(15))
        let anjali = Party(name: "Anjali Gupta", phone: "99001 12233", notes: "Regular jewellery customer", dateAdded: daysAgo(10))
        let sunita = Party(name: "Sunita Devi", phone: "98220 55667", dateAdded: daysAgo(8))
        let kavita = Party(name: "Kavita Jain", phone: "97888 44556", address: "Main Market", dateAdded: daysAgo(3))

        for party in [meena, priya, anjali, sunita, kavita] {
            context.insert(party)
        }

        // Opening balances
        context.insert(LedgerTransaction(party: meena, date: daysAgo(20), type: .openingBalance, amount: 1500, notes: "Brought forward from old register"))
        context.insert(LedgerTransaction(party: priya, date: daysAgo(15), type: .openingBalance, amount: 800, notes: "Opening balance"))
        context.insert(LedgerTransaction(party: anjali, date: daysAgo(10), type: .openingBalance, amount: -200, notes: "Advance paid earlier"))

        // MARK: Sales (reduces stock from purchase buffer down toward demo qty)
        struct DemoSale {
            let sku: String
            let daysAgo: Int
            let qty: Int
            let price: Decimal?
            let party: Party?
            let mode: PaymentMode
            let received: Decimal? // nil = full net
            let notes: String?
            var discountType: DiscountType = .none
            var discountValue: Decimal = 0
        }

        let sales: [DemoSale] = [
            .init(sku: "SUI-0001", daysAgo: 6, qty: 1, price: 2590, party: meena, mode: .upi, received: nil, notes: nil),
            .init(sku: "JEW-0001", daysAgo: 6, qty: 2, price: 399, party: nil, mode: .cash, received: nil, notes: "Walk-in"),
            .init(sku: "FOO-0001", daysAgo: 5, qty: 1, price: 799, party: sunita, mode: .cash, received: nil, notes: "₹49 off", discountType: .flatAmount, discountValue: 49),
            .init(sku: "SUI-0003", daysAgo: 5, qty: 2, price: 1490, party: priya, mode: .credit, received: 1000, notes: "Partial payment"),
            .init(sku: "JEW-0002", daysAgo: 4, qty: 1, price: 1490, party: anjali, mode: .upi, received: nil, notes: nil),
            .init(sku: "SUI-0002", daysAgo: 3, qty: 1, price: 3190, party: kavita, mode: .mixed, received: 2000, notes: "Cash + UPI later", discountType: .percentage, discountValue: 5),
            .init(sku: "FOO-0002", daysAgo: 3, qty: 1, price: 1190, party: nil, mode: .card, received: nil, notes: nil),
            .init(sku: "SUI-0004", daysAgo: 2, qty: 1, price: 1690, party: meena, mode: .upi, received: nil, notes: nil),
            .init(sku: "JEW-0001", daysAgo: 2, qty: 1, price: 399, party: nil, mode: .cash, received: nil, notes: nil),
            .init(sku: "FOO-0003", daysAgo: 1, qty: 1, price: 990, party: sunita, mode: .upi, received: nil, notes: nil),
            .init(sku: "SUI-0005", daysAgo: 1, qty: 1, price: 3990, party: priya, mode: .credit, received: 0, notes: "Full credit — wedding order"),
            .init(sku: "SUI-0001", daysAgo: 0, qty: 1, price: 2590, party: nil, mode: .cash, received: nil, notes: "Today walk-in"),
            .init(sku: "JEW-0003", daysAgo: 0, qty: 1, price: 449, party: anjali, mode: .upi, received: nil, notes: nil),
            .init(sku: "FOO-0001", daysAgo: 0, qty: 2, price: 799, party: kavita, mode: .cash, received: nil, notes: nil),
            .init(sku: "SUI-0006", daysAgo: 8, qty: 2, price: 2390, party: meena, mode: .upi, received: nil, notes: "Sold out set")
        ]

        for demo in sales {
            guard let item = itemsBySKU[demo.sku] else { continue }
            let price = demo.price ?? item.mrp
            let gross = price * Decimal(demo.qty)
            let net = SalePricing.netAmount(gross: gross, type: demo.discountType, value: demo.discountValue)
            let received = demo.received ?? net
            let date = daysAgo(demo.daysAgo)

            let sale = SaleEntry(
                date: date,
                item: item,
                quantity: demo.qty,
                salePrice: price,
                party: demo.party,
                paymentMode: demo.mode,
                amountReceived: received,
                notes: demo.notes,
                source: .manual,
                isUntrackedCredit: false,
                discountType: demo.discountType,
                discountValue: demo.discountValue
            )
            context.insert(sale)
            item.quantityOnHand -= demo.qty

            let pending = sale.pendingAmount
            if pending > 0, let party = demo.party {
                context.insert(LedgerTransaction(
                    party: party,
                    date: date,
                    type: .saleOnCredit,
                    amount: pending,
                    relatedSaleEntry: sale,
                    notes: "Credit from sale of \(item.name)"
                ))
            }
        }

        // Payments received
        context.insert(LedgerTransaction(
            party: meena,
            date: daysAgo(4),
            type: .paymentReceived,
            amount: -1000,
            notes: "via UPI · Partial clearance"
        ))
        context.insert(LedgerTransaction(
            party: priya,
            date: daysAgo(2),
            type: .paymentReceived,
            amount: -500,
            notes: "via Cash"
        ))

        if let settings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first {
            settings.hasSeededDemoData = true
        }

        try? context.save()
        return "Demo data loaded: 12 items, 5 customers, 15 sales."
    }

    /// Extra units purchased beyond the “final” on-hand target, consumed by demo sales.
    private static func purchaseBuffer(for sku: String) -> Int {
        switch sku {
        case "SUI-0001": return 2
        case "SUI-0002": return 1
        case "SUI-0003": return 2
        case "SUI-0004": return 1
        case "SUI-0005": return 1
        case "SUI-0006": return 2
        case "FOO-0001": return 3
        case "FOO-0002": return 1
        case "FOO-0003": return 1
        case "JEW-0001": return 3
        case "JEW-0002": return 1
        case "JEW-0003": return 1
        default: return 0
        }
    }

    private static func seedCategoriesIfNeeded(in context: ModelContext, settings: AppSettings?) {
        let categoryDescriptor = FetchDescriptor<Category>()
        let existingCategories = (try? context.fetch(categoryDescriptor)) ?? []
        if existingCategories.isEmpty {
            let defaults: [(String, [String], Int)] = [
                ("Suits", ["Stitched", "Unstitched"], 0),
                ("Footwear", [], 1),
                ("Jewellery", [], 2)
            ]
            for (name, subTypes, order) in defaults {
                context.insert(Category(
                    name: name,
                    subTypes: subTypes,
                    defaultMarkupPercent: 40,
                    sortOrder: order
                ))
            }
            settings?.hasSeededCategories = true
        }
    }
}
