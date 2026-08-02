//
//  PaymentView.swift
//  Boutique Buddy
//

import SwiftUI
import SwiftData

struct PaymentView: View {
    enum Kind {
        case receive
        case make

        var title: String {
            switch self {
            case .receive: "Receive Payment"
            case .make: "Make Payment"
            }
        }

        var direction: PaymentDirection {
            switch self {
            case .receive: .received
            case .make: .paid
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let party: Party
    let kind: Kind

    @State private var amountText = ""
    @State private var date = Date()
    @State private var paymentMode: PaymentMode = .cash
    @State private var notes = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("Customer", value: party.name)
                LabeledContent("Current Balance", value: party.balance.currencyString)
                TextField("Amount", text: $amountText)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Picker("Payment Mode", selection: $paymentMode) {
                    ForEach(PaymentMode.allCases.filter { $0 != .credit && $0 != .mixed }) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.caption)
                }
            }
            .formStyle(.grouped)
            .padding()
            .navigationTitle(kind.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private func save() {
        guard let amount = CurrencyFormatting.parse(amountText), amount > 0 else {
            errorMessage = "Enter a valid amount."
            return
        }

        LedgerPaymentRecorder.record(
            party: party,
            direction: kind.direction,
            amount: amount,
            date: date,
            paymentMode: paymentMode,
            notes: notes.isEmpty ? nil : notes,
            in: modelContext
        )
        dismiss()
    }
}
