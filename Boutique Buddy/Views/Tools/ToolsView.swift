//
//  ToolsView.swift
//  Boutique Buddy
//

import SwiftUI
import SwiftData

struct ToolsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [InventoryItem]
    @Query private var settingsList: [AppSettings]

    @State private var statusMessage: String?
    @State private var showLoadConfirm = false
    @State private var showResetConfirm = false

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    ManageCategoriesView()
                } label: {
                    Label("Manage Categories", systemImage: "square.grid.3x3")
                }
                NavigationLink {
                    BackupRestoreView()
                } label: {
                    Label("Backup & Restore", systemImage: "externaldrive")
                }
                NavigationLink {
                    SmartPriceView()
                } label: {
                    Label("Smart Price", systemImage: "tag")
                }
                NavigationLink {
                    BarcodeLabelView()
                } label: {
                    Label("Barcode Labels", systemImage: "barcode")
                }

                Section("Evaluation") {
                    Button {
                        if items.isEmpty {
                            loadDemo()
                        } else {
                            showLoadConfirm = true
                        }
                    } label: {
                        Label("Load Demo Data", systemImage: "sparkles")
                    }

                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Reset Shop Data…", systemImage: "trash")
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Tools")
            .alert("Replace with Demo Data?", isPresented: $showLoadConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Clear & Load Demo", role: .destructive) {
                    clearShopData()
                    loadDemo()
                }
            } message: {
                Text("You already have \(items.count) item(s). This clears inventory, sales, and customers, then loads sample data.")
            }
            .alert("Reset All Shop Data?", isPresented: $showResetConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    clearShopData()
                    settings?.hasSeededDemoData = false
                    try? modelContext.save()
                    statusMessage = "Shop data cleared. Categories kept."
                }
            } message: {
                Text("Deletes all items, sales, purchases, customers, and ledger entries. Categories are kept.")
            }
        }
    }

    private func loadDemo() {
        let message = SeedData.loadDemoData(in: modelContext)
        statusMessage = message
    }

    private func clearShopData() {
        deleteAll(LedgerTransaction.self)
        deleteAll(SaleEntry.self)
        deleteAll(PurchaseRecord.self)
        deleteAll(InventoryItem.self)
        deleteAll(Party.self)
        try? modelContext.save()
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) {
        let descriptor = FetchDescriptor<T>()
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        for row in rows {
            modelContext.delete(row)
        }
    }
}

#Preview {
    ToolsView()
        .modelContainer(for: [
            Category.self,
            InventoryItem.self,
            AppSettings.self
        ], inMemory: true)
}
