//
//  AccountStatementView.swift
//  Boutique Buddy
//

import SwiftUI

struct AccountStatementLine: Identifiable {
    let id: UUID
    let date: Date
    let title: String
    let amount: Decimal
}

/// Shareable account snapshot — same paper / stitch language as receipts.
struct AccountStatementView: View {
    let brand: BrandIdentity
    let customerName: String
    let statementDate: Date
    let balance: Decimal
    let recentLines: [AccountStatementLine]

    private let cardWidth: CGFloat = 380

    private var balanceLabel: String {
        if balance > 0 { return "Balance Due" }
        if balance < 0 { return "Advance / Credit" }
        return "Balance"
    }

    private var displayBalance: Decimal {
        balance < 0 ? -balance : balance
    }

    private var balanceIsDue: Bool { balance > 0 }

    var body: some View {
        ReceiptPaperCard(width: cardWidth) {
            ShareDocumentHeader(brand: brand, documentTitle: "Account Statement", date: statementDate)

            StitchDivider()

            ReceiptKeyedRow(label: "Customer", value: customerName, valueWeight: .semibold)

            StitchDivider()

            VStack(alignment: .leading, spacing: 4) {
                Text(balanceLabel.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .tracking(1.5)
                    .foregroundStyle(balanceIsDue ? Color.receiptDue : Color.receiptGold)

                Text(displayBalance.currencyString)
                    .font(.system(size: 26, weight: .bold, design: .default).monospacedDigit())
                    .foregroundStyle(balanceIsDue ? Color.receiptDue : Color.receiptInk)

                if balance == 0 {
                    Text("Settled")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundStyle(Color.receiptMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !recentLines.isEmpty {
                StitchDivider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("RECENT ACTIVITY")
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .tracking(1.5)
                        .foregroundStyle(Color.receiptGold)

                    ForEach(recentLines) { line in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.title)
                                    .font(.system(size: 15, weight: .semibold, design: .default))
                                    .foregroundStyle(Color.receiptInk)
                                Text(line.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 12, weight: .regular, design: .default))
                                    .foregroundStyle(Color.receiptMuted)
                            }
                            Spacer(minLength: 12)
                            Text(signed(line.amount))
                                .font(.system(size: 15, weight: .regular, design: .default).monospacedDigit())
                                .foregroundStyle(Color.receiptInk)
                        }
                    }
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

    private func signed(_ amount: Decimal) -> String {
        if amount > 0 { return "+\(amount.currencyString)" }
        if amount < 0 { return amount.currencyString }
        return amount.currencyString
    }
}

extension AccountStatementView {
    init(party: Party, brand: BrandIdentity, recentLimit: Int = 8) {
        self.brand = brand
        self.customerName = party.name
        self.statementDate = Date()
        self.balance = party.balance

        let recent = party.ledgerTransactions
            .sorted { $0.date > $1.date }
            .prefix(recentLimit)
            .map {
                AccountStatementLine(
                    id: $0.id,
                    date: $0.date,
                    title: $0.type.rawValue,
                    amount: $0.amount
                )
            }
        self.recentLines = Array(recent)
    }
}

#Preview {
    AccountStatementView(
        brand: .fallback,
        customerName: "Meena Sharma",
        statementDate: .now,
        balance: 2090,
        recentLines: [
            AccountStatementLine(id: UUID(), date: .now, title: "Sale on Credit", amount: 1090),
            AccountStatementLine(id: UUID(), date: .now, title: "Payment Received", amount: -1000)
        ]
    )
    .padding()
    .background(Color.gray.opacity(0.2))
}
