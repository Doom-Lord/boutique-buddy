//
//  AddPurchaseView.swift
//  Boutique Buddy
//

import SwiftUI
import SwiftData

struct AddPurchaseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InventoryItem.name) private var existingItems: [InventoryItem]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var settingsList: [AppSettings]

    var existingItem: InventoryItem? = nil

    @State private var mode: PurchaseMode = .existing
    @State private var selectedItemID: UUID?
    @State private var newName = ""
    @State private var selectedCategoryID: UUID?
    @State private var subType = ""
    @State private var costPriceText = ""
    @State private var mrpText = ""
    @State private var quantity = 1
    @State private var purchaseDate = Date()
    @State private var supplier = ""
    @State private var notes = ""
    @State private var showCostUpdateAlert = false
    @State private var pendingCostUpdate: (InventoryItem, Decimal)?
    @State private var errorMessage: String?

    private var settings: AppSettings? { settingsList.first }

    private enum PurchaseMode: String, CaseIterable {
        case existing = "Existing Item"
        case newItem = "New Item"
    }

    var body: some View {
        NavigationStack {
            Form {
                if existingItem == nil {
                    Picker("Add to", selection: $mode) {
                        ForEach(PurchaseMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 4)
                }

                if mode == .existing || existingItem != nil {
                    if let existingItem {
                        LabeledContent("Item", value: existingItem.name)
                    } else {
                        Picker("Item", selection: $selectedItemID) {
                            Text("Select item…").tag(UUID?.none)
                            ForEach(existingItems.filter { !$0.isArchived }) { item in
                                Text("\(item.name) (\(item.sku)) — stock \(item.quantityOnHand)")
                                    .tag(Optional(item.id))
                            }
                        }
                    }
                } else {
                    TextField("Name", text: $newName)
                    Picker("Category", selection: $selectedCategoryID) {
                        Text("Select…").tag(UUID?.none)
                        ForEach(categories) { Text($0.name).tag(Optional($0.id)) }
                    }
                    if let cat = categories.first(where: { $0.id == selectedCategoryID }), cat.hasSubTypes {
                        Picker("Sub-Type", selection: $subType) {
                            Text("—").tag("")
                            ForEach(cat.subTypes, id: \.self) { Text($0).tag($0) }
                        }
                    }
                    HStack {
                        TextField("Cost Price", text: $costPriceText)
                        if let cat = categories.first(where: { $0.id == selectedCategoryID }),
                           let markup = cat.defaultMarkupPercent,
                           let cost = CurrencyFormatting.parse(costPriceText), cost > 0 {
                            Button("Suggest MRP") {
                                let increment = settings?.smartPriceRoundingIncrement ?? 10
                                let suggested = SmartPriceCalculator.suggestMRP(
                                    costPrice: cost,
                                    markupPercent: markup,
                                    roundingIncrement: increment
                                )
                                mrpText = "\(suggested)"
                            }
                        }
                    }
                    TextField("MRP", text: $mrpText)
                }

                Stepper("Quantity: \(quantity)", value: $quantity, in: 1...9999)
                DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                TextField("Supplier (optional)", text: $supplier)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...4)

                if mode == .existing, let item = resolvedExistingItem {
                    TextField("Cost Price at Purchase", text: $costPriceText)
                        .onAppear {
                            if costPriceText.isEmpty {
                                costPriceText = "\(item.costPrice)"
                            }
                        }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .formStyle(.grouped)
            .padding()
            .navigationTitle("Add Purchase")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear {
                if let existingItem {
                    mode = .existing
                    selectedItemID = existingItem.id
                    costPriceText = "\(existingItem.costPrice)"
                } else if selectedCategoryID == nil {
                    selectedCategoryID = categories.first?.id
                }
            }
            .alert("Update Cost Price?", isPresented: $showCostUpdateAlert) {
                Button("Yes") {
                    if let (item, cost) = pendingCostUpdate {
                        item.costPrice = cost
                        try? modelContext.save()
                    }
                    pendingCostUpdate = nil
                    dismiss()
                }
                Button("No", role: .cancel) {
                    pendingCostUpdate = nil
                    dismiss()
                }
            } message: {
                if let (item, cost) = pendingCostUpdate {
                    Text("Update \(item.name)'s cost price from \(item.costPrice.currencyString) to \(cost.currencyString)?")
                }
            }
        }
    }

    private var resolvedExistingItem: InventoryItem? {
        if let existingItem { return existingItem }
        return existingItems.first { $0.id == selectedItemID }
    }

    private func save() {
        errorMessage = nil

        if mode == .newItem && existingItem == nil {
            guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else {
                errorMessage = "Enter an item name."
                return
            }
            guard let cost = CurrencyFormatting.parse(costPriceText),
                  let mrp = CurrencyFormatting.parse(mrpText) else {
                errorMessage = "Enter valid cost price and MRP."
                return
            }
            let category = categories.first { $0.id == selectedCategoryID }
            let sku = SKUGenerator.generate(for: category, in: modelContext)
            let item = InventoryItem(
                name: newName.trimmingCharacters(in: .whitespaces),
                sku: sku,
                category: category,
                subType: subType.isEmpty ? nil : subType,
                costPrice: cost,
                mrp: mrp,
                quantityOnHand: quantity,
                supplier: supplier.isEmpty ? nil : supplier
            )
            modelContext.insert(item)
            let purchase = PurchaseRecord(
                item: item,
                quantity: quantity,
                costPriceAtPurchase: cost,
                purchaseDate: purchaseDate,
                supplier: supplier.isEmpty ? nil : supplier,
                source: .manual,
                notes: notes.isEmpty ? nil : notes
            )
            modelContext.insert(purchase)
            try? modelContext.save()
            dismiss()
            return
        }

        guard let item = resolvedExistingItem else {
            errorMessage = "Select an item."
            return
        }
        guard let cost = CurrencyFormatting.parse(costPriceText) else {
            errorMessage = "Enter a valid cost price."
            return
        }

        let purchase = PurchaseRecord(
            item: item,
            quantity: quantity,
            costPriceAtPurchase: cost,
            purchaseDate: purchaseDate,
            supplier: supplier.isEmpty ? nil : supplier,
            source: .manual,
            notes: notes.isEmpty ? nil : notes
        )
        modelContext.insert(purchase)
        item.quantityOnHand += quantity
        if !supplier.isEmpty { item.supplier = supplier }

        if cost != item.costPrice {
            pendingCostUpdate = (item, cost)
            try? modelContext.save()
            showCostUpdateAlert = true
        } else {
            try? modelContext.save()
            dismiss()
        }
    }
}
