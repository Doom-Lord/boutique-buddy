//
//  ReceiptView.swift
//  Boutique Buddy
//

import SwiftUI

struct ReceiptLineItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let category: String
    let quantity: Int
    let unitPrice: Decimal

    init(id: UUID = UUID(), name: String, category: String, quantity: Int, unitPrice: Decimal) {
        self.id = id
        self.name = name
        self.category = category
        self.quantity = quantity
        self.unitPrice = unitPrice
    }
}

/// Shareable sale receipt — paper stock, stitch dividers, scalloped edge.
struct ReceiptView: View {
    let brand: BrandIdentity
    let saleDate: Date
    let customerName: String?
    let lineItems: [ReceiptLineItem]
    let grossAmount: Decimal
    let discountAmount: Decimal
    let discountLabel: String?
    let netAmount: Decimal
    let amountPaid: Decimal
    let pendingAmount: Decimal

    private let cardWidth: CGFloat = 380

    var body: some View {
        ReceiptPaperCard(width: cardWidth) {
            ShareDocumentHeader(brand: brand, documentTitle: "Sale Receipt", date: saleDate)

            StitchDivider()

            if let customerName, !customerName.isEmpty {
                ReceiptKeyedRow(label: "Customer", value: customerName, valueWeight: .semibold)
                StitchDivider()
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(lineItems) { item in
                    itemBlock(item)
                }
            }

            StitchDivider()

            VStack(spacing: 8) {
                if discountAmount > 0 {
                    ReceiptKeyedRow(label: "Gross Amount", value: grossAmount.currencyString)
                    ReceiptKeyedRow(
                        label: discountLabel ?? "Discount",
                        value: "−\(discountAmount.currencyString)"
                    )
                    ReceiptKeyedRow(label: "Net Amount", value: netAmount.currencyString, valueWeight: .semibold)
                } else {
                    ReceiptKeyedRow(label: "Amount", value: netAmount.currencyString, valueWeight: .semibold)
                }

                ReceiptKeyedRow(label: "Paid", value: amountPaid.currencyString)

                if pendingAmount > 0 {
                    ReceiptKeyedRow(
                        label: "Balance Due",
                        value: pendingAmount.currencyString,
                        labelWeight: .semibold,
                        valueWeight: .bold,
                        emphasizeDue: true
                    )
                }
            }

            StitchDivider()

            Text(brand.thankYouNote)
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundStyle(Color.receiptMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private func itemBlock(_ item: ReceiptLineItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.name)
                .font(.system(size: 15, weight: .semibold, design: .default))
                .foregroundStyle(Color.receiptInk)

            if !item.category.isEmpty {
                Text(item.category)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundStyle(Color.receiptMuted)
            }

            Text("\(item.quantity) × \(item.unitPrice.currencyString)")
                .font(.system(size: 15, weight: .regular, design: .default).monospacedDigit())
                .foregroundStyle(Color.receiptInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension ReceiptView {
    init(sale: SaleEntry, brand: BrandIdentity) {
        self.brand = brand
        self.saleDate = sale.date
        self.customerName = sale.party?.name
        self.lineItems = [
            ReceiptLineItem(
                id: sale.id,
                name: sale.item?.name ?? "Item",
                category: sale.item?.displayCategory ?? "",
                quantity: sale.quantity,
                unitPrice: sale.salePrice
            )
        ]
        self.grossAmount = sale.grossAmount
        self.discountAmount = sale.discountAmount
        if sale.discountAmount > 0 {
            switch sale.discountType {
            case .percentage:
                self.discountLabel = "Discount (−\(sale.discountValue)%)"
            case .flatAmount, .none:
                self.discountLabel = "Discount"
            }
        } else {
            self.discountLabel = nil
        }
        self.netAmount = sale.netAmount
        self.amountPaid = sale.amountReceived
        self.pendingAmount = sale.pendingAmount
    }
}

#Preview {
    ReceiptView(
        brand: .fallback,
        saleDate: .now,
        customerName: "Anjali",
        lineItems: [
            ReceiptLineItem(name: "Beige Block Heels", category: "Footwear", quantity: 1, unitPrice: 1190)
        ],
        grossAmount: 1190,
        discountAmount: 90,
        discountLabel: "Discount",
        netAmount: 1100,
        amountPaid: 990,
        pendingAmount: 110
    )
    .padding()
    .background(Color.gray.opacity(0.2))
}
