//
//  DashboardView.swift
//  Boutique Buddy
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \SaleEntry.date, order: .reverse) private var sales: [SaleEntry]
    @Query(filter: #Predicate<InventoryItem> { !$0.isArchived }) private var items: [InventoryItem]
    @Query private var parties: [Party]

    private var todaySales: [SaleEntry] {
        sales.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var todayTotal: Decimal {
        todaySales.reduce(Decimal.zero) { $0 + $1.totalAmount }
    }

    private var outstandingDues: Decimal {
        parties.map(\.balance).filter { $0 > 0 }.reduce(Decimal.zero, +)
    }

    private var lowStockCount: Int {
        items.filter(\.isLowStock).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Dashboard")
                    .font(.largeTitle.bold())

                Text("Quick snapshot — full dashboard coming later.")
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatCard(
                        title: "Today's Sales",
                        value: todayTotal.currencyString,
                        subtitle: "\(todaySales.count) entr\(todaySales.count == 1 ? "y" : "ies")",
                        systemImage: "indianrupeesign.circle"
                    )
                    StatCard(
                        title: "Outstanding Dues",
                        value: outstandingDues.currencyString,
                        subtitle: "Across all customers",
                        systemImage: "person.crop.circle.badge.exclamationmark"
                    )
                    StatCard(
                        title: "Low Stock",
                        value: "\(lowStockCount)",
                        subtitle: "Items with ≤ 2 in stock",
                        systemImage: "exclamationmark.triangle"
                    )
                }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [SaleEntry.self, InventoryItem.self, Party.self, Category.self], inMemory: true)
}
