//
//  ContentView.swift
//  Boutique Buddy
//
//  Created by Vikas Deswal on 02/08/26.
//

import SwiftUI
import SwiftData
import AppKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedSection: SidebarSection? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
            .navigationTitle("Boutique Buddy")
        } detail: {
            Group {
                switch selectedSection {
                case .dashboard: DashboardView()
                case .entries: EntriesView()
                case .items: ItemsView()
                case .parties: PartiesView()
                case .tools: ToolsView()
                case .none: DashboardView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            SeedData.ensureDefaults(in: modelContext)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                // Automatic backup is handled more reliably via NSApplication willTerminate;
                // scenePhase inactive also fires on resign — keep quiet here.
            }
        }
        .background(QuitBackupObserver())
    }
}

/// Observes app termination to write an automatic local backup.
private struct QuitBackupObserver: NSViewRepresentable {
    @Environment(\.modelContext) private var modelContext

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.startObserving()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(modelContext: modelContext)
    }

    final class Coordinator {
        let modelContext: ModelContext
        private var observer: NSObjectProtocol?

        init(modelContext: ModelContext) {
            self.modelContext = modelContext
        }

        func startObserving() {
            observer = NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                try? self.modelContext.save()
                BackupManager.automaticBackupOnQuit(container: self.modelContext.container)
                let descriptor = FetchDescriptor<AppSettings>()
                if let settings = try? self.modelContext.fetch(descriptor).first {
                    settings.lastBackupDate = Date()
                    try? self.modelContext.save()
                }
            }
        }

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Category.self,
            InventoryItem.self,
            PurchaseRecord.self,
            SaleEntry.self,
            Party.self,
            LedgerTransaction.self,
            AppSettings.self
        ], inMemory: true)
}
