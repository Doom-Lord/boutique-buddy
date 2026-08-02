//
//  Party.swift
//  Boutique Buddy
//

import Foundation
import SwiftData

@Model
final class Party {
    var id: UUID
    var name: String
    var phone: String?
    var address: String?
    var notes: String?
    var dateAdded: Date

    @Relationship(deleteRule: .cascade, inverse: \LedgerTransaction.party)
    var ledgerTransactions: [LedgerTransaction]

    @Relationship(deleteRule: .nullify, inverse: \SaleEntry.party)
    var sales: [SaleEntry]

    init(
        id: UUID = UUID(),
        name: String,
        phone: String? = nil,
        address: String? = nil,
        notes: String? = nil,
        dateAdded: Date = .now
    ) {
        self.id = id
        self.name = name
        self.phone = phone
        self.address = address
        self.notes = notes
        self.dateAdded = dateAdded
        self.ledgerTransactions = []
        self.sales = []
    }

    /// Positive = customer owes the shop. Negative = shop owes the customer.
    var balance: Decimal {
        ledgerTransactions.reduce(Decimal.zero) { $0 + $1.amount }
    }
}
