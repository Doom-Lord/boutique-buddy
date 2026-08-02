//
//  LedgerPaymentRecorder.swift
//  Boutique Buddy
//

import Foundation
import SwiftData

enum LedgerPaymentRecorder {
    @discardableResult
    static func record(
        party: Party,
        direction: PaymentDirection,
        amount: Decimal,
        date: Date,
        paymentMode: PaymentMode,
        notes: String?,
        in context: ModelContext
    ) -> LedgerTransaction {
        let modeNote = "via \(paymentMode.rawValue)"
        let combinedNotes = [notes.flatMap { $0.isEmpty ? nil : $0 }, modeNote]
            .compactMap { $0 }
            .joined(separator: " · ")

        let ledger = LedgerTransaction(
            party: party,
            date: date,
            type: direction.ledgerType,
            amount: direction.signedAmount(amount),
            notes: combinedNotes
        )
        context.insert(ledger)
        try? context.save()
        return ledger
    }
}
