//
//  SmartPriceView.swift
//  Boutique Buddy
//

import SwiftUI
import SwiftData

struct SmartPriceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var settingsList: [AppSettings]

    @State private var selectedCategoryID: UUID?
    @State private var costText = ""
    @State private var suggestedMRP: Decimal?
    @State private var roundingIncrement = 10

    private var settings: AppSettings? { settingsList.first }

    private var selectedCategory: Category? {
        categories.first { $0.id == selectedCategoryID }
    }

    var body: some View {
        Form {
            Section("Settings") {
                Picker("Category", selection: $selectedCategoryID) {
                    Text("Select…").tag(UUID?.none)
                    ForEach(categories) { cat in
                        let markup = cat.defaultMarkupPercent.map { " (\(Int($0))%)" } ?? ""
                        Text("\(cat.name)\(markup)").tag(Optional(cat.id))
                    }
                }
                Stepper("Round up to nearest ₹\(roundingIncrement)", value: $roundingIncrement, in: 1...100, step: 5)
                if let settings {
                    Button("Save as Default Rounding") {
                        settings.smartPriceRoundingIncrement = roundingIncrement
                        try? modelContext.save()
                    }
                }
                Text("Edit per-category markup % in Manage Categories.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Calculator") {
                TextField("Cost Price", text: $costText)
                Button("Suggest MRP") { calculate() }
                    .disabled(selectedCategory?.defaultMarkupPercent == nil || CurrencyFormatting.parse(costText) == nil)
                if let suggestedMRP {
                    LabeledContent("Suggested MRP", value: suggestedMRP.currencyString)
                    Text("This is a suggestion only — confirm before applying to an item.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Smart Price")
        .onAppear {
            selectedCategoryID = categories.first?.id
            roundingIncrement = settings?.smartPriceRoundingIncrement ?? 10
        }
    }

    private func calculate() {
        guard let cost = CurrencyFormatting.parse(costText),
              let markup = selectedCategory?.defaultMarkupPercent else { return }
        suggestedMRP = SmartPriceCalculator.suggestMRP(
            costPrice: cost,
            markupPercent: markup,
            roundingIncrement: roundingIncrement
        )
    }
}
