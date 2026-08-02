//
//  SmartPriceCalculator.swift
//  Boutique Buddy
//

import Foundation

enum SmartPriceCalculator {
    /// Applies markup percent to cost, then rounds up to the nearest increment.
    static func suggestMRP(
        costPrice: Decimal,
        markupPercent: Double,
        roundingIncrement: Int = 10
    ) -> Decimal {
        guard costPrice > 0 else { return 0 }
        let markup = Decimal(markupPercent) / 100
        let raw = costPrice * (1 + markup)
        let increment = Decimal(max(roundingIncrement, 1))
        let divided = raw / increment
        let ceiling = NSDecimalNumber(decimal: divided).rounding(accordingToBehavior: NSDecimalNumberHandler(
            roundingMode: .up,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        ))
        return ceiling.decimalValue * increment
    }
}
