//
//  SaleCSVImportView.swift
//  Boutique Buddy
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

struct SaleCSVImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [InventoryItem]
    @Query private var parties: [Party]

    @State private var table: CSVTable?
    @State private var columnMapping: [String: Int] = [:]
    @State private var summary: CSVImportSummary?
    @State private var pendingNewCustomers: [String] = []
    @State private var createCustomerDecisions: [String: Bool] = [:]
    @State private var errorMessage: String?
    @State private var awaitingCustomerPrompt = false

    private let expectedColumns = [
        "Date", "Item Name or SKU", "Quantity", "Sale Price",
        "Customer Name", "Payment Mode", "Amount Received", "Notes"
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if let summary {
                    summaryView(summary)
                } else if awaitingCustomerPrompt, !pendingNewCustomers.isEmpty {
                    customerPromptSection
                } else if let table {
                    mappingSection(table)
                    previewSection(table)
                } else {
                    ContentUnavailableView {
                        Label("Import Sales", systemImage: "square.and.arrow.down")
                    } description: {
                        Text("CSV columns: Date, Item Name or SKU, Quantity, Sale Price, Customer Name, Payment Mode, Amount Received, Notes")
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
            .navigationTitle("Import Sales CSV")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(summary == nil ? "Cancel" : "Done") { dismiss() }
                }
                if table != nil, summary == nil, !awaitingCustomerPrompt {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import") { prepareImport() }
                    }
                }
                if awaitingCustomerPrompt {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Continue") { runImport() }
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

    private var customerPromptSection: some View {
        GroupBox("New Customers") {
            VStack(alignment: .leading, spacing: 8) {
                Text("These names weren't found. Create them?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(pendingNewCustomers, id: \.self) { name in
                    Toggle(isOn: Binding(
                        get: { createCustomerDecisions[name] ?? true },
                        set: { createCustomerDecisions[name] = $0 }
                    )) {
                        Text("Create '\(name)'")
                    }
                    .toggleStyle(.checkbox)
                }
            }
            .padding(8)
        }
    }

    private func mappingSection(_ table: CSVTable) -> some View {
        GroupBox("Column Mapping") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], spacing: 8) {
                ForEach(expectedColumns, id: \.self) { col in
                    HStack {
                        Text(col).frame(width: 130, alignment: .leading)
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
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            let parsed = CSVParser.parse(contents: contents)
            table = parsed
            columnMapping = autoMap(headers: parsed.headers)
            errorMessage = nil
        } catch {
            errorMessage = "Could not read file: \(error.localizedDescription)"
        }
    }

    private func autoMap(headers: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        let aliases: [String: [String]] = [
            "Date": ["date", "sale date"],
            "Item Name or SKU": ["item name or sku", "item", "item name", "sku", "name"],
            "Quantity": ["quantity", "qty"],
            "Sale Price": ["sale price", "price", "mrp"],
            "Customer Name": ["customer name", "customer", "party", "name"],
            "Payment Mode": ["payment mode", "payment", "mode"],
            "Amount Received": ["amount received", "received", "paid"],
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

    private func prepareImport() {
        guard let table else { return }
        var unknowns = Set<String>()
        for row in table.rows {
            let name = CSVParser.value(in: row, mapping: columnMapping, key: "Customer Name")
            guard !name.isEmpty else { continue }
            let exists = parties.contains {
                $0.name.compare(name, options: .caseInsensitive) == .orderedSame
            }
            if !exists { unknowns.insert(name) }
        }
        if unknowns.isEmpty {
            runImport()
        } else {
            pendingNewCustomers = unknowns.sorted()
            createCustomerDecisions = Dictionary(uniqueKeysWithValues: pendingNewCustomers.map { ($0, true) })
            awaitingCustomerPrompt = true
        }
    }

    private func runImport() {
        guard let table else { return }
        awaitingCustomerPrompt = false
        var result = CSVImportSummary()
        var partyCache = Dictionary(uniqueKeysWithValues: parties.map { ($0.name.lowercased(), $0) })

        for (name, shouldCreate) in createCustomerDecisions where shouldCreate {
            if partyCache[name.lowercased()] == nil {
                let party = Party(name: name)
                modelContext.insert(party)
                partyCache[name.lowercased()] = party
            }
        }

        for (index, row) in table.rows.enumerated() {
            let rowNumber = index + 2
            let dateText = CSVParser.value(in: row, mapping: columnMapping, key: "Date")
            let itemKey = CSVParser.value(in: row, mapping: columnMapping, key: "Item Name or SKU")
            let qtyText = CSVParser.value(in: row, mapping: columnMapping, key: "Quantity")
            let priceText = CSVParser.value(in: row, mapping: columnMapping, key: "Sale Price")
            let customerName = CSVParser.value(in: row, mapping: columnMapping, key: "Customer Name")
            let modeText = CSVParser.value(in: row, mapping: columnMapping, key: "Payment Mode")
            let receivedText = CSVParser.value(in: row, mapping: columnMapping, key: "Amount Received")
            let notes = CSVParser.value(in: row, mapping: columnMapping, key: "Notes")

            guard !itemKey.isEmpty else {
                result.skipped.append((rowNumber, "Missing item"))
                continue
            }

            guard let item = items.first(where: {
                $0.name.compare(itemKey, options: .caseInsensitive) == .orderedSame
                    || $0.sku.compare(itemKey, options: .caseInsensitive) == .orderedSame
            }) else {
                result.skipped.append((rowNumber, "Item '\(itemKey)' not found"))
                continue
            }

            guard let qty = Int(qtyText), qty > 0,
                  let price = CurrencyFormatting.parse(priceText) else {
                result.skipped.append((rowNumber, "Invalid quantity or sale price"))
                continue
            }

            let date = CSVParser.parseDate(dateText) ?? Date()
            let mode = PaymentMode.matching(modeText) ?? .cash
            let gross = price * Decimal(qty)
            let received = CurrencyFormatting.parse(receivedText) ?? (mode == .credit ? 0 : gross)

            var party: Party?
            if !customerName.isEmpty {
                party = partyCache[customerName.lowercased()]
                if party == nil && createCustomerDecisions[customerName] != true {
                    // Skip attaching party
                }
            }

            let sale = SaleEntry(
                date: date,
                item: item,
                quantity: qty,
                salePrice: price,
                party: party,
                paymentMode: mode,
                amountReceived: received,
                notes: notes.isEmpty ? nil : notes,
                source: .csv,
                isUntrackedCredit: false,
                discountType: .none,
                discountValue: 0
            )
            let pending = sale.pendingAmount
            sale.isUntrackedCredit = pending > 0 && party == nil
            modelContext.insert(sale)
            item.quantityOnHand -= qty

            if pending > 0, let party {
                let ledger = LedgerTransaction(
                    party: party,
                    date: date,
                    type: .saleOnCredit,
                    amount: pending,
                    relatedSaleEntry: sale,
                    notes: "Credit from sale of \(item.name)"
                )
                modelContext.insert(ledger)
            }

            result.imported += 1
        }

        try? modelContext.save()
        summary = result
    }
}
