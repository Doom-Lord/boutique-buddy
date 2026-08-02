//
//  LedgerTransaction.swift
//  Boutique Buddy
//

import Foundation
import SwiftData

@Model
final class LedgerTransaction {
    var id: UUID
    var date: Date
    var typeRaw: String
    /// Positive = increases what customer owes. Negative = decreases it.
    var amount: Decimal
    var notes: String?

    var party: Party?
    var relatedSaleEntry: SaleEntry?

    init(
        id: UUID = UUID(),
        party: Party? = nil,
        date: Date = .now,
        type: LedgerTransactionType,
        amount: Decimal,
        relatedSaleEntry: SaleEntry? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.party = party
        self.date = date
        self.typeRaw = type.rawValue
        self.amount = amount
        self.relatedSaleEntry = relatedSaleEntry
        self.notes = notes
    }

    var type: LedgerTransactionType {
        get { LedgerTransactionType(rawValue: typeRaw) ?? .adjustment }
        set { typeRaw = newValue.rawValue }
    }
}
