//
//  BackupRestoreView.swift
//  Boutique Buddy
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct BackupRestoreView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]

    @State private var statusMessage: String?
    @State private var showRestoreConfirm = false
    @State private var pendingRestoreURL: URL?

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        Form {
            Section("Backup") {
                if let last = settings?.lastBackupDate {
                    LabeledContent("Last Backup", value: last.formatted(date: .abbreviated, time: .shortened))
                } else {
                    LabeledContent("Last Backup", value: "Never")
                }
                Text("Automatic backups are saved on quit (last 10 kept) in Application Support.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Backup Now…") { backupNow() }
            }

            Section("Restore") {
                Text("Restoring replaces all current data. The app may need to be restarted after restore.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Restore from Backup…", role: .destructive) { pickRestore() }
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Backup & Restore")
        .alert("Restore Backup?", isPresented: $showRestoreConfirm) {
            Button("Restore", role: .destructive) { performRestore() }
            Button("Cancel", role: .cancel) { pendingRestoreURL = nil }
        } message: {
            Text("This will overwrite your current shop data. Continue?")
        }
    }

    private func backupNow() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "store") ?? .data]
        panel.nameFieldStringValue = "BoutiqueBuddy_Backup.store"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try modelContext.save()
            try BackupManager.backup(container: modelContext.container, to: url)
            settings?.lastBackupDate = Date()
            try? modelContext.save()
            statusMessage = "Backup saved to \(url.lastPathComponent)"
        } catch {
            statusMessage = "Backup failed: \(error.localizedDescription)"
        }
    }

    private func pickRestore() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "store") ?? .data, .data]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pendingRestoreURL = url
        showRestoreConfirm = true
    }

    private func performRestore() {
        guard let url = pendingRestoreURL else { return }
        do {
            try BackupManager.restore(from: url, into: modelContext.container)
            statusMessage = "Restore complete. Please quit and reopen Boutique Buddy to reload data."
        } catch {
            statusMessage = "Restore failed: \(error.localizedDescription)"
        }
        pendingRestoreURL = nil
    }
}
