//
//  AddPartyView.swift
//  Boutique Buddy
//

import SwiftUI
import SwiftData

struct AddPartyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var existingParty: Party? = nil

    @State private var name = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var setOpeningBalance = false
    @State private var openingAmountText = ""
    @State private var openingDirection: OpeningDirection = .owesShop

    private enum OpeningDirection: String, CaseIterable {
        case owesShop = "Owes shop"
        case shopOwes = "Shop owes them"
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Phone", text: $phone)
                TextField("Address", text: $address, axis: .vertical)
                    .lineLimit(2...4)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...4)

                if existingParty == nil {
                    Toggle("Set opening balance", isOn: $setOpeningBalance)
                    if setOpeningBalance {
                        TextField("Amount", text: $openingAmountText)
                        Picker("Direction", selection: $openingDirection) {
                            ForEach(OpeningDirection.allCases, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                        Text("Does this customer already owe you money, or are you owed to them, from before you started using this app?")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
            .navigationTitle(existingParty == nil ? "Add Customer" : "Edit Customer")
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
                if let existingParty {
                    name = existingParty.name
                    phone = existingParty.phone ?? ""
                    address = existingParty.address ?? ""
                    notes = existingParty.notes ?? ""
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let existingParty {
            existingParty.name = trimmed
            existingParty.phone = phone.isEmpty ? nil : phone
            existingParty.address = address.isEmpty ? nil : address
            existingParty.notes = notes.isEmpty ? nil : notes
        } else {
            let party = Party(
                name: trimmed,
                phone: phone.isEmpty ? nil : phone,
                address: address.isEmpty ? nil : address,
                notes: notes.isEmpty ? nil : notes
            )
            modelContext.insert(party)

            if setOpeningBalance, let amount = CurrencyFormatting.parse(openingAmountText), amount > 0 {
                let signed: Decimal = openingDirection == .owesShop ? amount : -amount
                let ledger = LedgerTransaction(
                    party: party,
                    date: Date(),
                    type: .openingBalance,
                    amount: signed,
                    notes: "Opening balance"
                )
                modelContext.insert(ledger)
            }
        }
        try? modelContext.save()
        dismiss()
    }
}
