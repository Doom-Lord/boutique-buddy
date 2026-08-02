//
//  CurrencyFormatting.swift
//  Boutique Buddy
//

import Foundation

enum CurrencyFormatting {
    static let symbol = "₹"

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        return f
    }()

    static func string(from value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        let formatted = formatter.string(from: number) ?? "0"
        return "\(symbol)\(formatted)"
    }

    static func string(from value: Double) -> String {
        string(from: Decimal(value))
    }

    static func parse(_ text: String) -> Decimal? {
        let cleaned = text
            .replacingOccurrences(of: symbol, with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let double = Double(cleaned) else { return nil }
        return Decimal(double)
    }
}

extension Decimal {
    var currencyString: String { CurrencyFormatting.string(from: self) }
}
