//
//  Category.swift
//  Boutique Buddy
//

import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID
    var name: String
    var subTypes: [String]
    var defaultMarkupPercent: Double?
    var sortOrder: Int

    @Relationship(deleteRule: .nullify, inverse: \InventoryItem.category)
    var items: [InventoryItem]

    init(
        id: UUID = UUID(),
        name: String,
        subTypes: [String] = [],
        defaultMarkupPercent: Double? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.subTypes = subTypes
        self.defaultMarkupPercent = defaultMarkupPercent
        self.sortOrder = sortOrder
        self.items = []
    }

    var hasSubTypes: Bool { !subTypes.isEmpty }
}
