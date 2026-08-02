//
//  SKUGenerator.swift
//  Boutique Buddy
//

import Foundation
import SwiftData

enum SKUGenerator {
    static func generate(for category: Category?, in context: ModelContext) -> String {
        let prefix = prefix(for: category)
        let existing = fetchExistingSKUs(prefix: prefix, in: context)
        var next = 1
        while existing.contains(String(format: "%@-%04d", prefix, next)) {
            next += 1
        }
        return String(format: "%@-%04d", prefix, next)
    }

    private static func prefix(for category: Category?) -> String {
        guard let name = category?.name, !name.isEmpty else { return "ITM" }
        let letters = name.uppercased().filter(\.isLetter)
        if letters.count >= 3 {
            return String(letters.prefix(3))
        }
        return letters.padding(toLength: 3, withPad: "X", startingAt: 0)
    }

    private static func fetchExistingSKUs(prefix: String, in context: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<InventoryItem>()
        let items = (try? context.fetch(descriptor)) ?? []
        return Set(items.map(\.sku).filter { $0.hasPrefix(prefix + "-") })
    }
}
