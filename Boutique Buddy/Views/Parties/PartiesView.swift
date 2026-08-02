//
//  PartiesView.swift
//  Boutique Buddy
//

import SwiftUI
import SwiftData

struct PartiesView: View {
    @Query(sort: \Party.name) private var parties: [Party]
    @State private var searchText = ""
    @State private var showingAdd = false

    private var filtered: [Party] {
        guard !searchText.isEmpty else { return parties }
        let q = searchText.lowercased()
        return parties.filter {
            $0.name.lowercased().contains(q)
                || ($0.phone?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        "No Customers",
                        systemImage: "person.2",
                        description: Text("Add a customer to track dues and payments.")
                    )
                } else {
                    List {
                        ForEach(filtered) { party in
                            NavigationLink(value: party) {
                                PartyRowView(party: party)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Parties")
            .navigationDestination(for: Party.self) { party in
                PartyDetailView(party: party)
            }
            .searchable(text: $searchText, prompt: "Search name or phone")
            .toolbar {
                ToolbarItem {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add Customer", systemImage: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddPartyView()
                    .frame(minWidth: 420, minHeight: 420)
            }
        }
    }
}

struct PartyRowView: View {
    let party: Party

    private var balanceColor: Color {
        if party.balance > 0 { return .red }
        if party.balance < 0 { return .green }
        return .secondary
    }

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
                .font(.body.monospacedDigit().weight(.medium))
                .foregroundStyle(balanceColor)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    PartiesView()
        .modelContainer(for: [Party.self, LedgerTransaction.self], inMemory: true)
}
