//
//  InventoryItem.swift
//  Boutique Buddy
//

import Foundation
import SwiftData

@Model
final class InventoryItem {
    var id: UUID
    var name: String
    var sku: String
    var subType: String?
    var costPrice: Decimal
    var mrp: Decimal
    var quantityOnHand: Int
    var dateAdded: Date
    var supplier: String?
    var notes: String?
    var isArchived: Bool

    var category: Category?

    @Relationship(deleteRule: .cascade, inverse: \PurchaseRecord.item)
    var purchases: [PurchaseRecord]

    @Relationship(deleteRule: .cascade, inverse: \SaleEntry.item)
    var sales: [SaleEntry]

    init(
        id: UUID = UUID(),
        name: String,
        sku: String,
        category: Category? = nil,
        subType: String? = nil,
        costPrice: Decimal,
        mrp: Decimal,
        quantityOnHand: Int = 0,
        dateAdded: Date = .now,
        supplier: String? = nil,
        notes: String? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.sku = sku
        self.category = category
        self.subType = subType
        self.costPrice = costPrice
        self.mrp = mrp
        self.quantityOnHand = quantityOnHand
        self.dateAdded = dateAdded
        self.supplier = supplier
        self.notes = notes
        self.isArchived = isArchived
        self.purchases = []
        self.sales = []
    }

    var isLowStock: Bool { quantityOnHand <= 2 }

    var displayCategory: String {
        if let subType, !subType.isEmpty, let categoryName = category?.name {
            return "\(categoryName) · \(subType)"
        }
        return category?.name ?? "Uncategorized"
    }
}
