//
//  AppSettings.swift
//  Boutique Buddy
//

import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID
    var currencySymbol: String
    var backupFolderBookmark: Data?
    var lastBackupDate: Date?
    var labelSizeRaw: String
    var smartPriceRoundingIncrement: Int
    var hasSeededCategories: Bool = false
    var hasSeededDemoData: Bool = false

    /// Display name on receipts and statements (shop / brand).
    var brandName: String = "Boutique Buddy"
    /// Optional logo, stored as downscaled JPEG/PNG data.
    var logoImageData: Data?
    var address: String = ""
    var phoneNumber: String = ""
    var thankYouNote: String = "Thank you for shopping with us! 🙏"

    /// Legacy field from earlier builds — migrated into `brandName` on launch, then cleared.
    var shopName: String = ""

    /// Remembers last Add Entry tab: `"sale"` or `"payment"`.
    var lastEntryTabRaw: String = "sale"

    init(
        id: UUID = UUID(),
        currencySymbol: String = "₹",
        backupFolderBookmark: Data? = nil,
        lastBackupDate: Date? = nil,
        labelSize: LabelSize = .mm50x25,
        smartPriceRoundingIncrement: Int = 10,
        hasSeededCategories: Bool = false,
        hasSeededDemoData: Bool = false,
        brandName: String = "Boutique Buddy",
        logoImageData: Data? = nil,
        address: String = "",
        phoneNumber: String = "",
        thankYouNote: String = "Thank you for shopping with us! 🙏",
        lastEntryTabRaw: String = "sale"
    ) {
        self.id = id
        self.currencySymbol = currencySymbol
        self.backupFolderBookmark = backupFolderBookmark
        self.lastBackupDate = lastBackupDate
        self.labelSizeRaw = labelSize.rawValue
        self.smartPriceRoundingIncrement = smartPriceRoundingIncrement
        self.hasSeededCategories = hasSeededCategories
        self.hasSeededDemoData = hasSeededDemoData
        self.brandName = brandName
        self.logoImageData = logoImageData
        self.address = address
        self.phoneNumber = phoneNumber
        self.thankYouNote = thankYouNote
        self.shopName = ""
        self.lastEntryTabRaw = lastEntryTabRaw
    }

    var labelSize: LabelSize {
        get { LabelSize(rawValue: labelSizeRaw) ?? .mm50x25 }
        set { labelSizeRaw = newValue.rawValue }
    }

    var lastEntryTab: EntryFormTab {
        get { EntryFormTab(rawValue: lastEntryTabRaw) ?? .sale }
        set { lastEntryTabRaw = newValue.rawValue }
    }
}

/// Snapshot of shop identity for share cards (keeps SwiftUI views free of live model binding).
struct BrandIdentity: Equatable {
    var brandName: String
    var logoImageData: Data?
    var address: String
    var phoneNumber: String
    var thankYouNote: String

    static let fallback = BrandIdentity(
        brandName: "Boutique Buddy",
        logoImageData: nil,
        address: "",
        phoneNumber: "",
        thankYouNote: "Thank you for shopping with us! 🙏"
    )

    init(
        brandName: String,
        logoImageData: Data?,
        address: String,
        phoneNumber: String,
        thankYouNote: String
    ) {
        self.brandName = brandName
        self.logoImageData = logoImageData
        self.address = address
        self.phoneNumber = phoneNumber
        self.thankYouNote = thankYouNote
    }

    init(settings: AppSettings?) {
        guard let settings else {
            self = .fallback
            return
        }
        let name = settings.brandName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.brandName = name.isEmpty ? "Boutique Buddy" : name
        self.logoImageData = settings.logoImageData
        self.address = settings.address.trimmingCharacters(in: .whitespacesAndNewlines)
        self.phoneNumber = settings.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = settings.thankYouNote.trimmingCharacters(in: .whitespacesAndNewlines)
        self.thankYouNote = note.isEmpty ? BrandIdentity.fallback.thankYouNote : note
    }
}
