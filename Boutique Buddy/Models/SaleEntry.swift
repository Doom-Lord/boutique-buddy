//
//  SaleEntry.swift
//  Boutique Buddy
//

import Foundation
import SwiftData

@Model
final class SaleEntry {
    var id: UUID
    var date: Date
    var quantity: Int
    var salePrice: Decimal
    var paymentModeRaw: String
    var amountReceived: Decimal
    var notes: String?
    var sourceRaw: String
    /// True when credit shortfall was saved without a party attached.
    var isUntrackedCredit: Bool
    var discountTypeRaw: String = DiscountType.none.rawValue
    var discountValue: Decimal = 0

    var item: InventoryItem?
    var party: Party?

    @Relationship(deleteRule: .nullify, inverse: \LedgerTransaction.relatedSaleEntry)
    var ledgerTransactions: [LedgerTransaction]

    init(
        id: UUID = UUID(),
        date: Date = .now,
        item: InventoryItem? = nil,
        quantity: Int,
        salePrice: Decimal,
        party: Party? = nil,
        paymentMode: PaymentMode = .cash,
        amountReceived: Decimal,
        notes: String? = nil,
        source: RecordSource = .manual,
        isUntrackedCredit: Bool = false,
        discountType: DiscountType = .none,
        discountValue: Decimal = 0
    ) {
        self.id = id
        self.date = date
        self.item = item
        self.quantity = quantity
        self.salePrice = salePrice
        self.party = party
        self.paymentModeRaw = paymentMode.rawValue
        self.amountReceived = amountReceived
        self.notes = notes
        self.sourceRaw = source.rawValue
        self.isUntrackedCredit = isUntrackedCredit
        self.discountTypeRaw = discountType.rawValue
        self.discountValue = discountType == .none ? 0 : discountValue
        self.ledgerTransactions = []
    }

    var paymentMode: PaymentMode {
        get { PaymentMode(rawValue: paymentModeRaw) ?? .cash }
        set { paymentModeRaw = newValue.rawValue }
    }

    var source: RecordSource {
        get { RecordSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var discountType: DiscountType {
        get { DiscountType(rawValue: discountTypeRaw) ?? .none }
        set { discountTypeRaw = newValue.rawValue }
    }

    var grossAmount: Decimal { salePrice * Decimal(quantity) }

    var discountAmount: Decimal {
        SalePricing.discountAmount(
            gross: grossAmount,
            type: discountType,
            value: discountValue
        )
    }

    var netAmount: Decimal { grossAmount - discountAmount }

    var pendingAmount: Decimal { max(0, netAmount - amountReceived) }

    /// Alias for net amount (used by dashboard / daily totals).
    var totalAmount: Decimal { netAmount }

    /// Alias for pending amount (older call sites).
    var shortfall: Decimal { pendingAmount }
}

enum SalePricing {
    static func discountAmount(gross: Decimal, type: DiscountType, value: Decimal) -> Decimal {
        guard gross > 0, value > 0 else { return 0 }
        let raw: Decimal
        switch type {
        case .none:
            return 0
        case .percentage:
            raw = gross * (value / 100)
        case .flatAmount:
            raw = value
        }
        return min(max(0, raw), gross)
    }

    static func netAmount(gross: Decimal, type: DiscountType, value: Decimal) -> Decimal {
        gross - discountAmount(gross: gross, type: type, value: value)
    }

    static func pendingAmount(net: Decimal, received: Decimal) -> Decimal {
        max(0, net - received)
    }

    /// True when the entered discount value would exceed the gross (before clamping).
    static func wouldClamp(gross: Decimal, type: DiscountType, value: Decimal) -> Bool {
        guard value > 0 else { return false }
        switch type {
        case .none: return false
        case .percentage: return value > 100
        case .flatAmount: return value > gross
        }
    }
}
