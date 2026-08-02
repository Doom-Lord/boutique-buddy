//
//  PurchaseCSVImportView.swift
//  Boutique Buddy
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

struct PurchaseCSVImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var existingItems: [InventoryItem]

    @State private var table: CSVTable?
    @State private var columnMapping: [String: Int] = [:]
    @State private var summary: CSVImportSummary?
    @State private var categoryRemap: [String: UUID] = [:]
    @State private var unmatchedCategories: [String] = []
    @State private var errorMessage: String?

    private let expectedColumns = [
        "Item Name", "SKU", "Category", "Sub-Type", "Cost Price",
        "MRP", "Quantity", "Purchase Date", "Supplier", "Notes"
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if let summary {
                    summaryView(summary)
                } else if let table {
                    if !unmatchedCategories.isEmpty {
                        categoryMappingSection
                    }
                    mappingSection(table)
                    previewSection(table)
                } else {
                    ContentUnavailableView {
                        Label("Import Purchases", systemImage: "square.and.arrow.down")
                    } description: {
                        Text("CSV columns: Item Name, SKU, Category, Sub-Type, Cost Price, MRP, Quantity, Purchase Date, Supplier, Notes")
                    } actions: {
                        Button("Choose CSV File…") { pickFile() }
                            .buttonStyle(.borderedProminent)
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle("Import Purchases CSV")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(summary == nil ? "Cancel" : "Done") { dismiss() }
                }
                if table != nil, summary == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import") { runImport() }
                            .disabled(!unmatchedCategories.allSatisfy { categoryRemap[$0] != nil })
                    }
                }
            }
        }
    }

    private func summaryView(_ summary: CSVImportSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(summary.imported) imported, \(summary.skipped.count) skipped")
                .font(.title2.bold())
            if summary.hasSkips {
                List(summary.skipped, id: \.row) { skip in
                    Text("Row \(skip.row): \(skip.reason)")
                        .font(.caption)
                }
            }
        }
    }

    private var categoryMappingSection: some View {
        GroupBox("Unmatched Categories") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Map these CSV categories to existing ones:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(unmatchedCategories, id: \.self) { name in
                    HStack {
                        Text(name).frame(width: 140, alignment: .leading)
                        Picker("Map to", selection: Binding(
                            get: { categoryRemap[name] },
                            set: { categoryRemap[name] = $0 }
                        )) {
                            Text("Select…").tag(UUID?.none)
                            ForEach(categories) { cat in
                                Text(cat.name).tag(Optional(cat.id))
                            }
                        }
                    }
                }
            }
            .padding(8)
        }
    }

    private func mappingSection(_ table: CSVTable) -> some View {
        GroupBox("Column Mapping") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 8) {
                ForEach(expectedColumns, id: \.self) { col in
                    HStack {
                        Text(col).frame(width: 110, alignment: .leading)
                        Picker("", selection: Binding(
                            get: { columnMapping[col] ?? -1 },
                            set: { columnMapping[col] = $0 }
                        )) {
                            Text("—").tag(-1)
                            ForEach(Array(table.headers.enumerated()), id: \.offset) { index, header in
                                Text(header.isEmpty ? "(col \(index + 1))" : header).tag(index)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }
            .padding(8)
        }
    }

    private func previewSection(_ table: CSVTable) -> some View {
        GroupBox("Preview (first 10 rows)") {
            ScrollView([.horizontal, .vertical]) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                    GridRow {
                        ForEach(expectedColumns, id: \.self) { col in
                            Text(col).font(.caption.bold())
                        }
                    }
                    ForEach(Array(table.rows.prefix(10).enumerated()), id: \.offset) { _, row in
                        GridRow {
                            ForEach(expectedColumns, id: \.self) { col in
                                Text(CSVParser.value(in: row, mapping: columnMapping, key: col))
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 200)
        }
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            let parsed = CSVParser.parse(contents: contents)
            table = parsed
            columnMapping = autoMap(headers: parsed.headers)
            detectUnmatchedCategories(in: parsed)
            errorMessage = nil
        } catch {
            errorMessage = "Could not read file: \(error.localizedDescription)"
        }
    }

    private func autoMap(headers: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        let aliases: [String: [String]] = [
            "Item Name": ["item name", "name", "item"],
            "SKU": ["sku", "code"],
            "Category": ["category", "cat"],
            "Sub-Type": ["sub-type", "subtype", "sub type", "type"],
            "Cost Price": ["cost price", "cost", "cp"],
            "MRP": ["mrp", "price", "selling price"],
            "Quantity": ["quantity", "qty", "stock"],
            "Purchase Date": ["purchase date", "date"],
            "Supplier": ["supplier", "vendor"],
            "Notes": ["notes", "note", "remark"]
        ]
        for (key, names) in aliases {
            if let index = headers.firstIndex(where: { header in
                names.contains { header.compare($0, options: .caseInsensitive) == .orderedSame }
            }) {
                map[key] = index
            } else {
                map[key] = -1
            }
        }
        return map
    }

    private func detectUnmatchedCategories(in table: CSVTable) {
        var found = Set<String>()
        for row in table.rows {
            let name = CSVParser.value(in: row, mapping: columnMapping, key: "Category")
            guard !name.isEmpty else { continue }
            let match = categories.contains {
                $0.name.compare(name, options: .caseInsensitive) == .orderedSame
            }
            if !match { found.insert(name) }
        }
        unmatchedCategories = found.sorted()
    }

    private func runImport() {
        guard let table else { return }
        var result = CSVImportSummary()

        for (index, row) in table.rows.enumerated() {
            let rowNumber = index + 2
            let name = CSVParser.value(in: row, mapping: columnMapping, key: "Item Name")
            let skuValue = CSVParser.value(in: row, mapping: columnMapping, key: "SKU")
            let categoryName = CSVParser.value(in: row, mapping: columnMapping, key: "Category")
            let subType = CSVParser.value(in: row, mapping: columnMapping, key: "Sub-Type")
            let costText = CSVParser.value(in: row, mapping: columnMapping, key: "Cost Price")
            let mrpText = CSVParser.value(in: row, mapping: columnMapping, key: "MRP")
            let qtyText = CSVParser.value(in: row, mapping: columnMapping, key: "Quantity")
            let dateText = CSVParser.value(in: row, mapping: columnMapping, key: "Purchase Date")
            let supplier = CSVParser.value(in: row, mapping: columnMapping, key: "Supplier")
            let notes = CSVParser.value(in: row, mapping: columnMapping, key: "Notes")

            guard !name.isEmpty else {
                result.skipped.append((rowNumber, "Missing item name"))
                continue
            }
            guard let cost = CurrencyFormatting.parse(costText),
                  let mrp = CurrencyFormatting.parse(mrpText),
                  let qty = Int(qtyText), qty > 0 else {
                result.skipped.append((rowNumber, "Invalid cost, MRP, or quantity"))
                continue
            }

            var category: Category?
            if !categoryName.isEmpty {
                if let remapped = categoryRemap[categoryName] {
                    category = categories.first { $0.id == remapped }
                } else {
                    category = categories.first {
                        $0.name.compare(categoryName, options: .caseInsensitive) == .orderedSame
                    }
                }
                if category == nil {
                    result.skipped.append((rowNumber, "Category '\(categoryName)' not found"))
                    continue
                }
            }

            let purchaseDate = CSVParser.parseDate(dateText) ?? Date()

            let matched: InventoryItem?
            if !skuValue.isEmpty {
                matched = existingItems.first {
                    $0.sku.compare(skuValue, options: .caseInsensitive) == .orderedSame
                        || ($0.name.compare(name, options: .caseInsensitive) == .orderedSame
                            && $0.sku.compare(skuValue, options: .caseInsensitive) == .orderedSame)
                }
            } else {
                matched = existingItems.first {
                    $0.name.compare(name, options: .caseInsensitive) == .orderedSame
                }
            }

            let item: InventoryItem
            if let matched {
                item = matched
                item.quantityOnHand += qty
            } else {
                let sku = skuValue.isEmpty ? SKUGenerator.generate(for: category, in: modelContext) : skuValue
                item = InventoryItem(
                    name: name,
                    sku: sku,
                    category: category,
                    subType: subType.isEmpty ? nil : subType,
                    costPrice: cost,
                    mrp: mrp,
                    quantityOnHand: qty,
                    supplier: supplier.isEmpty ? nil : supplier
                )
                modelContext.insert(item)
            }

            let purchase = PurchaseRecord(
                item: item,
                quantity: qty,
                costPriceAtPurchase: cost,
                purchaseDate: purchaseDate,
                supplier: supplier.isEmpty ? nil : supplier,
                source: .csv,
                notes: notes.isEmpty ? nil : notes
            )
            modelContext.insert(purchase)
            result.imported += 1
        }

        try? modelContext.save()
        summary = result
    }
}
