//
//  PartyDetailView.swift
//  Boutique Buddy
//

import SwiftUI
import SwiftData

struct PartyDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]
    @Bindable var party: Party

    @State private var showingEdit = false
    @State private var showingReceivePayment = false
    @State private var showingMakePayment = false
    @State private var toastMessage: String?

    private var brand: BrandIdentity { BrandIdentity(settings: settingsList.first) }

    private var sortedTransactions: [LedgerTransaction] {
        party.ledgerTransactions.sorted { $0.date < $1.date }
    }

    private var runningBalances: [(LedgerTransaction, Decimal)] {
        var running: Decimal = 0
        return sortedTransactions.map { tx in
            running += tx.amount
            return (tx, running)
        }.reversed()
    }

    private var balanceColor: Color {
        if party.balance > 0 { return .red }
        if party.balance < 0 { return .green }
        return .secondary
    }

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Balance")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(party.balance.currencyString)
                            .font(.largeTitle.bold())
                            .foregroundStyle(balanceColor)
                        Text(balanceCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)

                if let phone = party.phone, !phone.isEmpty {
                    LabeledContent("Phone", value: phone)
                }
                if let address = party.address, !address.isEmpty {
                    LabeledContent("Address", value: address)
                }
                if let notes = party.notes, !notes.isEmpty {
                    LabeledContent("Notes", value: notes)
                }
            }

            Section("Share Statement") {
                ShareImageControls(
                    helpCopy: "Copy account statement image",
                    helpShare: "Share account statement…",
                    compact: false,
                    card: {
                        AccountStatementView(
                            party: party,
                            brand: brand
                        )
                    },
                    onCopied: {
                        toastMessage = "Statement copied — paste it anywhere with ⌘V."
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 2_400_000_000)
                            if toastMessage?.hasPrefix("Statement copied") == true {
                                toastMessage = nil
                            }
                        }
                    }
                )
            }

            Section("Ledger") {
                if runningBalances.isEmpty {
                    Text("No transactions yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(runningBalances, id: \.0.id) { tx, running in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tx.type.rawValue)
                                    .font(.body.weight(.medium))
                                Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let notes = tx.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(signedAmount(tx.amount))
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(tx.amount >= 0 ? .red : .green)
                                Text(running.currencyString)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle(party.name)
        .copyToast($toastMessage)
        .toolbar {
            ToolbarItemGroup {
                Button("Receive Payment") { showingReceivePayment = true }
                Button("Make Payment") { showingMakePayment = true }
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            AddPartyView(existingParty: party)
                .frame(minWidth: 420, minHeight: 360)
        }
        .sheet(isPresented: $showingReceivePayment) {
            PaymentView(party: party, kind: .receive)
                .frame(minWidth: 400, minHeight: 320)
        }
        .sheet(isPresented: $showingMakePayment) {
            PaymentView(party: party, kind: .make)
                .frame(minWidth: 400, minHeight: 320)
        }
    }

    private var balanceCaption: String {
        if party.balance > 0 { return "Customer owes the shop" }
        if party.balance < 0 { return "Shop owes the customer" }
        return "Settled"
    }

    private func signedAmount(_ amount: Decimal) -> String {
        if amount >= 0 {
            return "+\(amount.currencyString)"
        }
        return amount.currencyString
    }
}
