//
//  Enums.swift
//  Boutique Buddy
//

import Foundation

enum RecordSource: String, Codable, CaseIterable, Identifiable {
    case manual
    case csv

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual: "Manual"
        case .csv: "CSV Import"
        }
    }
}

enum PaymentMode: String, Codable, CaseIterable, Identifiable {
    case cash = "Cash"
    case upi = "UPI"
    case card = "Card"
    case credit = "Credit"
    case mixed = "Mixed"

    var id: String { rawValue }

    static func matching(_ value: String) -> PaymentMode? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return allCases.first { $0.rawValue.compare(trimmed, options: .caseInsensitive) == .orderedSame }
    }
}

enum DiscountType: String, Codable, CaseIterable, Identifiable {
    case none
    case percentage
    case flatAmount

    var id: String { rawValue }

    var pickerLabel: String {
        switch self {
        case .none: "None"
        case .percentage: "% off"
        case .flatAmount: "₹ off"
        }
    }
}

enum LedgerTransactionType: String, Codable, CaseIterable, Identifiable {
    case openingBalance = "Opening Balance"
    case saleOnCredit = "Sale on Credit"
    case paymentReceived = "Payment Received"
    case paymentMade = "Payment Made"
    case adjustment = "Adjustment"

    var id: String { rawValue }
}

enum LabelSize: String, Codable, CaseIterable, Identifiable {
    case mm50x25 = "50×25 mm"
    case mm50x30 = "50×30 mm"
    case twoAcross = "2 Across (50×25)"

    var id: String { rawValue }

    /// Label size in points (72 pt = 1 inch). 1 mm ≈ 2.8346 pt.
    var sizeInPoints: CGSize {
        switch self {
        case .mm50x25, .twoAcross:
            CGSize(width: 50 * 2.8346, height: 25 * 2.8346)
        case .mm50x30:
            CGSize(width: 50 * 2.8346, height: 30 * 2.8346)
        }
    }

    var columns: Int {
        switch self {
        case .twoAcross: 2
        default: 1
        }
    }
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case dashboard
    case entries
    case items
    case parties
    case tools

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .entries: "Entries"
        case .items: "Items"
        case .parties: "Parties"
        case .tools: "Tools"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .entries: "list.bullet.rectangle"
        case .items: "shippingbox"
        case .parties: "person.2"
        case .tools: "wrench.and.screwdriver"
        }
    }
}

enum EntryFormTab: String, CaseIterable, Identifiable {
    case sale
    case payment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sale: "Sale Entry"
        case .payment: "Payment Entry"
        }
    }

    var windowTitle: String {
        switch self {
        case .sale: "Add Sale"
        case .payment: "Add Payment"
        }
    }
}

enum PaymentDirection: String, CaseIterable, Identifiable {
    case received = "Received from customer"
    case paid = "Paid to customer"

    var id: String { rawValue }

    var ledgerType: LedgerTransactionType {
        switch self {
        case .received: .paymentReceived
        case .paid: .paymentMade
        }
    }

    /// Positive = customer owes more; negative = customer owes less.
    func signedAmount(_ amount: Decimal) -> Decimal {
        switch self {
        case .received: -amount
        case .paid: amount
        }
    }
}
