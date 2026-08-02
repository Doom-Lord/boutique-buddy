//
//  BackupManager.swift
//  Boutique Buddy
//

import Foundation
import SwiftData

enum BackupManager {
    static var automaticBackupDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Boutique Buddy/Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func storeURL(for container: ModelContainer) -> URL? {
        container.configurations.first?.url
    }

    /// Copies the SwiftData store (and sidecars) to `destination`.
    static func backup(container: ModelContainer, to destination: URL) throws {
        guard let storeURL = storeURL(for: container) else {
            throw BackupError.storeNotFound
        }
        try copyStore(from: storeURL, to: destination)
    }

    static func automaticBackupOnQuit(container: ModelContainer) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let name = "BoutiqueBuddy_\(formatter.string(from: Date())).store"
        let destination = automaticBackupDirectory.appendingPathComponent(name)
        do {
            try backup(container: container, to: destination)
            pruneAutomaticBackups(keeping: 10)
        } catch {
            // Best-effort on quit; ignore failures.
        }
    }

    static func pruneAutomaticBackups(keeping limit: Int) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: automaticBackupDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let sorted = files
            .filter { $0.pathExtension == "store" || $0.lastPathComponent.contains(".store") }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return da > db
            }

        for url in sorted.dropFirst(limit) {
            try? fm.removeItem(at: url)
            // Also remove possible sidecar files
            for suffix in ["-shm", "-wal"] {
                let sidecar = URL(fileURLWithPath: url.path + suffix)
                try? fm.removeItem(at: sidecar)
            }
        }
    }

    static func restore(from backupURL: URL, into container: ModelContainer) throws {
        guard let storeURL = storeURL(for: container) else {
            throw BackupError.storeNotFound
        }
        // Caller should recreate the container after restore; here we overwrite files.
        try copyStore(from: backupURL, to: storeURL)
    }

    private static func copyStore(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: source, to: destination)

        for suffix in ["-shm", "-wal"] {
            let src = URL(fileURLWithPath: source.path + suffix)
            let dst = URL(fileURLWithPath: destination.path + suffix)
            if fm.fileExists(atPath: dst.path) {
                try? fm.removeItem(at: dst)
            }
            if fm.fileExists(atPath: src.path) {
                try? fm.copyItem(at: src, to: dst)
            }
        }
    }

    enum BackupError: LocalizedError {
        case storeNotFound

        var errorDescription: String? {
            switch self {
            case .storeNotFound: "Could not locate the data store."
            }
        }
    }
}
