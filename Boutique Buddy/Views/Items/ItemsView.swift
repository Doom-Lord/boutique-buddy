//
//  ItemsView.swift
//  Boutique Buddy
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ItemsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InventoryItem.name) private var allItems: [InventoryItem]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var searchText = ""
    @State private var selectedCategoryID: UUID?
    @State private var selectedSubType: String?
    @State private var sortOption: ItemSortOption = .name
    @State private var showArchived = false
    @State private var showingAddPurchase = false
    @State private var showingCSVImport = false
    @State private var selectedItem: InventoryItem?

    private var filteredItems: [InventoryItem] {
        var result = allItems.filter { showArchived ? true : !$0.isArchived }

        if let selectedCategoryID {
            result = result.filter { $0.category?.id == selectedCategoryID }
        }
        if let selectedSubType, !selectedSubType.isEmpty {
            result = result.filter { $0.subType == selectedSubType }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(q) || $0.sku.lowercased().contains(q)
            }
        }

        switch sortOption {
        case .name: result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .stock: result.sort { $0.quantityOnHand < $1.quantityOnHand }
        case .cost: result.sort { $0.costPrice < $1.costPrice }
        case .mrp: result.sort { $0.mrp < $1.mrp }
        }
        return result
    }

    private var selectedCategory: Category? {
        categories.first { $0.id == selectedCategoryID }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                Divider()
                if filteredItems.isEmpty {
                    ContentUnavailableView(
                        "No Items",
                        systemImage: "shippingbox",
                        description: Text("Add a purchase to create your first item.")
                    )
                } else {
                    List(selection: $selectedItem) {
                        ForEach(filteredItems) { item in
                            NavigationLink(value: item) {
                                ItemRowView(item: item)
                            }
                            .tag(item)
                        }
                    }
                }
            }
            .navigationTitle("Items")
            .navigationDestination(for: InventoryItem.self) { item in
                ItemDetailView(item: item)
            }
            .searchable(text: $searchText, prompt: "Search name or SKU")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        showingCSVImport = true
                    } label: {
                        Label("Import CSV", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        showingAddPurchase = true
                    } label: {
                        Label("Add Purchase", systemImage: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }
            }
            .sheet(isPresented: $showingAddPurchase) {
                AddPurchaseView()
                    .frame(minWidth: 480, minHeight: 520)
            }
            .sheet(isPresented: $showingCSVImport) {
                PurchaseCSVImportView()
                    .frame(minWidth: 640, minHeight: 480)
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            Picker("Category", selection: $selectedCategoryID) {
                Text("All Categories").tag(UUID?.none)
                ForEach(categories) { category in
                    Text(category.name).tag(Optional(category.id))
                }
            }
            .frame(maxWidth: 200)
            .onChange(of: selectedCategoryID) { _, _ in
                selectedSubType = nil
            }

            if let category = selectedCategory, category.hasSubTypes {
                Picker("Sub-Type", selection: $selectedSubType) {
                    Text("All Sub-Types").tag(String?.none)
                    ForEach(category.subTypes, id: \.self) { sub in
                        Text(sub).tag(Optional(sub))
                    }
                }
                .frame(maxWidth: 180)
            }

            Picker("Sort", selection: $sortOption) {
                ForEach(ItemSortOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .frame(maxWidth: 140)

            Toggle("Show Archived", isOn: $showArchived)
                .toggleStyle(.checkbox)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

enum ItemSortOption: String, CaseIterable, Identifiable {
    case name, stock, cost, mrp
    var id: String { rawValue }
    var title: String {
        switch self {
        case .name: "Name"
        case .stock: "Stock"
        case .cost: "Cost"
        case .mrp: "MRP"
        }
    }
}

struct ItemRowView: View {
    let item: InventoryItem

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.body.weight(.medium))
                    if item.isArchived {
                        Text("Archived")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                    if item.isLowStock && !item.isArchived {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .help("Low stock")
                    }
                }
                Text("\(item.sku) · \(item.displayCategory)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Qty \(item.quantityOnHand)")
                .font(.body.monospacedDigit())
                .foregroundStyle(item.isLowStock ? .orange : .primary)
                .frame(width: 70, alignment: .trailing)
            Text(item.mrp.currencyString)
                .font(.body.monospacedDigit())
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ItemsView()
        .modelContainer(for: [InventoryItem.self, Category.self, PurchaseRecord.self], inMemory: true)
}
