//
//  Color+Theme.swift
//  Boutique Buddy
//

import SwiftUI

extension Color {
    /// Warm paper tone for shareable receipts / statements.
    static let receiptPaper = Color(red: 250 / 255, green: 245 / 255, blue: 236 / 255) // #FAF5EC
    /// Warm charcoal primary text.
    static let receiptInk = Color(red: 46 / 255, green: 38 / 255, blue: 33 / 255) // #2E2621
    /// Secondary labels, category, address.
    static let receiptMuted = Color(red: 140 / 255, green: 129 / 255, blue: 119 / 255) // #8C8177
    /// Brand name and section accents.
    static let receiptMaroon = Color(red: 139 / 255, green: 41 / 255, blue: 66 / 255) // #8B2942
    /// Stitch dividers and small-caps eyebrows — use sparingly.
    static let receiptGold = Color(red: 201 / 255, green: 160 / 255, blue: 85 / 255) // #C9A055
    /// Pending / balance-due amounts only.
    static let receiptDue = Color(red: 179 / 255, green: 58 / 255, blue: 46 / 255) // #B33A2E
}
