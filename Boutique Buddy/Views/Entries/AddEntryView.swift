//
//  AddEntryView.swift
//  Boutique Buddy
//

import SwiftUI
import SwiftData

struct AddEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<InventoryItem> { !$0.isArchived }, sort: \InventoryItem.name)
    private var items: [InventoryItem]
    @Query(sort: \Party.name) private var parties: [Party]
    @Query private var settingsList: [AppSettings]

    @State private var tab: EntryFormTab = .sale
    @State private var date = Date()

    // Sale
    @State private var selectedItem: InventoryItem?
    @State private var quantity = 1
    @State private var salePriceText = ""
    @State private var selectedParty: Party?
    @State private var paymentMode: PaymentMode = .cash
    @State private var amountReceivedText = ""
    @State private var notes = ""
    @State private var showDiscount = false
    @State private var discountKind: DiscountKind = .percentage
    @State private var discountValueText = ""
    @State private var showOverpayConfirm = false
    @State private var showCreditWarning = false
    @State private var saveAndContinue = false

    // Payment
    @State private var paymentParty: Party?
    @State private var paymentDirection: PaymentDirection = .received
    @State private var paymentAmountText = ""
    @State private var paymentModeOnly: PaymentMode = .cash
    @State private var paymentNotes = ""

    @State private var errorMessage: String?
    @State private var stockWarning: String?
    @State private var itemFocusNonce = 0
    @State private var partyFocusNonce = 0
    @State private var paymentPartyFocusNonce = 0

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case quantity, salePrice, amountReceived, paymentAmount
    }

    private enum DiscountKind: String, CaseIterable, Identifiable {
        case percentage = "% off"
        case flatAmount = "₹ off"
        var id: String { rawValue }

        var asDiscountType: DiscountType {
            switch self {
            case .percentage: .percentage
            case .flatAmount: .flatAmount
            }
        }
    }

    private var settings: AppSettings? { settingsList.first }

    private var unitPrice: Decimal { CurrencyFormatting.parse(salePriceText) ?? 0 }
    private var grossAmount: Decimal { unitPrice * Decimal(quantity) }
    private var activeDiscountType: DiscountType { showDiscount ? discountKind.asDiscountType : .none }
    private var enteredDiscountValue: Decimal {
        guard showDiscount else { return 0 }
        return CurrencyFormatting.parse(discountValueText) ?? 0
    }
    private var discountAmount: Decimal {
        SalePricing.discountAmount(gross: grossAmount, type: activeDiscountType, value: enteredDiscountValue)
    }
    private var netAmount: Decimal {
        SalePricing.netAmount(gross: grossAmount, type: activeDiscountType, value: enteredDiscountValue)
    }
    private var amountReceived: Decimal { CurrencyFormatting.parse(amountReceivedText) ?? 0 }
    private var pendingAmount: Decimal {
        SalePricing.pendingAmount(net: netAmount, received: amountReceived)
    }
    private var discountClampedNote: String? {
        guard showDiscount, SalePricing.wouldClamp(gross: grossAmount, type: activeDiscountType, value: enteredDiscountValue) else {
            return nil
        }
        return "Discount can’t exceed the gross amount — capped at \(grossAmount.currencyString)."
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Entry Type", selection: $tab) {
                    ForEach(EntryFormTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .onChange(of: tab) { _, newValue in
                    settings?.lastEntryTab = newValue
                    try? modelContext.save()
                    errorMessage = nil
                    if newValue == .sale {
                        itemFocusNonce += 1
                    } else {
                        paymentPartyFocusNonce += 1
                    }
                }

                Form {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    if tab == .sale {
                        saleForm
                    } else {
                        paymentForm
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                .formStyle(.grouped)
                .padding(.horizontal, 8)
            }
            .navigationTitle(tab.windowTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("Save & Add Another") {
                        saveAndContinue = true
                        attemptSave()
                    }
                    Button("Save") {
                        saveAndContinue = false
                        attemptSave()
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                }
            }
            .alert("Amount exceeds sale total", isPresented: $showOverpayConfirm) {
                Button("Save Anyway") { performSaleSave(allowOverpay: true) }
                Button("Cancel", role: .cancel) { saveAndContinue = false }
            } message: {
                Text("Amount received is more than the net amount after discount. This can be used for advances. Continue?")
            }
            .alert("Credit without customer", isPresented: $showCreditWarning) {
                Button("Save Anyway") { performSaleSave(allowUntrackedCredit: true) }
                Button("Cancel", role: .cancel) { saveAndContinue = false }
            } message: {
                Text("Credit sales need a customer attached to track what's owed. Save anyway?")
            }
            .onAppear {
                tab = settings?.lastEntryTab ?? .sale
                if tab == .sale {
                    itemFocusNonce += 1
                } else {
                    paymentPartyFocusNonce += 1
                }
            }
        }
    }

    // MARK: - Sale form

    @ViewBuilder
    private var saleForm: some View {
        SearchablePicker(
            title: "Item",
            placeholder: "Search name, SKU, or MRP…",
            items: items,
            selection: $selectedItem,
            autofocus: false,
            focusNonce: itemFocusNonce,
            score: ItemSearchRanking.score,
            selectedTitle: { "\($0.name) · \($0.sku)" },
            onSelect: {
                if let item = selectedItem {
                    salePriceText = "\(item.mrp)"
                    updateAmountReceivedDefault()
                    updateStockWarning()
                    focusedField = .quantity
                }
            },
            row: { ItemSearchRow(item: $0) }
        )
        .onChange(of: selectedItem) { _, item in
            if let item {
                salePriceText = "\(item.mrp)"
                updateAmountReceivedDefault()
                updateStockWarning()
            }
        }

        HStack {
            Text("Quantity")
            Spacer()
            TextField("Qty", value: $quantity, format: .number)
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                .focused($focusedField, equals: .quantity)
                .onChange(of: quantity) { _, _ in
                    updateAmountReceivedDefault()
                    updateStockWarning()
                }
            Stepper("", value: $quantity, in: 1...9999)
                .labelsHidden()
        }

        if let stockWarning {
            Text(stockWarning)
                .foregroundStyle(.orange)
                .font(.caption)
        }

        TextField("Sale Price (per unit)", text: $salePriceText)
            .focused($focusedField, equals: .salePrice)
            .onChange(of: salePriceText) { _, _ in updateAmountReceivedDefault() }

        discountSection

        SearchablePicker(
            title: "Customer",
            placeholder: "Search customer name or phone…",
            items: parties,
            selection: $selectedParty,
            allowsClearToNil: true,
            nilSelectionLabel: "Walk-in (no customer)",
            focusNonce: partyFocusNonce,
            score: PartySearchRanking.score,
            selectedTitle: { party in
                if let phone = party.phone, !phone.isEmpty { return "\(party.name) · \(phone)" }
                return party.name
            },
            row: { PartySearchRow(party: $0) }
        )

        Picker("Payment Mode", selection: $paymentMode) {
            ForEach(PaymentMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .onChange(of: paymentMode) { _, mode in
            if mode == .credit {
                amountReceivedText = "0"
            } else {
                updateAmountReceivedDefault()
            }
        }

        TextField("Amount Received", text: $amountReceivedText)
            .focused($focusedField, equals: .amountReceived)

        summarySection

        TextField("Notes", text: $notes, axis: .vertical)
            .lineLimit(2...4)
    }

    // MARK: - Payment form

    @ViewBuilder
    private var paymentForm: some View {
        SearchablePicker(
            title: "Customer",
            placeholder: "Search customer name or phone…",
            items: parties,
            selection: $paymentParty,
            allowsClearToNil: false,
            nilSelectionLabel: nil,
            focusNonce: paymentPartyFocusNonce,
            score: PartySearchRanking.score,
            selectedTitle: { party in
                if let phone = party.phone, !phone.isEmpty { return "\(party.name) · \(phone)" }
                return party.name
            },
            onSelect: { focusedField = .paymentAmount },
            row: { PartySearchRow(party: $0) }
        )

        if let paymentParty {
            LabeledContent("Current Balance", value: paymentParty.balance.currencyString)
        }

        Picker("Direction", selection: $paymentDirection) {
            ForEach(PaymentDirection.allCases) { direction in
                Text(direction.rawValue).tag(direction)
            }
        }
        .pickerStyle(.segmented)

        TextField("Amount", text: $paymentAmountText)
            .focused($focusedField, equals: .paymentAmount)

        Picker("Payment Mode", selection: $paymentModeOnly) {
            ForEach(PaymentMode.allCases.filter { $0 != .credit && $0 != .mixed }) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }

        TextField("Notes", text: $paymentNotes, axis: .vertical)
            .lineLimit(2...4)
    }

    // MARK: - Discount / summary (unchanged logic)

    @ViewBuilder
    private var discountSection: some View {
        if showDiscount {
            Picker("Discount", selection: $discountKind) {
                ForEach(DiscountKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: discountKind) { _, _ in updateAmountReceivedDefault() }

            TextField(discountKind == .percentage ? "Discount %" : "Discount ₹", text: $discountValueText)
                .onChange(of: discountValueText) { _, _ in updateAmountReceivedDefault() }

            if let discountClampedNote {
                Text(discountClampedNote)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Button("Remove discount") {
                showDiscount = false
                discountValueText = ""
                updateAmountReceivedDefault()
            }
        } else {
            Button("Add discount") {
                showDiscount = true
                discountKind = .percentage
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.headline)
            summaryRow("Gross Amount", grossAmount.currencyString)
            if showDiscount && discountAmount > 0 {
                let label: String = {
                    if activeDiscountType == .percentage {
                        return "Discount (−\(enteredDiscountValue)%)"
                    }
                    return "Discount"
                }()
                summaryRow(label, "−\(discountAmount.currencyString)")
            }
            summaryRow("Net Amount", netAmount.currencyString, bold: true)
            summaryRow("Amount Received", amountReceived.currencyString)
            HStack {
                Text("Pending Amount")
                Spacer()
                Text(pendingAmount.currencyString)
                    .fontWeight(.semibold)
                    .foregroundStyle(pendingAmount > 0 ? Color.orange : Color.primary)
            }
            .font(.body.monospacedDigit())
        }
        .padding(.vertical, 4)
    }

    private func summaryRow(_ label: String, _ value: String, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .fontWeight(bold ? .semibold : .regular)
            Spacer()
            Text(value)
                .fontWeight(bold ? .semibold : .regular)
        }
        .font(.body.monospacedDigit())
    }

    // MARK: - Save

    private func attemptSave() {
        errorMessage = nil
        if tab == .sale {
            attemptSaleSave()
        } else {
            attemptPaymentSave()
        }
    }

    private func attemptSaleSave() {
        guard selectedItem != nil else {
            errorMessage = "Select an item."
            saveAndContinue = false
            return
        }
        guard CurrencyFormatting.parse(salePriceText) != nil else {
            errorMessage = "Enter a valid sale price."
            saveAndContinue = false
            return
        }
        guard CurrencyFormatting.parse(amountReceivedText) != nil else {
            errorMessage = "Enter a valid amount received."
            saveAndContinue = false
            return
        }
        if showDiscount, CurrencyFormatting.parse(discountValueText) == nil {
            errorMessage = "Enter a valid discount value, or remove the discount."
            saveAndContinue = false
            return
        }

        if amountReceived > netAmount {
            showOverpayConfirm = true
            return
        }
        if pendingAmount > 0 && selectedParty == nil {
            showCreditWarning = true
            return
        }
        performSaleSave()
    }

    private func performSaleSave(allowOverpay: Bool = false, allowUntrackedCredit: Bool = false) {
        guard let item = selectedItem,
              let price = CurrencyFormatting.parse(salePriceText),
              let received = CurrencyFormatting.parse(amountReceivedText) else { return }

        let pending = SalePricing.pendingAmount(net: netAmount, received: received)
        let untracked = pending > 0 && selectedParty == nil

        if untracked && !allowUntrackedCredit {
            showCreditWarning = true
            return
        }
        if received > netAmount && !allowOverpay {
            showOverpayConfirm = true
            return
        }

        let type = activeDiscountType
        let value = type == .none ? Decimal(0) : enteredDiscountValue

        let sale = SaleEntry(
            date: date,
            item: item,
            quantity: quantity,
            salePrice: price,
            party: selectedParty,
            paymentMode: paymentMode,
            amountReceived: received,
            notes: notes.isEmpty ? nil : notes,
            source: .manual,
            isUntrackedCredit: untracked,
            discountType: type,
            discountValue: value
        )
        modelContext.insert(sale)
        item.quantityOnHand -= quantity

        if pending > 0, let party = selectedParty {
            let ledger = LedgerTransaction(
                party: party,
                date: date,
                type: .saleOnCredit,
                amount: pending,
                relatedSaleEntry: sale,
                notes: "Credit from sale of \(item.name)"
            )
            modelContext.insert(ledger)
        }

        try? modelContext.save()
        finishSave(kind: .sale)
    }

    private func attemptPaymentSave() {
        guard let party = paymentParty else {
            errorMessage = "Select a customer."
            saveAndContinue = false
            return
        }
        guard let amount = CurrencyFormatting.parse(paymentAmountText), amount > 0 else {
            errorMessage = "Enter a valid amount."
            saveAndContinue = false
            return
        }

        LedgerPaymentRecorder.record(
            party: party,
            direction: paymentDirection,
            amount: amount,
            date: date,
            paymentMode: paymentModeOnly,
            notes: paymentNotes.isEmpty ? nil : paymentNotes,
            in: modelContext
        )
        finishSave(kind: .payment)
    }

    private func finishSave(kind: EntryFormTab) {
        if saveAndContinue {
            clearForm(keepingDate: true, kind: kind)
            saveAndContinue = false
        } else {
            dismiss()
        }
    }

    private func clearForm(keepingDate: Bool, kind: EntryFormTab) {
        if !keepingDate { date = Date() }
        errorMessage = nil
        stockWarning = nil

        switch kind {
        case .sale:
            selectedItem = nil
            quantity = 1
            salePriceText = ""
            selectedParty = nil
            paymentMode = .cash
            amountReceivedText = ""
            notes = ""
            showDiscount = false
            discountValueText = ""
            itemFocusNonce += 1
        case .payment:
            paymentParty = nil
            paymentDirection = .received
            paymentAmountText = ""
            paymentModeOnly = .cash
            paymentNotes = ""
            paymentPartyFocusNonce += 1
        }
    }

    private func updateAmountReceivedDefault() {
        if paymentMode != .credit {
            amountReceivedText = "\(netAmount)"
        }
    }

    private func updateStockWarning() {
        guard let item = selectedItem else {
            stockWarning = nil
            return
        }
        if quantity > item.quantityOnHand {
            stockWarning = "Only \(item.quantityOnHand) in stock — this will make stock negative."
        } else {
            stockWarning = nil
        }
    }
}
