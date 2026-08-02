//
//  Boutique_BuddyApp.swift
//  Boutique Buddy
//
//  Created by Vikas Deswal on 02/08/26.
//

import SwiftUI
import SwiftData

@main
struct Boutique_BuddyApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Category.self,
            InventoryItem.self,
            PurchaseRecord.self,
            SaleEntry.self,
            Party.self,
            LedgerTransaction.self,
            AppSettings.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 560)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        .defaultSize(width: 1100, height: 700)

        Settings {
            SettingsView()
        }
        .modelContainer(sharedModelContainer)
    }
}
