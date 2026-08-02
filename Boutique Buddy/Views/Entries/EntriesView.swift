//
//  EntriesView.swift
//  Boutique Buddy
//

import SwiftUI
import SwiftData

enum JournalEntry: Identifiable {
    case sale(SaleEntry)
    case payment(LedgerTransaction)

    var id: UUID {
        switch self {
        case .sale(let sale): sale.id
        case .payment(let tx): tx.id
        }
    }

    var date: Date {
        switch self {
        case .sale(let sale): sale.date
        case .payment(let tx): tx.date
        }
    }
}

struct EntriesView: View {
    @Query(sort: \SaleEntry.date, order: .reverse) private var sales: [SaleEntry]
    @Query(sort: \LedgerTransaction.date, order: .reverse) private var ledger: [LedgerTransaction]
    @Query private var settingsList: [AppSettings]

    @State private var searchText = ""
    @State private var dateFrom: Date? = nil
    @State private var dateTo: Date? = nil
    @State private var showingAddEntry = false
    @State private var showingCSVImport = false
    @State private var toastMessage: String?

    private var brand: BrandIdentity { BrandIdentity(settings: settingsList.first) }

    private var paymentEntries: [LedgerTransaction] {
        ledger.filter {
            $0.type == .paymentReceived || $0.type == .paymentMade
        }
    }

    private var filteredJournal: [JournalEntry] {
        let saleRows: [JournalEntry] = sales.compactMap { sale in
            guard matchesFilters(date: sale.date, searchable: saleSearchBlob(sale)) else { return nil }
            return .sale(sale)
        }
        let paymentRows: [JournalEntry] = paymentEntries.compactMap { tx in
            let blob = [
                tx.party?.name,
                tx.type.rawValue,
                tx.notes
            ].compactMap { $0 }.joined(separator: " ").lowercased()
            guard matchesFilters(date: tx.date, searchable: blob) else { return nil }
            return .payment(tx)
        }
        return (saleRows + paymentRows).sorted { $0.date > $1.date }
    }

    private var grouped: [(date: Date, entries: [JournalEntry], salesTotal: Decimal, saleCount: Int, paymentCount: Int)] {
        let calendar = Calendar.current
        let dict = Dictionary(grouping: filteredJournal) { calendar.startOfDay(for: $0.date) }
        return dict.keys.sorted(by: >).map { day in
            let entries = dict[day]!.sorted { $0.date > $1.date }
            let salesOnly = entries.compactMap { entry -> SaleEntry? in
                if case .sale(let sale) = entry { return sale }
                return nil
            }
            let paymentCount = entries.filter {
                if case .payment = $0 { return true }
                return false
            }.count
            let total = salesOnly.reduce(Decimal.zero) { $0 + $1.netAmount }
            return (day, entries, total, salesOnly.count, paymentCount)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                Divider()
                if grouped.isEmpty {
                    ContentUnavailableView(
                        "No Entries Yet",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Add a sale or payment, or import a CSV.")
                    )
                } else {
                    List {
                        ForEach(grouped, id: \.date) { group in
                            Section {
                                ForEach(group.entries) { entry in
                                    switch entry {
                                    case .sale(let sale):
                                        HStack(spacing: 8) {
                                            NavigationLink {
                                                SaleDetailView(sale: sale)
                                            } label: {
                                                SaleRowLabel(sale: sale)
                                            }
                                            ShareImageControls(
                                                helpCopy: "Copy receipt image",
                                                helpShare: "Share receipt…",
                                                compact: true,
                                                card: {
                                                    ReceiptView(sale: sale, brand: brand)
                                                },
                                                onCopied: { showCopiedToast() }
                                            )
                                        }
                                    case .payment(let tx):
                                        PaymentJournalRow(transaction: tx)
                                    }
                                }
                            } header: {
                                HStack {
                                    Text(sectionTitle(for: group.date))
                                    Spacer()
                                    Text(groupHeader(group))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Entries")
            .searchable(text: $searchText, prompt: "Search item, customer, or payment")
            .copyToast($toastMessage)
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        showingCSVImport = true
                    } label: {
                        Label("Import CSV", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        showingAddEntry = true
                    } label: {
                        Label("Add Entry", systemImage: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                AddEntryView()
                    .frame(minWidth: 540, minHeight: 680)
            }
            .sheet(isPresented: $showingCSVImport) {
                SaleCSVImportView()
                    .frame(minWidth: 640, minHeight: 480)
            }
        }
    }

    private func groupHeader(_ group: (date: Date, entries: [JournalEntry], salesTotal: Decimal, saleCount: Int, paymentCount: Int)) -> String {
        var parts: [String] = ["\(group.salesTotal.currencyString)"]
        if group.saleCount > 0 {
            parts.append("\(group.saleCount) sale\(group.saleCount == 1 ? "" : "s")")
        }
        if group.paymentCount > 0 {
            parts.append("\(group.paymentCount) payment\(group.paymentCount == 1 ? "" : "s")")
        }
        if group.saleCount == 0 && group.paymentCount == 0 {
            parts.append("0 entries")
        }
        return parts.joined(separator: " · ")
    }

    private func matchesFilters(date: Date, searchable: String) -> Bool {
        if let dateFrom, date < Calendar.current.startOfDay(for: dateFrom) { return false }
        if let dateTo {
            let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: dateTo))!
            if date >= end { return false }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            if !searchable.contains(q) { return false }
        }
        return true
    }

    private func saleSearchBlob(_ sale: SaleEntry) -> String {
        [
            sale.item?.name,
            sale.item?.sku,
            sale.party?.name
        ].compactMap { $0 }.joined(separator: " ").lowercased()
    }

    private func showCopiedToast() {
        toastMessage = "Receipt copied — paste it anywhere with ⌘V."
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            if toastMessage?.hasPrefix("Receipt copied") == true {
                toastMessage = nil
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            DatePicker(
                "From",
                selection: Binding(
                    get: { dateFrom ?? Date() },
                    set: { dateFrom = $0 }
                ),
                displayedComponents: .date
            )
            .labelsHidden()
            .frame(width: 120)
            .opacity(dateFrom == nil ? 0.5 : 1)
            .onTapGesture { if dateFrom == nil { dateFrom = Date() } }

            Text("–")

            DatePicker(
                "To",
                selection: Binding(
                    get: { dateTo ?? Date() },
                    set: { dateTo = $0 }
                ),
                displayedComponents: .date
            )
            .labelsHidden()
            .frame(width: 120)
            .opacity(dateTo == nil ? 0.5 : 1)
            .onTapGesture { if dateTo == nil { dateTo = Date() } }

            if dateFrom != nil || dateTo != nil {
                Button("Clear Dates") {
                    dateFrom = nil
                    dateTo = nil
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func sectionTitle(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

struct SaleRowLabel: View {
    let sale: SaleEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bag")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(sale.item?.name ?? "Unknown item")
                        .font(.body.weight(.medium))
                    if sale.isUntrackedCredit {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                            .help("Credit sale without a customer")
                    }
                    if sale.discountAmount > 0 {
                        Text("Discount")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                    }
                }
                Text("\(sale.quantity) × \(sale.salePrice.currencyString) · \(sale.paymentMode.rawValue) · \(sale.party?.name ?? "Walk-in")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(sale.netAmount.currencyString)
                    .font(.body.monospacedDigit().weight(.medium))
                if sale.pendingAmount > 0 {
                    Text("\(sale.pendingAmount.currencyString) due")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.orange)
                } else {
                    Text("Paid")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct PaymentJournalRow: View {
    let transaction: LedgerTransaction

    private var isReceived: Bool {
        transaction.type == .paymentReceived
    }

    private var absoluteAmount: Decimal {
        transaction.amount < 0 ? -transaction.amount : transaction.amount
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isReceived ? "arrow.down.left.circle" : "arrow.up.right.circle")
                .foregroundStyle(isReceived ? .green : .orange)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(isReceived ? "Payment received" : "Payment made")
                    .font(.body.weight(.medium))
                Text("\(transaction.party?.name ?? "Customer") · \(absoluteAmount.currencyString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(absoluteAmount.currencyString)
                .font(.body.monospacedDigit().weight(.medium))
                .foregroundStyle(isReceived ? .green : .primary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    EntriesView()
        .modelContainer(for: [
            SaleEntry.self,
            InventoryItem.self,
            Party.self,
            LedgerTransaction.self,
            AppSettings.self
        ], inMemory: true)
}
