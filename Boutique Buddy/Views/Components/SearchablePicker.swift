//
//  SearchablePicker.swift
//  Boutique Buddy
//

import SwiftUI

/// Spotlight-style searchable picker used for Items and Customers.
struct SearchablePicker<Item: Identifiable, Row: View>: View {
    let title: String
    let placeholder: String
    let items: [Item]
    @Binding var selection: Item?
    var allowsClearToNil: Bool = true
    var nilSelectionLabel: String? = nil
    var autofocus: Bool = false
    /// Bump this value from the parent to force the search field to take focus again.
    var focusNonce: Int = 0
    var score: (Item, String) -> Int?
    var selectedTitle: (Item) -> String
    var onSelect: (() -> Void)? = nil
    @ViewBuilder var row: (Item) -> Row

    @State private var query = ""
    @State private var highlightIndex = 0
    @State private var isEditing = false
    /// True after the user explicitly picks the nil option (e.g. Walk-in).
    @State private var confirmedNilSelection = false
    @FocusState private var fieldFocused: Bool

    private var showResults: Bool {
        isEditing && selection == nil && !confirmedNilSelection
    }

    private var showsNilChip: Bool {
        selection == nil && confirmedNilSelection && !isEditing && nilSelectionLabel != nil
    }

    private var ranked: [Item] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            return Array(items.prefix(8))
        }
        return items
            .compactMap { item -> (Item, Int)? in
                guard let s = score(item, q) else { return nil }
                return (item, s)
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let selection, !isEditing {
                selectedChip(title: selectedTitle(selection))
            } else if showsNilChip, let nilSelectionLabel {
                selectedChip(title: nilSelectionLabel)
            } else {
                TextField(placeholder, text: $query)
                    .textFieldStyle(.roundedBorder)
                    .focused($fieldFocused)
                    .onSubmit { selectHighlighted() }
                    .onKeyPress(.downArrow) {
                        moveHighlight(1)
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        moveHighlight(-1)
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        query = ""
                        highlightIndex = 0
                        return .handled
                    }
                    .onChange(of: query) { _, _ in
                        highlightIndex = 0
                    }
                    .onChange(of: fieldFocused) { _, focused in
                        if focused {
                            isEditing = true
                            confirmedNilSelection = false
                            selection = nil
                        }
                    }

                if showResults {
                    resultsList
                }
            }
        }
        .onAppear {
            if autofocus {
                requestFocus()
            }
        }
        .onChange(of: focusNonce) { _, _ in
            selection = nil
            confirmedNilSelection = false
            query = ""
            isEditing = true
            requestFocus()
        }
    }

    private func requestFocus() {
        DispatchQueue.main.async {
            fieldFocused = true
            isEditing = true
            confirmedNilSelection = false
        }
    }

    private func selectedChip(title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
            Text(title)
                .lineLimit(1)
            Spacer()
            Button("Change") {
                selection = nil
                confirmedNilSelection = false
                query = ""
                isEditing = true
                requestFocus()
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private var resultsList: some View {
        Group {
            if ranked.isEmpty {
                Text(query.isEmpty ? "Start typing to search…" : "No matches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if let nilSelectionLabel, query.isEmpty {
                                Button {
                                    commit(nil)
                                } label: {
                                    Text(nilSelectionLabel)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                            ForEach(Array(ranked.prefix(40).enumerated()), id: \.element.id) { index, item in
                                Button {
                                    commit(item)
                                } label: {
                                    row(item)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(index == highlightIndex ? Color.accentColor.opacity(0.15) : Color.clear)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .id(index)
                            }
                        }
                    }
                    .frame(maxHeight: 6 * 36)
                    .background(.background)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
                    .onChange(of: highlightIndex) { _, newValue in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private func moveHighlight(_ delta: Int) {
        guard !ranked.isEmpty else { return }
        let maxIndex = min(39, ranked.count - 1)
        highlightIndex = min(max(0, highlightIndex + delta), maxIndex)
    }

    private func selectHighlighted() {
        guard !ranked.isEmpty else { return }
        let index = min(highlightIndex, ranked.count - 1)
        commit(ranked[index])
    }

    private func commit(_ item: Item?) {
        selection = item
        query = ""
        isEditing = false
        fieldFocused = false
        confirmedNilSelection = (item == nil && nilSelectionLabel != nil)
        onSelect?()
    }
}

enum ItemSearchRanking {
    static func score(_ item: InventoryItem, query: String) -> Int? {
        let q = query.lowercased()
        let name = item.name.lowercased()
        let sku = item.sku.lowercased()
        let mrpDigits = NSDecimalNumber(decimal: item.mrp).stringValue
            .replacingOccurrences(of: ",", with: "")

        var tier: Int?
        if name == q { tier = 500 }
        else if name.hasPrefix(q) { tier = 400 }
        else if name.contains(q) { tier = 300 }
        else if sku.hasPrefix(q) || sku.contains(q) { tier = 200 }
        else if !q.isEmpty, q.allSatisfy({ $0.isNumber || $0 == "." }),
                mrpDigits.hasPrefix(q) || mrpDigits == q {
            tier = 100
        }

        guard let tier else { return nil }
        let lastSold = item.sales.map(\.date).max() ?? .distantPast
        let recencyBoost = Int(lastSold.timeIntervalSince1970 / 60_000)
        return tier * 1_000_000 + recencyBoost
    }
}

enum PartySearchRanking {
    static func score(_ party: Party, query: String) -> Int? {
        let q = query.lowercased()
        let name = party.name.lowercased()
        let phone = (party.phone ?? "").lowercased()

        var tier: Int?
        if name == q { tier = 500 }
        else if name.hasPrefix(q) { tier = 400 }
        else if name.contains(q) { tier = 300 }
        else if !phone.isEmpty, phone.contains(q) { tier = 200 }

        guard let tier else { return nil }
        let lastActivity = party.ledgerTransactions.map(\.date).max()
            ?? party.sales.map(\.date).max()
            ?? .distantPast
        let recencyBoost = Int(lastActivity.timeIntervalSince1970 / 60_000)
        return tier * 1_000_000 + recencyBoost
    }
}

struct ItemSearchRow: View {
    let item: InventoryItem

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body.weight(.medium))
                Text(item.displayCategory)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.mrp.currencyString)
                    .font(.body.monospacedDigit())
                Text("\(item.quantityOnHand) in stock")
                    .font(.caption)
                    .foregroundStyle(item.quantityOnHand <= 2 ? Color.orange : Color.secondary)
            }
        }
    }
}

struct PartySearchRow: View {
    let party: Party

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(party.name)
                    .font(.body.weight(.medium))
                if let phone = party.phone, !phone.isEmpty {
                    Text(phone)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(party.balance.currencyString)
                .font(.caption.monospacedDigit())
                .foregroundStyle(party.balance > 0 ? Color.orange : Color.secondary)
        }
    }
}
