//
//  SaleDetailView.swift
//  Boutique Buddy
//

import SwiftUI
import SwiftData

struct SaleDetailView: View {
    @Query private var settingsList: [AppSettings]
    let sale: SaleEntry

    @State private var toastMessage: String?

    private var brand: BrandIdentity { BrandIdentity(settings: settingsList.first) }

    var body: some View {
        Form {
            Section("Sale") {
                LabeledContent("Date", value: sale.date.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Item", value: sale.item?.name ?? "—")
                if let category = sale.item?.displayCategory {
                    LabeledContent("Category", value: category)
                }
                LabeledContent("Quantity", value: "\(sale.quantity)")
                LabeledContent("Sale Price", value: sale.salePrice.currencyString)
                LabeledContent("Gross Amount", value: sale.grossAmount.currencyString)
                if sale.discountAmount > 0 {
                    LabeledContent("Discount", value: discountDescription)
                }
                LabeledContent("Net Amount", value: sale.netAmount.currencyString)
                LabeledContent("Amount Paid", value: sale.amountReceived.currencyString)
                if sale.pendingAmount > 0 {
                    LabeledContent("Pending", value: sale.pendingAmount.currencyString)
                }
                LabeledContent("Payment", value: sale.paymentMode.rawValue)
                LabeledContent("Customer", value: sale.party?.name ?? "Walk-in")
                if let notes = sale.notes, !notes.isEmpty {
                    LabeledContent("Notes", value: notes)
                }
            }

            Section("Share Receipt") {
                ShareImageControls(
                    helpCopy: "Copy receipt image",
                    helpShare: "Share receipt…",
                    compact: false,
                    card: {
                        ReceiptView(sale: sale, brand: brand)
                    },
                    onCopied: {
                        toastMessage = "Receipt copied — paste it anywhere with ⌘V."
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 2_400_000_000)
                            if toastMessage?.hasPrefix("Receipt copied") == true {
                                toastMessage = nil
                            }
                        }
                    }
                )
            }
        }
        .formStyle(.grouped)
        .navigationTitle(sale.item?.name ?? "Sale")
        .copyToast($toastMessage)
    }

    private var discountDescription: String {
        switch sale.discountType {
        case .percentage:
            return "−\(sale.discountAmount.currencyString) (\(sale.discountValue)%)"
        case .flatAmount:
            return "−\(sale.discountAmount.currencyString)"
        case .none:
            return "—"
        }
    }
}
