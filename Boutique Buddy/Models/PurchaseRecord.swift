//
//  PurchaseRecord.swift
//  Boutique Buddy
//

import Foundation
import SwiftData

@Model
final class PurchaseRecord {
    var id: UUID
    var quantity: Int
    var costPriceAtPurchase: Decimal
    var purchaseDate: Date
    var supplier: String?
    var sourceRaw: String
    var notes: String?

    var item: InventoryItem?

    init(
        id: UUID = UUID(),
        item: InventoryItem? = nil,
        quantity: Int,
        costPriceAtPurchase: Decimal,
        purchaseDate: Date = .now,
        supplier: String? = nil,
        source: RecordSource = .manual,
        notes: String? = nil
    ) {
        self.id = id
        self.item = item
        self.quantity = quantity
        self.costPriceAtPurchase = costPriceAtPurchase
        self.purchaseDate = purchaseDate
        self.supplier = supplier
        self.sourceRaw = source.rawValue
        self.notes = notes
    }

    var source: RecordSource {
        get { RecordSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
}
