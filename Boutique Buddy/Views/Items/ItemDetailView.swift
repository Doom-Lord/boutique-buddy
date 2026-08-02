//
//  ItemDetailView.swift
//  Boutique Buddy
//

import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: InventoryItem
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var showingRestock = false
    @State private var showingEdit = false

    var body: some View {
        Form {
            Section("Details") {
                LabeledContent("Name", value: item.name)
                LabeledContent("SKU", value: item.sku)
                LabeledContent("Category", value: item.displayCategory)
                LabeledContent("Cost Price", value: item.costPrice.currencyString)
                LabeledContent("MRP", value: item.mrp.currencyString)
                LabeledContent("In Stock", value: "\(item.quantityOnHand)")
                if let supplier = item.supplier, !supplier.isEmpty {
                    LabeledContent("Supplier", value: supplier)
                }
                if let notes = item.notes, !notes.isEmpty {
                    LabeledContent("Notes", value: notes)
                }
                LabeledContent("Added", value: item.dateAdded.formatted(date: .abbreviated, time: .omitted))
            }

            Section("Stock History") {
                if item.purchases.isEmpty && item.sales.isEmpty {
                    Text("No purchases or sales yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(item.purchases.sorted(by: { $0.purchaseDate > $1.purchaseDate }).prefix(10)) { purchase in
                        HStack {
                            Text("Purchase +\(purchase.quantity)")
                            Spacer()
                            Text(purchase.purchaseDate.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(item.sales.sorted(by: { $0.date > $1.date }).prefix(10)) { sale in
                        HStack {
                            Text("Sale −\(sale.quantity)")
                            Spacer()
                            Text(sale.date.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(item.name)
        .toolbar {
            ToolbarItemGroup {
                Button("Restock") { showingRestock = true }
                Button("Edit") { showingEdit = true }
                Button(item.isArchived ? "Unarchive" : "Archive") {
                    item.isArchived.toggle()
                    try? modelContext.save()
                }
            }
        }
        .sheet(isPresented: $showingRestock) {
            AddPurchaseView(existingItem: item)
                .frame(minWidth: 480, minHeight: 420)
        }
        .sheet(isPresented: $showingEdit) {
            EditItemView(item: item)
                .frame(minWidth: 440, minHeight: 400)
        }
    }
}

struct EditItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: InventoryItem
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var name: String = ""
    @State private var selectedCategoryID: UUID?
    @State private var subType: String = ""
    @State private var costPriceText: String = ""
    @State private var mrpText: String = ""
    @State private var supplier: String = ""
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Category", selection: $selectedCategoryID) {
                    ForEach(categories) { cat in
                        Text(cat.name).tag(Optional(cat.id))
                    }
                }
                if let cat = categories.first(where: { $0.id == selectedCategoryID }), cat.hasSubTypes {
                    Picker("Sub-Type", selection: $subType) {
                        Text("—").tag("")
                        ForEach(cat.subTypes, id: \.self) { Text($0).tag($0) }
                    }
                }
                TextField("Cost Price", text: $costPriceText)
                TextField("MRP", text: $mrpText)
                TextField("Supplier", text: $supplier)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            .formStyle(.grouped)
            .padding()
            .navigationTitle("Edit Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                name = item.name
                selectedCategoryID = item.category?.id
                subType = item.subType ?? ""
                costPriceText = "\(item.costPrice)"
                mrpText = "\(item.mrp)"
                supplier = item.supplier ?? ""
                notes = item.notes ?? ""
            }
        }
    }

    private func save() {
        item.name = name.trimmingCharacters(in: .whitespaces)
        item.category = categories.first { $0.id == selectedCategoryID }
        item.subType = subType.isEmpty ? nil : subType
        if let cost = CurrencyFormatting.parse(costPriceText) { item.costPrice = cost }
        if let mrp = CurrencyFormatting.parse(mrpText) { item.mrp = mrp }
        item.supplier = supplier.isEmpty ? nil : supplier
        item.notes = notes.isEmpty ? nil : notes
        try? modelContext.save()
        dismiss()
    }
}
